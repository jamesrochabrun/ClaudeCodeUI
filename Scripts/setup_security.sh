#!/bin/bash

# Setup Security Script
# Run this once to set up git hooks and security measures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔒 Setting up security measures..."
echo ""

# Install git hooks
echo "Installing git pre-commit hook..."
if [ -f ".githooks/pre-commit" ]; then
  # Make the hook executable
  chmod +x .githooks/pre-commit

  # Configure git to use our hooks directory
  git config core.hooksPath .githooks

  echo -e "${GREEN}✅ Git hooks installed${NC}"
else
  echo -e "${YELLOW}⚠️  Pre-commit hook not found${NC}"
fi

# Make security scripts executable
echo ""
echo "Making security scripts executable..."
chmod +x Scripts/security_check.sh 2>/dev/null || true
chmod +x Scripts/release.sh 2>/dev/null || true

# Check if signing_config.sh exists
echo ""
if [ ! -f "Scripts/signing_config.sh" ]; then
  echo -e "${YELLOW}📋 Creating signing_config.sh from template...${NC}"
  if [ -f "Scripts/signing_config_template.sh" ]; then
    cp Scripts/signing_config_template.sh Scripts/signing_config.sh
    echo -e "${GREEN}✅ Created Scripts/signing_config.sh${NC}"
    echo ""
    echo "⚠️  Remember to edit Scripts/signing_config.sh with your credentials:"
    echo "  - APPLE_ID"
    echo "  - APP_PASSWORD"
  fi
else
  echo -e "${GREEN}✅ signing_config.sh already exists${NC}"
fi

# Verify .gitignore
echo ""
echo "Verifying .gitignore..."
if grep -q "signing_config.sh" .gitignore; then
  echo -e "${GREEN}✅ .gitignore is properly configured${NC}"
else
  echo -e "${YELLOW}⚠️  Adding security entries to .gitignore...${NC}"
  echo "" >> .gitignore
  echo "# Security - Never commit these!" >> .gitignore
  echo "Scripts/signing_config.sh" >> .gitignore
  echo "scripts/signing_config.sh" >> .gitignore
  echo "*.p12" >> .gitignore
  echo "*.cer" >> .gitignore
  echo "*.key" >> .gitignore
fi

# Run initial security check
echo ""
echo "Running security check..."
bash Scripts/security_check.sh || true

echo ""
echo "================================"
echo -e "${GREEN}🎉 Security setup complete!${NC}"
echo ""
echo "Security features enabled:"
echo "✅ Pre-commit hook will run before every commit"
echo "✅ Security check script available: Scripts/security_check.sh"
echo "✅ Automated release script: Scripts/release.sh"
echo ""
echo "To bypass the pre-commit hook (use with caution):"
echo "  git commit --no-verify"
echo ""
echo "To run security check manually:"
echo "  ./Scripts/security_check.sh"
echo ""
echo "To create a release:"
echo "  ./Scripts/release.sh"