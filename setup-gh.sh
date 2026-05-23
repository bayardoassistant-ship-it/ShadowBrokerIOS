#!/bin/bash
# Run this on your Mac or anywhere with gh authenticated:
#   bash setup-gh.sh

set -e

REPO="ShadowBrokerIOS"

# Check gh auth
if ! gh auth status &>/dev/null; then
  echo "❌ gh not authenticated. Run: gh auth login"
  exit 1
fi

echo "✓ gh authenticated"

# Create repo
gh repo create "$REPO" --public --description "Real-time ADS-B / OSINT aircraft intelligence client for iPhone & iPad" --source . --push 2>/dev/null || {
  echo "Repo may already exist. Pushing..."
  git remote add origin "git@github.com:$(gh api user -q .login)/$REPO.git" 2>/dev/null || true
  git push -u origin main
}

echo ""
echo "✅ Repo pushed: https://github.com/$(gh api user -q .login)/$REPO"
echo ""
echo "⏳ Build workflow will run automatically on push."
echo "   Check Actions tab for your .app artifact."
