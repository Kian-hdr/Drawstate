# Contributing

Thank you for improving Drawstate.

## Development

Requirements: macOS 14 or later, Xcode with Swift 6.1 or later, and Git.

```sh
git clone https://github.com/Kian-hdr/Drawstate.git
cd Drawstate
swift test
./Scripts/package-app.sh release
open build/Drawstate.app
```

Read `AGENTS.md` before making architecture or menu-bar changes. Keep telemetry parsing and calculations in `DrawstateCore` when practical and add tests for behavior changes.

## Pull requests

- Keep changes focused.
- Explain user-visible behavior and hardware assumptions.
- Run `swift test` and a Release build.
- Never add analytics, network access, administrator requirements, raw SMC writes, or private data collection.
- Treat charge-limit control as experimental and preserve graceful failure.

By contributing, you agree that your contribution is licensed under the MIT License.
