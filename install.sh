#!/usr/bin/env bash
# install.sh — standalone installer for Ghost v2.0.0
# Installs prebuilt ghost-popup binary or compiles from source.
set -euo pipefail

VERSION="2.0.1"
REPO="Pakrohk/ziro-ghost"
PREFIX="${PREFIX:-$HOME/.local}"
FROM_SOURCE=0
QUIET=0
NO_VERIFY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-source)
      FROM_SOURCE=1
      shift
      ;;
    --prefix)
      PREFIX="$2"
      shift 2
      ;;
    --no-verify)
      NO_VERIFY=1
      shift
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    --help|-h)
      cat << 'EOF'
Usage: install.sh [OPTIONS]

Options:
  --from-source      Compile from source using Cargo (skips downloading release binary)
  --prefix <PATH>    Target installation prefix (default: ~/.local)
  --no-verify        Skip post-install binary execution test
  --quiet            Suppress informative output
  --help, -h         Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
TARGET=""

case "$OS-$ARCH" in
  linux-x86_64) TARGET="linux-x86_64" ;;
  linux-aarch64|linux-arm64) TARGET="linux-aarch64" ;;
  darwin-x86_64) TARGET="darwin-x86_64" ;;
  darwin-arm64) TARGET="darwin-arm64" ;;
  *)
    TARGET=""
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="$PREFIX/bin/ghost-popup"
mkdir -p "$PREFIX/bin"

if [[ $FROM_SOURCE -eq 1 ]] || [[ -z "$TARGET" ]]; then
  if [[ $QUIET -eq 0 ]]; then
    echo "Compiling ghost-popup from source (requires Cargo)..."
  fi
  command -v cargo >/dev/null 2>&1 || {
    echo "Error: cargo is required for building from source." >&2
    exit 1
  }
  cd "$SCRIPT_DIR"
  cargo build --release
  BUILT_BIN="$SCRIPT_DIR/target/release/ghost-popup"
  if [[ ! -f "$BUILT_BIN" ]]; then
    BUILT_BIN="$SCRIPT_DIR/crates/ghost-popup/target/release/ghost-popup"
  fi
  cp "$BUILT_BIN" "$BIN_DEST"
  chmod +x "$BIN_DEST"
else
  URL="https://github.com/${REPO}/releases/download/v${VERSION}/ghost-popup-${TARGET}"
  if [[ $QUIET -eq 0 ]]; then
    echo "Downloading prebuilt binary from $URL..."
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fSL -o "$BIN_DEST" "$URL" 2>/dev/null || {
      if [[ $QUIET -eq 0 ]]; then
        echo "Prebuilt binary download failed, falling back to source compilation..."
      fi
      cd "$SCRIPT_DIR"
      cargo build --release
      BUILT_BIN="$SCRIPT_DIR/target/release/ghost-popup"
      cp "$BUILT_BIN" "$BIN_DEST"
    }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$BIN_DEST" "$URL" 2>/dev/null || {
      cd "$SCRIPT_DIR"
      cargo build --release
      cp "$SCRIPT_DIR/target/release/ghost-popup" "$BIN_DEST"
    }
  else
    echo "Error: curl or wget is required for downloading release binary." >&2
    exit 1
  fi
  chmod +x "$BIN_DEST"
fi

if [[ $NO_VERIFY -eq 0 ]]; then
  if ! "$BIN_DEST" --version >/dev/null 2>&1; then
    echo "Warning: binary installed at $BIN_DEST failed verification." >&2
  fi
fi

if [[ $QUIET -eq 0 ]]; then
  echo "Successfully installed ghost-popup to $BIN_DEST"
  echo "Ensure $PREFIX/bin is in your PATH."
  echo "Add to your ~/.zshrc:"
  echo "  source \"${SCRIPT_DIR}/ghost.plugin.zsh\""
fi
