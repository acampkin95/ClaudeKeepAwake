# Changelog

All notable changes to ClaudeKeepAwake will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- AGENTS.md - Comprehensive codebase index and architecture documentation
- Build verification - Confirmed clean build with Swift 5.9

### Changed
- Updated CHANGELOG with accurate release history

## [0.1.0] - 2026-01-14

### Added
- Initial release
- Project structure established
- Core functionality:
  - Claude.app lifecycle monitoring (NSWorkspace notifications)
  - Automatic sleep prevention (IOPMAssertion)
  - Menubar status interface (NSStatusBar)
  - Optional window floating (AXUIElement + CGS private APIs)
  - Launch at login support (SMAppService)

### Infrastructure
- MIT License
- Swift Package Manager setup
- macOS 13.0+ target
- Custom build script (build.sh)
