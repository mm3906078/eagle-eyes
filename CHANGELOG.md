# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Automated release workflow using GitHub Actions
- Release script for version management (`scripts/release.sh`)
- Comprehensive CI/CD pipeline with testing, building, and releasing
- Release artifacts for both agent and master applications

### Changed
- Updated GitHub Actions workflow to include proper release management
- Enhanced Makefile with release targets
- Improved documentation with release instructions

### Fixed
- Updated deprecated GitHub Actions versions

## [0.1.0] - 2024-10-05

### Added
- Initial release of Eagle Eyes vulnerability scanner
- Agent application for scanning servers
- Master application for managing agents and notifications
- Web interface for monitoring and management
- Telegram bot integration for notifications
- Support for Ubuntu 22.04/Debian 12 systems

### Features
- Vulnerability scanning of installed packages
- Centralized management of multiple agents
- Real-time notifications via Telegram
- Web-based dashboard for monitoring
- Distributed architecture for scalability

[Unreleased]: https://github.com/mm3906078/eagle-eyes/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mm3906078/eagle-eyes/releases/tag/v0.1.0
