#!/bin/bash
# Find the inventory-tracker repo anywhere under the user's home directory
REPO=$(find "$HOME" -maxdepth 4 -name "inventory-tracker" -type d -exec test -e "{}/pyproject.toml" \; -print -quit 2>/dev/null)

if [ -z "$REPO" ]; then
    echo "Could not find the inventory-tracker folder."
    echo "Make sure the repo is somewhere in your home directory."
    echo ""
    read -p "Press Enter to close..."
    exit 1
fi

cd "$REPO"

if ! command -v uv &> /dev/null; then
    echo "Installing uv (Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

mkdir -p data

# Kill any existing instance
pkill -f "app.py" 2>/dev/null
sleep 0.5

# Start server in background, detached from terminal
nohup uv run app.py > /dev/null 2>&1 &
disown

# Wait for server to be ready, then open browser
sleep 1
open "http://localhost:5050"

# Close this terminal window
osascript -e 'tell application "Terminal" to close front window' &
