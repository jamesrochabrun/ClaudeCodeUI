#!/bin/bash

# Create Certificate Signing Request for Developer ID Application
# This generates a CSR file needed to create a Developer ID certificate

# Configuration
EMAIL="${APPLE_ID:-your-email@example.com}"
CN="James Rochabrun"  # Your name as it appears in your Apple Developer account
C="US"  # Country code (2 letters)

# Output files
KEY_FILE="$HOME/Desktop/DeveloperID_PrivateKey.key"
CSR_FILE="$HOME/Desktop/DeveloperID_CSR.certSigningRequest"

echo "Creating Certificate Signing Request..."
echo "This will create:"
echo "  - Private key: $KEY_FILE"
echo "  - CSR file: $CSR_FILE"
echo ""

# Generate private key and CSR
openssl req -new -newkey rsa:2048 -nodes \
  -keyout "$KEY_FILE" \
  -out "$CSR_FILE" \
  -subj "/emailAddress=$EMAIL/CN=$CN/C=$C"

if [ -f "$CSR_FILE" ] && [ -f "$KEY_FILE" ]; then
  echo "✅ Success! Files created:"
  echo ""
  echo "1. CSR file created at: $CSR_FILE"
  echo "   👉 Upload this file to Apple Developer portal"
  echo ""
  echo "2. Private key saved at: $KEY_FILE"
  echo "   ⚠️  KEEP THIS SAFE! You'll need it later"
  echo ""
  echo "Next steps:"
  echo "1. Click 'Choose File' in the Apple Developer portal"
  echo "2. Select: $CSR_FILE"
  echo "3. Click 'Continue'"
  echo "4. Download the certificate when ready"
  echo "5. Double-click the downloaded certificate to install it"
else
  echo "❌ Error creating CSR files"
  exit 1
fi