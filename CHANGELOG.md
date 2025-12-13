# Changelog
All notable changes to the hblink3-docker-install project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **BREAKING CHANGE - Modern Python Package Management**: For Debian 12+ (Bookworm/Trixie), HBMonv2 now uses a Python virtual environment instead of system-wide package installation
- HBMonv2 Python dependencies installed in isolated virtual environment at `/opt/HBMonv2/venv` for Debian 12+
- pip_install helper function now uses virtual environment for Debian 12+ (PEP 668 compliant)
- systemd service file automatically configured to use virtual environment Python interpreter for Debian 12+
- Added python3-venv to system dependencies for Debian 12+
- Enhanced pip_install helper function with comprehensive error handling and user feedback
- Added proper error checking after all pip package installations
- Improved error messages to help users diagnose installation failures
- Added directory verification before installing from requirements.txt
- Changed deprecated --force flag to --force-reinstall for attrs package installation

### Fixed
- **Resolved externally-managed-environment errors on Debian 12/13** by using virtual environments instead of --break-system-packages flag
- **Resolved package conflicts with system-installed cryptography** by isolating Python packages in virtual environment
- Silent pip installation failures now properly reported to users
- Missing requirements.txt file now handled gracefully with warning instead of silent failure
- pip installation errors now cause the installer to exit with proper error messages

### Technical Details
- Debian 10-11: Continues to use standard system-wide pip installation (backward compatible)
- Debian 12+: Uses modern virtual environment approach following PEP 668 standards
- Virtual environment is automatically activated during installation
- pip is upgraded within the virtual environment for latest features

## [1.5.0] - 2024-12-13

### Verified
- Full Debian 13 (Trixie) support confirmed working (33/33 tests passed)
- Upstream repository compatibility verified:
  - hblink3: https://github.com/ShaYmez/hblink3 (accessible, recently updated for Debian compatibility)
  - HBMonv2: https://github.com/ShaYmez/HBMonv2 (accessible, all dependencies compatible)
- pip installation with --break-system-packages flag working correctly for Debian 12+
- docker-compose-plugin installation working correctly for Debian 12+
- All control scripts validated (syntax and functionality)
- Version detection logic confirmed for Debian 13
- Documentation accurately references Debian 13 (Trixie) support

### Added
- CHANGELOG.md to track project changes and releases

## [1.4.0] - 2024-12-13
### Note
This version corresponds to installer version 13122025

### Added
- Debian 13 (Trixie) support
- Docker version alpine-3.18 compatibility
- Enhanced pip installation handling for Debian 12+ with PEP 668 compliance
- docker-compose-plugin support for modern Debian versions
- Fallback mechanism for docker-compose installation from GitHub releases

### Changed
- Updated installer to handle Debian 12 and 13 with --break-system-packages pip flag
- Improved docker-compose installation logic for newer Debian versions
- Enhanced version detection and branching logic

### Fixed
- pip installation issues on Debian 12+ due to externally-managed-environment restrictions

## [Previous] - Earlier Releases

### Supported
- Debian 10 (Buster) support
- Debian 11 (Bullseye) support
- Debian 12 (Bookworm) support
- Ubuntu 20.04 support
- Multi-architecture Docker builds (x86_64, armv6/7, aarch64, ppc64)

### Features
- Complete HBlink3 server installation via Docker
- HBMonv2 dashboard integration
- Built-in Parrot functionality (configurable)
- Automatic JSON file downloads (RadioID database)
- systemd service management
- Control scripts for easy management:
  - hblink-menu (interactive menu system)
  - hblink-start/stop/restart
  - hblink-update (Docker image updates)
  - hblink-flush (service cleanup)
  - hblink-uninstall (complete removal)
  - hblink-initial-setup (first-time configuration)
  - hblink-upgrade (future upgrades)
- Apache2 web server integration
- Automated cron jobs for log management
- Comprehensive logging to /var/log/hblink

### Installation Components
- Docker CE from official Docker repository
- docker-compose or docker-compose-plugin (version-dependent)
- Python 3 with required dependencies
- HBlink3 from https://github.com/ShaYmez/hblink3
- HBMonv2 from https://github.com/ShaYmez/HBMonv2
- Apache2 with PHP support
- systemd service files

### Security
- Proper file permissions (755/777) on critical directories
- Container user separation (UID 54000)
- Docker userland-proxy disabled for performance
- Root privilege checks before installation

### Documentation
- Comprehensive README.md with installation instructions
- Support for Debian 10, 11, 12, and 13 (Trixie)
- Port forwarding documentation
- Parrot feature configuration guide
- Uninstallation instructions

## Repository Information

### Upstream Dependencies
- **HBlink3:** https://github.com/ShaYmez/hblink3
- **HBMonv2:** https://github.com/ShaYmez/HBMonv2

### Compatibility Matrix
| Debian Version | Status | Notes |
|---------------|---------|-------|
| Debian 10 (Buster) | ✅ Supported | Uses standard apt packages |
| Debian 11 (Bullseye) | ✅ Supported | Uses standard apt packages |
| Debian 12 (Bookworm) | ✅ Supported | Uses docker-compose-plugin and --break-system-packages |
| Debian 13 (Trixie) | ✅ Supported | Uses docker-compose-plugin and --break-system-packages |
| Ubuntu 20.04 | ✅ Supported | Tested and working |

### Architecture Support
- x86_64 (64-bit Intel/AMD)
- armv6/armv7 (Raspberry Pi and similar)
- aarch64 (ARM 64-bit)
- ppc64 (PowerPC 64-bit)
- Additional architectures via Docker multi-arch support

## Maintenance Notes

### Known Issues
- None currently reported for Debian 13 support

### Upgrade Path
- Users can upgrade from any Debian 10/11/12 installation to Debian 13
- Existing configurations are preserved during system upgrades
- Use `hblink-update` to pull latest Docker images after OS upgrade

### Testing
- All installations should be performed on clean systems
- Destructive installer - not recommended for systems with existing software
- Minimum requirements: 1 core, 512MB RAM, adequate disk space

## Contributing
For bugs, features, or support, please visit:
- Main Repository: https://github.com/ShaYmez/hblink3-docker-install
- HBlink3 Repository: https://github.com/ShaYmez/hblink3
- HBMonv2 Repository: https://github.com/ShaYmez/HBMonv2
- Official HBlink3 Upstream: https://github.com/HBLink-org/hblink3

## Credits
- **Maintainer:** Shane Daley - M0VUB (M0VUB)
- **Contact:** shane@freestar.network
- **Dashboard:** HBMonv2 by Weldek SP2ONG
- **License:** GNU General Public License v3.0

---
*For detailed installation instructions, see [README.md](README.md)*
