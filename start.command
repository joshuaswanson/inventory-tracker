#!/bin/bash
cd "$(dirname "$0")"

if ! command -v python3 &> /dev/null; then
    echo "Python 3 is required but not installed."
    echo "Download it from https://www.python.org/downloads/"
    echo ""
    read -p "Press Enter to close..."
    exit 1
fi

if [ ! -d "venv" ]; then
    echo "First-time setup (this only happens once)..."
    python3 -m venv venv
fi

source venv/bin/activate
pip install -q -r requirements.txt 2>/dev/null

mkdir -p data

echo ""
echo "  Inventory Tracker is starting..."
echo "  Opening your browser now."
echo ""
echo "  To stop the server, close this window or press Ctrl+C."
echo ""

sleep 1 && open "http://localhost:5050" &

python3 app.py
