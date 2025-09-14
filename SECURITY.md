# Security Guidelines for ClaudeCodeUI

## Important: Protecting Your Credentials

This project includes scripts for building and distributing the app that require Apple Developer credentials. **NEVER commit sensitive information to the repository.**

### Files That Should NEVER Be Committed

The following files are already in `.gitignore` and should never be committed:

- `scripts/signing_config.sh` - Contains your Apple ID and app-specific password
- `*.p12` - Certificate files
- `*.cer` - Certificate files
- `*.key` - Private key files
- `*.certSigningRequest` - CSR files
- `DeveloperID_*` - Any Developer ID related files

### Setting Up Your Credentials Securely

1. **Copy the template file:**
   ```bash
   cp scripts/signing_config_template.sh scripts/signing_config.sh
   ```

2. **Edit `scripts/signing_config.sh`** with your actual credentials:
   - `APPLE_ID`: Your Apple ID email
   - `APP_PASSWORD`: App-specific password from appleid.apple.com
   - `TEAM_ID`: Your Apple Developer Team ID (this is okay to keep public)

3. **Verify it's ignored by git:**
   ```bash
   git status
   # Should NOT show scripts/signing_config.sh
   ```

### For GitHub Actions

If you're using GitHub Actions for automated releases, add these secrets to your repository:

1. Go to Settings → Secrets and variables → Actions
2. Add the following repository secrets:
   - `APPLE_ID`: Your Apple ID email
   - `APP_PASSWORD`: App-specific password
   - `TEAM_ID`: Your Team ID
   - `CERTIFICATE_BASE64`: Your certificate in base64
   - `CERTIFICATE_PASSWORD`: Certificate password
   - `KEYCHAIN_PASSWORD`: A random password for the temporary keychain

### Creating an App-Specific Password

1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. Go to "Sign-In and Security" → "App-Specific Passwords"
4. Click the "+" to generate a new password
5. Name it "ClaudeCodeUI Notarization"
6. Copy the generated password (format: xxxx-xxxx-xxxx-xxxx)

### If You Accidentally Committed Secrets

If you accidentally committed sensitive information:

1. **Immediately revoke the exposed credentials:**
   - Revoke the app-specific password at appleid.apple.com
   - Create a new one

2. **Remove from git history** (this won't help if already pushed to GitHub):
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch scripts/signing_config.sh" \
     --prune-empty --tag-name-filter cat -- --all
   ```

3. **Force push** (if the repo is public, consider the credentials compromised):
   ```bash
   git push origin --force --all
   ```

4. **Create new credentials** immediately

### Best Practices

1. **Use environment variables** for CI/CD instead of hardcoding
2. **Rotate app-specific passwords** periodically
3. **Use separate passwords** for different purposes
4. **Never share** your signing_config.sh file
5. **Always verify** with `git status` before committing

### For Open Source Contributors

If you're contributing to this project:
- Never ask for someone's credentials
- Test with your own Apple Developer account
- Use the template files as reference
- Report security issues privately to the maintainer