# Contributing

Issues and pull requests are welcome.

## Development setup

1. Use macOS 12 or later with Xcode Command Line Tools installed.
2. Clone the repository.
3. Run `quota-overlay/build.sh`.
4. Confirm that all parser and localization self-tests pass.
5. Run `launcher/build.sh` when changing launcher behavior.

Keep the application native and dependency-light. Do not add analytics, telemetry, credential scraping, or shell-based parsing of untrusted quota responses.

## Pull requests

- Explain the user-visible behavior and compatibility impact.
- Add or update parser self-tests for response-shape changes.
- Keep English, Simplified Chinese, Japanese, and Spanish strings aligned.
- Verify both `arm64` and `x86_64` slices.
- Do not commit build products, credentials, account data, or screenshots containing personal information.
