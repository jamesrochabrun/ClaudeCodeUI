#!/bin/bash

# Security Check Script
# Run this before committing to ensure no sensitive data is exposed

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔒 Running Security Check..."
echo ""

ISSUES_FOUND=0

# Check for sensitive patterns in staged files
check_staged_files() {
  echo "Checking staged files for sensitive data..."

  # Patterns to search for
  PATTERNS=(
    "api[_-]?key"
    "private[_-]?key"
  )

  # Get list of staged files
  STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

  if [ -z "$STAGED_FILES" ]; then
    echo "No staged files to check"
    return
  fi

  for pattern in "${PATTERNS[@]}"; do
    # Search in staged content
    FOUND=$(git diff --cached --diff-filter=ACM | grep -i "$pattern" 2>/dev/null || true)
    if [ ! -z "$FOUND" ]; then
      echo -e "${RED}❌ Found potential sensitive data matching pattern: $pattern${NC}"
      echo "$FOUND" | head -3
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done
}

# Check if sensitive files are being tracked
check_sensitive_files() {
  echo ""
  echo "Checking for sensitive files..."

  SENSITIVE_FILES=(
    "Scripts/signing_config.sh"
    "scripts/signing_config.sh"
  )

  for file in "${SENSITIVE_FILES[@]}"; do
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
      echo -e "${RED}❌ Sensitive file is being tracked: $file${NC}"
      echo "  Run: git rm --cached $file"
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done

  # Check for certificate files
  CERT_FILES=$(git ls-files "*.p12" "*.cer" "*.key" "*.certSigningRequest" 2>/dev/null)
  if [ ! -z "$CERT_FILES" ]; then
    echo -e "${RED}❌ Certificate files are being tracked:${NC}"
    echo "$CERT_FILES"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  fi
}

# Check if .gitignore is properly configured
check_gitignore() {
  echo ""
  echo "Checking .gitignore configuration..."

  REQUIRED_IGNORES=(
    "signing_config.sh"
    "*.p12"
    "*.cer"
    "*.key"
  )

  for pattern in "${REQUIRED_IGNORES[@]}"; do
    if ! grep -q "$pattern" .gitignore 2>/dev/null; then
      echo -e "${YELLOW}⚠️  Missing in .gitignore: $pattern${NC}"
    fi
  done
}

# Check for hardcoded credentials in specific files
check_hardcoded_credentials() {
  echo ""
  echo "Checking for hardcoded credentials..."

  # Files that should not contain real credentials
  FILES_TO_CHECK=(
    "Scripts/notarize.sh"
    "Scripts/build_app.sh"
    "Scripts/export_options.plist"
    ".github/workflows/release.yml"
  )

  for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
      # Check for email patterns
      if grep -q ".*@.*\.com" "$file" 2>/dev/null; then
        FOUND_EMAIL=$(grep ".*@.*\.com" "$file" | grep -v "example.com" | grep -v "YOUR_.*@" || true)
        if [ ! -z "$FOUND_EMAIL" ]; then
          echo -e "${YELLOW}⚠️  Possible email in $file${NC}"
          echo "  $FOUND_EMAIL"
        fi
      fi

      # Check for app password pattern (xxxx-xxxx-xxxx-xxxx)
      if grep -E "[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}" "$file" >/dev/null 2>&1; then
        echo -e "${RED}❌ Possible app password in $file${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
      fi
    fi
  done
}

# Run all checks
check_staged_files
check_sensitive_files
check_gitignore
check_hardcoded_credentials

echo ""
echo "================================"
if [ $ISSUES_FOUND -eq 0 ]; then
  echo -e "${GREEN}✅ Security check passed!${NC}"
  echo "It's safe to commit."
else
  echo -e "${RED}❌ Security check failed!${NC}"
  echo "Found $ISSUES_FOUND potential security issues."
  echo ""
  echo "Please review and fix the issues above before committing."
  echo "If you're sure these are false positives, you can commit with:"
  echo "  git commit --no-verify"
  exit 1
fi