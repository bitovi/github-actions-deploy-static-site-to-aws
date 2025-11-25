# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `.gitignore` file to exclude generated files and Terraform state
- `.editorconfig` for consistent code formatting across editors
- `CONTRIBUTING.md` with contribution guidelines
- `SECURITY.md` with security policy and best practices
- `CHANGELOG.md` to track version history
- GitHub Actions CI workflow for automated testing
  - ShellCheck for bash script validation
  - Terraform validation and formatting checks
  - Markdown linting

### Changed
- Refactored Terraform code into separate files for better organization:
  - `s3.tf` - S3 bucket resources and policies
  - `cloudfront.tf` - CloudFront distributions
  - `route53.tf` - Route53 DNS records
  - `certificates.tf` - ACM certificates
  - `locals.tf` - Local variables and outputs
  - `main.tf` - Now minimal, references other files
- Optimized rsync operation in `generate_deploy.sh` to eliminate duplicate code
- Improved error messages with GitHub Actions annotations (`::error::`, `::warning::`)
- Enhanced bucket deletion script with better error handling

### Fixed
- Typo in `action.yaml`: "abd" → "and" in Route53 comment
- Arithmetic comparison in `create_tf_state_bucket.sh`: changed string comparison to numeric
- Bash variable quoting in `generate_identifier.sh` for better safety
- Added `set -e` to `create_tf_state_bucket.sh` for consistency
- Better error messages with specific character counts for FQDN length errors
- Added graceful failure handling for bucket deletion

## [0.2.7] - Previous Release

### Features
- Static site deployment to AWS S3
- Optional CloudFront CDN integration
- Route53 DNS management
- Automatic SSL certificate creation and validation
- Customizable error pages
- Cache control settings
- Support for custom domains and subdomains

---

**Note**: For releases prior to the current development version, please refer to [GitHub Releases](https://github.com/bitovi/github-actions-deploy-static-site-to-aws/releases).
