# Security Policy

## Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.2.x   | :white_check_mark: |
| < 0.2   | :x:                |

## Reporting a Vulnerability

We take the security of this GitHub Action seriously. If you discover a security vulnerability, please follow these steps:

### 🔒 Please DO NOT:
- Open a public GitHub issue
- Discuss the vulnerability publicly until it has been addressed

### ✅ Please DO:

1. **Report via GitHub Security Advisories** (Preferred)
   - Go to the [Security tab](https://github.com/bitovi/github-actions-deploy-static-site-to-aws/security/advisories)
   - Click "Report a vulnerability"
   - Provide detailed information about the vulnerability

2. **Report via Email** (Alternative)
   - Email: security@bitovi.com
   - Include "[SECURITY] GitHub Actions Deploy Static Site" in the subject line

### What to Include in Your Report

Please provide as much information as possible:

- **Description**: Clear description of the vulnerability
- **Impact**: What could an attacker do with this vulnerability?
- **Reproduction Steps**: Detailed steps to reproduce the issue
- **Affected Versions**: Which versions are affected?
- **Possible Fix**: If you have suggestions for fixing the issue
- **Your Contact Information**: So we can follow up with questions

### What to Expect

1. **Acknowledgment**: We will acknowledge receipt of your report within 48 hours
2. **Investigation**: We will investigate and validate the vulnerability
3. **Updates**: We will keep you informed of our progress
4. **Resolution**: We will work on a fix and coordinate disclosure
5. **Credit**: We will publicly credit you for the discovery (unless you prefer to remain anonymous)

## Security Best Practices for Users

When using this action:

### 🔐 Secrets Management
- **Never** commit AWS credentials to your repository
- Always use GitHub Secrets for sensitive data
- Rotate AWS credentials regularly
- Use IAM roles with minimal required permissions

### 🛡️ AWS Permissions
Follow the principle of least privilege:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "cloudfront:CreateDistribution",
        "cloudfront:GetDistribution",
        "cloudfront:UpdateDistribution",
        "cloudfront:DeleteDistribution",
        "route53:ChangeResourceRecordSets",
        "acm:RequestCertificate",
        "acm:DescribeCertificate",
        "acm:DeleteCertificate"
      ],
      "Resource": "*"
    }
  ]
}
```

### 🔍 Code Review
- Review action updates before upgrading
- Pin to specific versions instead of using `@main`
- Monitor AWS CloudTrail for unexpected activity

### 📦 Terraform State
- Ensure S3 bucket for Terraform state has:
  - Encryption enabled
  - Versioning enabled
  - Access logging configured
  - Proper bucket policies

### 🚫 Don't:
- Use root AWS credentials
- Share AWS credentials across environments
- Commit `.tfvars` files with sensitive data
- Disable AWS CloudTrail logging

## Known Security Considerations

### Terraform State Files
Terraform state files may contain sensitive information. This action:
- Stores state in S3 with encryption
- Uses unique bucket names per deployment
- Supports state file destruction on cleanup

### Public S3 Buckets
This action creates **publicly accessible** S3 buckets by design (for static website hosting). Be aware:
- All files uploaded will be publicly readable
- Do not upload sensitive data
- Use CloudFront with restricted bucket access when possible

### Certificate Management
When using `aws_r53_create_root_cert` or `aws_r53_create_sub_cert`:
- Certificates are managed by Terraform
- **Certificates will be deleted** when the stack is destroyed
- Consider using `aws_r53_cert_arn` for production certificates

## Security Updates

We will:
- Release security patches as soon as possible
- Publish security advisories for confirmed vulnerabilities
- Credit reporters (unless they prefer anonymity)
- Maintain this security policy up to date

## Contact

For security concerns, contact:
- GitHub Security Advisories: [Report a vulnerability](https://github.com/bitovi/github-actions-deploy-static-site-to-aws/security/advisories)
- Email: security@bitovi.com
- Discord: [Bitovi Community](https://discord.gg/J7ejFsZnJ4Z) (for general security questions, not vulnerabilities)

Thank you for helping keep this project secure! 🔒
