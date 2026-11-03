#!/bin/bash

set -e

# --- Setup paths ---
if [ -z "${TOOLCHAINSPATH+x}" ]; then
  TOOLCHAINSPATH="$HOME/toolchains"
fi

if [ -z "${WINDOWSMSVCSYSROOT+x}" ]; then
  WINDOWSMSVCSYSROOT="$TOOLCHAINSPATH/windows-msvc-sysroot"
fi

# --- Make sure the sysroot checkout exists (it is NOT cloned here) ---
if [ ! -d "$WINDOWSMSVCSYSROOT" ]; then
  echo "❌ $WINDOWSMSVCSYSROOT does not exist. Clone your windows-msvc-sysroot repo first."
  exit 1
fi

if [ ! -d "$WINDOWSMSVCSYSROOT/.git" ]; then
  echo "❌ $WINDOWSMSVCSYSROOT is not a git repository"
  exit 1
fi

cd "$WINDOWSMSVCSYSROOT"

echo "🧹 Cleaning entire history of $WINDOWSMSVCSYSROOT"

# 1. Create a new orphan branch (a branch with no history)
git checkout --orphan temp-branch

# 2. Add all files in the current directory to staging
git add -A

# 3. Commit the current state with your desired message
git commit -m "cleanup entire history of repo"

# 4. Delete the old main branch
git branch -D main || true

# 5. Rename the current branch to main
git branch -m main

# 6. Push to a Remote Repository
git push -u origin main --force

echo "windows-msvc-sysroot history cleanup completed successfully! 🚀"
