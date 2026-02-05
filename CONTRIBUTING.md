# Contributing to Strata

Thanks for your interest in contributing to Strata! This document outlines how to get started.

## Development Setup

### Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 15+ (Swift 5.9+)
- Node.js 18+
- Claude Code CLI authenticated (`claude login`)

### Getting Started

```bash
# Clone the repo
git clone https://github.com/skargbo/Strata.git
cd Strata

# Install bridge dependencies
cd bridge && npm install && cd ..

# Build and run
swift build
swift run Strata
```

Or open `Package.swift` in Xcode and run from there.

## Project Structure

- `Sources/Strata/` — Swift app source
- `bridge/` — Node.js bridge to Claude Agent SDK
- `README.md` — User-facing documentation

## Making Changes

### Branch Naming

- `feature/description` — New features
- `fix/description` — Bug fixes
- `docs/description` — Documentation only

### Commit Messages

Use clear, concise commit messages:

```
Add skills catalog search integration

- Connect to skills.sh API
- Filter results to trusted sources
- Show install counts in UI
```

- Start with a verb (Add, Fix, Update, Remove, Refactor)
- First line under 72 characters
- Add bullet points for details if needed

### Code Style

- Follow existing patterns in the codebase
- Use Swift's standard naming conventions (camelCase for variables, PascalCase for types)
- Keep files focused — one major type per file
- Prefer clarity over brevity

### Testing

Before submitting:

```bash
swift build  # Must compile without errors
```

Run the app and manually verify your changes work as expected.

## Submitting a Pull Request

1. Fork the repository
2. Create a branch from `main`
3. Make your changes
4. Ensure `swift build` passes
5. Push to your fork
6. Open a PR against `main`

### PR Guidelines

- Keep PRs focused — one feature or fix per PR
- Include a clear description of what changed and why
- Add screenshots for UI changes
- Link related issues if applicable

## Reporting Issues

When opening an issue, include:

- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable
- Any error messages from Console.app

## Questions?

Open a [GitHub Discussion](https://github.com/skargbo/Strata/discussions) for questions or ideas that aren't bug reports or feature requests.

## License

By contributing, you agree that your contributions will be licensed under the same [BSL 1.1 License](LICENSE) that covers the project.
