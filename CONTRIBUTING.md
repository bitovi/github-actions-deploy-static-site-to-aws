# Contributing to Deploy Static Site to AWS

Thank you for your interest in contributing to this GitHub Action! We welcome contributions from the community.

## How to Contribute

### Reporting Issues

If you encounter a bug or have a feature request:

1. Check if the issue already exists in [GitHub Issues](https://github.com/bitovi/github-actions-deploy-static-site-to-aws/issues)
2. If not, create a new issue with:
   - A clear, descriptive title
   - Detailed description of the problem or feature
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Your environment details (OS, versions, etc.)

### Submitting Changes

1. **Fork the Repository**
   ```bash
   git clone https://github.com/your-username/github-actions-deploy-static-site-to-aws.git
   cd github-actions-deploy-static-site-to-aws
   ```

2. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

3. **Make Your Changes**
   - Follow the existing code style
   - Add tests if applicable
   - Update documentation as needed

4. **Test Your Changes**
   - Run shellcheck on bash scripts: `shellcheck scripts/*.sh`
   - Validate Terraform: `terraform fmt -check -recursive terraform_code/`
   - Test the action in a real workflow if possible

5. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "Brief description of your changes"
   ```
   
   Use conventional commit messages:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation changes
   - `refactor:` for code refactoring
   - `test:` for adding tests
   - `chore:` for maintenance tasks

6. **Push to Your Fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Open a Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Select your fork and branch
   - Fill in the PR template with details about your changes

## Development Guidelines

### Shell Scripts

- Use `#!/usr/bin/env bash` for portability
- Always use `set -e` to fail on errors
- Quote all variables: `"$VARIABLE"` instead of `$VARIABLE`
- Use GitHub Actions annotations for errors: `echo "::error::message"`
- Add comments for complex logic

### Terraform

- Run `terraform fmt` before committing
- Keep resources organized in appropriate files:
  - `s3.tf` - S3 buckets and policies
  - `cloudfront.tf` - CloudFront distributions
  - `route53.tf` - DNS records
  - `certificates.tf` - ACM certificates
  - `locals.tf` - Local variables and outputs
- Add descriptions to all variables and outputs
- Use conditional resources with `count` for optional features

### Documentation

- Update README.md for user-facing changes
- Add inline comments for complex code
- Include examples for new features
- Update CHANGELOG.md (see below)

### CHANGELOG

When making changes, update the CHANGELOG.md:

```markdown
## [Unreleased]
### Added
- Description of new feature

### Changed
- Description of changes to existing functionality

### Fixed
- Description of bug fixes
```

## Code Review Process

1. A maintainer will review your PR
2. Address any requested changes
3. Once approved, a maintainer will merge your PR
4. Your contribution will be included in the next release!

## Testing

While we don't currently have automated tests for everything, please manually test:

- Bash scripts with ShellCheck
- Terraform with `terraform validate`
- The action in a real workflow when possible

## Community

- Join our [Discord Channel](https://discord.gg/J7ejFsZnJ4Z) for discussions
- Be respectful and follow our Code of Conduct
- Help others in discussions and issues

## Questions?

If you have questions about contributing, feel free to:
- Open a discussion in GitHub Discussions
- Ask in our Discord channel
- Reach out to the maintainers

Thank you for making this project better! 🎉
