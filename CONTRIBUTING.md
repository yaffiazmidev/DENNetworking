# Contributing to DENNetworking

Thank you for your interest in contributing to DENNetworking! This document provides guidelines to help you get started.

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/DENNetworking.git
   cd DENNetworking
   ```
3. **Open** the project:
   ```bash
   open Package.swift
   ```

## Development

### Requirements

- Xcode 15.0+
- Swift 5.10+
- Swift 6 language mode (the package uses `swift-tools-version: 6.0`)

### Project Structure

```
Sources/DENNetworking/
├── DENNetworkHTTPClient.swift            — Transport protocol
├── DENNetworkURLSessionHTTPClient.swift   — URLSession implementation
├── DENNetworkService.swift                — Status code mapping + decoding
├── DENNetworkError.swift                  — Typed error enum
├── Decorators/
│   ├── RetryHTTPClientDecorator.swift     — Automatic retry with backoff
│   └── AuthenticatedHTTPClientDecorator.swift — Auth + base URL decorator
└── Helper/
    ├── DENNetworkLogger.swift             — Opt-in request/response logger
    ├── MultipartFormData.swift            — Multipart form data builder
    └── URLRequest+Builder.swift           — Fluent request builder
```

### Running Tests

```bash
swift test
```

Or in Xcode: `Cmd + U`

### Running the Example App

```bash
open Example/Example.xcodeproj
```

## How to Contribute

### Reporting Bugs

1. Check existing [issues](https://github.com/yaffiazmidev/DENNetworking/issues) first
2. Open a new issue with:
   - A clear title
   - Steps to reproduce
   - Expected vs actual behavior
   - Swift/Xcode/OS version

### Suggesting Features

Open an issue with the `enhancement` label describing:
- What problem it solves
- Proposed API design
- Example usage

### Submitting Pull Requests

1. Create a branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Make your changes following the guidelines below
3. Write or update tests
4. Run `swift test` and ensure all tests pass
5. Commit with a clear message
6. Push to your fork and open a PR

## Guidelines

### Code Style

- Follow existing code conventions in the project
- Use Swift's standard naming conventions
- Add doc comments (`///`) for all public APIs
- Keep implementations focused and single-responsibility

### Architecture Principles

- **Protocol-first**: Define abstractions before implementations
- **Decorator pattern**: Add behavior by wrapping `DENNetworkHTTPClient`, not by modifying existing code
- **Sendable**: All public types must conform to `Sendable` for Swift 6 concurrency safety
- **Zero dependencies**: This library has no external dependencies — keep it that way

### Testing

- Write tests for all new functionality
- Use the existing test helpers (`HTTPClientStub`, etc.)
- Test both success and failure paths
- Keep tests fast — use stubs, not real network calls

### What We Look For in PRs

- Solves a real problem or adds meaningful functionality
- Follows existing patterns and architecture
- Includes tests with good coverage
- Does not break existing public API (or has a good reason to)
- Documentation for new public APIs

### Commit Messages

- Use present tense ("Add feature" not "Added feature")
- Keep the first line under 72 characters
- Reference issues when applicable (`Fix #123`)

## Code of Conduct

Be respectful and constructive. We are all here to build great software together. Harassment, discrimination, or toxic behavior will not be tolerated.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
