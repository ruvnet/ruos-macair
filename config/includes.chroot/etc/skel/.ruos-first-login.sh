#!/bin/bash
# ruOS first-login setup — runs once then removes itself
MARKER="$HOME/.ruos-initialized"
[ -f "$MARKER" ] && exit 0

echo "╔══════════════════════════════════════════╗"
echo "║  ruOS — First Login Setup                ║"
echo "╚══════════════════════════════════════════╝"

# Install Rust
if ! command -v rustup &>/dev/null; then
    echo "==> Installing Rust toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    source "$HOME/.cargo/env"
fi

# Install Claude Code
if ! command -v claude &>/dev/null; then
    echo "==> Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code 2>/dev/null || true
fi

# Install claude-flow MCP
if command -v claude &>/dev/null; then
    claude mcp add claude-flow -- npx -y @claude-flow/cli@latest 2>/dev/null || true
fi

# Run ruvultra-init
if command -v ruvultra-init &>/dev/null; then
    echo "==> Running ruvultra-init..."
    ruvultra-init setup 2>/dev/null || true
fi

touch "$MARKER"
echo "==> ruOS initialized! Restart your terminal."
