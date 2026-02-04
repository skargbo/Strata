#!/usr/bin/env node
// Claude Agent SDK Bridge
// Communicates with the Swift app via newline-delimited JSON on stdin/stdout.

import { query } from "@anthropic-ai/claude-agent-sdk";
import { createInterface } from "readline";
import { randomUUID } from "crypto";
import { existsSync, statSync, realpathSync } from "fs";

// --- State ---
let currentQuery = null;
const pendingPermissions = new Map(); // requestId -> { resolve, originalInput }
let currentToolUse = null; // { toolName, input } — set in canUseTool, used in user event
const toolUseQueue = []; // FIFO queue of { toolName, input } from assistant tool_use blocks
let lastContextTokens = 0; // Total tokens in the conversation context (from last API call)

// --- Helpers ---
function emit(obj) {
  process.stdout.write(JSON.stringify(obj) + "\n");
}

// --- Startup handshake: echo nonce for authentication ---
const bridgeNonce = process.env.STRATA_BRIDGE_NONCE || "";
emit({ type: "ready", nonce: bridgeNonce });
delete process.env.STRATA_BRIDGE_NONCE;

// --- stdin reader ---
const rl = createInterface({ input: process.stdin, terminal: false });

rl.on("line", (line) => {
  let msg;
  try {
    msg = JSON.parse(line);
  } catch (e) {
    console.error("[bridge] Malformed JSON from stdin:", e.message);
    return;
  }

  switch (msg.type) {
    case "query":
      handleQuery(msg);
      break;

    case "permission_response":
      handlePermissionResponse(msg);
      break;

    case "compact":
      handleCompact(msg);
      break;

    case "cancel":
      handleCancel();
      break;
  }
});

rl.on("close", () => {
  if (currentQuery) currentQuery.close();
  process.exit(0);
});

// --- Query handler ---
async function handleQuery(msg) {
  const { prompt, sessionId, cwd, permissionMode, model, systemPrompt } = msg;

  // Canonicalize and validate cwd to prevent path traversal
  const resolvedCwd = (() => {
    const candidate = cwd || process.cwd();
    try {
      const real = realpathSync(candidate);
      if (existsSync(real) && statSync(real).isDirectory()) return real;
    } catch {}
    return process.cwd();
  })();

  const cwdPreamble = `Your working directory is: ${resolvedCwd}\nAll file paths should be relative to or within this directory unless the user explicitly specifies an absolute path elsewhere.`;

  const options = {
    cwd: resolvedCwd,
    includePartialMessages: true,
    permissionMode: permissionMode || "default",
    canUseTool,
    systemPrompt: systemPrompt
      ? `${cwdPreamble}\n\n${systemPrompt}`
      : cwdPreamble,
  };

  if (model) {
    options.model = model;
  }

  if (sessionId) {
    options.resume = sessionId;
  }

  currentToolUse = null;
  toolUseQueue.length = 0;

  if (!sessionId) {
    lastContextTokens = 0;
  }

  // Clear orphaned permissions from any previous query
  for (const [id, pending] of pendingPermissions) {
    pending.resolve({ behavior: "deny", message: "Cancelled — new query started" });
  }
  pendingPermissions.clear();

  try {
    currentQuery = query({ prompt, options });

    for await (const event of currentQuery) {
      switch (event.type) {
        case "stream_event":
          handleStreamEvent(event);
          break;

        case "user":
          // A user event with a tool result means a tool has completed.
          // Emit turn_complete so Swift finalizes the current assistant message,
          // then emit tool_activity with structured data about the tool use.
          if (event.tool_use_result !== undefined) {
            // Resolve tool info: prefer canUseTool tracking (set when
            // permission was required), fall back to the FIFO queue
            // (populated from assistant tool_use blocks, for auto-approved tools).
            let toolInfo = currentToolUse || toolUseQueue.shift() || null;

            emit({ type: "turn_complete" });

            emit({
              type: "tool_activity",
              toolName: toolInfo?.toolName || "Unknown",
              input: toolInfo?.input || {},
              result: event.tool_use_result,
            });

            currentToolUse = null;
          }
          break;

        case "assistant":
          // assistant events contain full message snapshots for the
          // current turn (not deltas). Emit as set_text so Swift can
          // replace the current turn's text.
          if (event.message && event.message.content) {
            // Track tool_use blocks so we can pair them with results
            // (needed for auto-approved tools where canUseTool isn't called).
            const seenIds = new Set(toolUseQueue.map((t) => t._id));
            for (const block of event.message.content) {
              if (block.type === "tool_use" && block.id && !seenIds.has(block.id)) {
                toolUseQueue.push({
                  _id: block.id,
                  toolName: block.name,
                  input: block.input || {},
                });
                seenIds.add(block.id);
              }
            }

            const textParts = event.message.content
              .filter((b) => b.type === "text")
              .map((b) => b.text);
            if (textParts.length > 0) {
              emit({ type: "set_text", text: textParts.join("\n\n") });
            }
          }
          break;

        case "result":
          handleResult(event);
          break;

        case "tool_progress":
          emit({
            type: "tool_progress",
            toolName: event.tool_name,
            toolUseId: event.tool_use_id,
            elapsed: event.elapsed_time_seconds,
          });
          break;

        case "tool_use_summary":
          emit({
            type: "tool_use_summary",
            summary: event.summary,
          });
          break;
      }
    }
  } catch (err) {
    emit({ type: "error", message: err.message || String(err) });
  } finally {
    currentQuery = null;
  }
}

// --- Stream event handler ---
function handleStreamEvent(event) {
  const ev = event.event;
  if (!ev) return;

  if (ev.type === "content_block_delta" && ev.delta) {
    if (ev.delta.type === "text_delta" && ev.delta.text) {
      emit({ type: "token", text: ev.delta.text });
    }
  }
}

// --- Result handler ---
function handleResult(event) {
  const usage = event.usage || {};
  // Context = total input tokens from this API call. This represents the full
  // conversation size because each call sends the entire history. Output tokens
  // are excluded — they'll appear as input on the next call.
  lastContextTokens =
    (usage.input_tokens || 0) +
    (usage.cache_read_input_tokens || 0) +
    (usage.cache_creation_input_tokens || 0);

  emit({
    type: "result",
    text: event.result || "",
    sessionId: event.session_id || "",
    isError: !!event.is_error,
    subtype: event.subtype,
    usage: {
      inputTokens: usage.input_tokens || 0,
      outputTokens: usage.output_tokens || 0,
      cacheReadTokens: usage.cache_read_input_tokens || 0,
      cacheCreationTokens: usage.cache_creation_input_tokens || 0,
    },
    costUSD: event.total_cost_usd || 0,
    durationMs: event.duration_ms || 0,
    contextTokens: lastContextTokens,
  });
}

// --- Compact handler ---
async function handleCompact(msg) {
  const { sessionId, cwd, permissionMode, model, focusInstructions } = msg;
  if (!sessionId) {
    emit({ type: "error", message: "Cannot compact without a session ID" });
    return;
  }

  const compactPrompt = focusInstructions
    ? `/compact ${focusInstructions}`
    : "/compact";

  handleQuery({
    type: "query",
    prompt: compactPrompt,
    sessionId,
    cwd: cwd || process.cwd(),
    permissionMode: permissionMode || "default",
    model,
  });
}

// --- Permission callback ---
async function canUseTool(toolName, input, opts) {
  const requestId = randomUUID();

  // Track the current tool use so we can pair it with the result later
  currentToolUse = { toolName, input };

  emit({
    type: "permission_request",
    requestId,
    toolName,
    input: summarizeInput(toolName, input),
    reason: opts.decisionReason || null,
  });

  return new Promise((resolve) => {
    pendingPermissions.set(requestId, { resolve, originalInput: input });
  });
}

function handlePermissionResponse(msg) {
  const pending = pendingPermissions.get(msg.requestId);
  if (!pending) return;

  pendingPermissions.delete(msg.requestId);

  if (msg.behavior === "allow") {
    // Pass the original input back as updatedInput so the subprocess
    // retains the tool's parameters (file_path, command, etc.).
    // updatedInput must be a record (not undefined) to pass Zod validation.
    pending.resolve({
      behavior: "allow",
      updatedInput: pending.originalInput || {},
    });
  } else {
    pending.resolve({
      behavior: "deny",
      message: msg.message || "User denied permission",
    });
  }
}

// --- Cancel handler ---
function handleCancel() {
  if (currentQuery) {
    currentQuery.close();
    currentQuery = null;
  }
}

// --- Input summarizer (keep payloads compact for the UI) ---
function summarizeInput(toolName, input) {
  const summary = {};
  switch (toolName) {
    case "Bash":
      summary.command = input.command || "";
      if (input.description) summary.description = input.description;
      break;
    case "Edit":
      summary.file_path = input.file_path || "";
      summary.old_string =
        typeof input.old_string === "string"
          ? input.old_string.slice(0, 200)
          : "";
      summary.new_string =
        typeof input.new_string === "string"
          ? input.new_string.slice(0, 200)
          : "";
      break;
    case "Write":
      summary.file_path = input.file_path || "";
      summary.contentLength =
        typeof input.content === "string" ? input.content.length : 0;
      break;
    case "Read":
      summary.file_path = input.file_path || "";
      break;
    case "Glob":
      summary.pattern = input.pattern || "";
      if (input.path) summary.path = input.path;
      break;
    case "Grep":
      summary.pattern = input.pattern || "";
      if (input.path) summary.path = input.path;
      if (input.glob) summary.glob = input.glob;
      break;
    default:
      for (const [k, v] of Object.entries(input).slice(0, 5)) {
        summary[k] =
          typeof v === "string" ? v.slice(0, 200) : JSON.stringify(v);
      }
  }
  return summary;
}
