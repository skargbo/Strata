# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Strata, please report it privately rather than opening a public issue.

**Email:** Open a private security advisory via [GitHub Security Advisories](https://github.com/skargbo/Strata/security/advisories/new)

Please include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fixes (optional)

## Response Timeline

- **Acknowledgment:** Within 48 hours
- **Initial assessment:** Within 7 days
- **Resolution target:** Depends on severity, typically within 30 days

## Scope

This policy covers:

- The Strata macOS application (`Sources/Strata/`)
- The Node.js bridge (`bridge/`)
- Any official releases

## Out of Scope

- Vulnerabilities in dependencies (report to upstream maintainers)
- Vulnerabilities in Claude Code or the Anthropic API
- Issues requiring physical access to the machine

## Security Considerations

Strata handles potentially sensitive data:

- **API credentials** — Uses Claude Code's OAuth or `ANTHROPIC_API_KEY`
- **Session data** — Conversations stored in `~/Library/Application Support/Strata/`
- **Working directory access** — Claude can read/write files based on permission mode

Users should:

- Use "Guided" permission mode for sensitive projects
- Review tool invocations before approving
- Avoid sharing session export files containing sensitive conversations

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| Older   | No        |

Only the latest release receives security updates.
