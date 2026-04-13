#!/bin/bash
cd "$(dirname "$0")"

if ! command -v uv &> /dev/null; then
    echo "Installing uv (Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

mkdir -p data

echo ""
echo "  Inventory Tracker is starting..."
echo "  Opening your browser now."
echo ""
echo "  To stop the server, close this window or press Ctrl+C."
echo ""

sleep 1 && open "http://localhost:5050" &

uv run app.py
