#!/usr/bin/env bash
cd "$(dirname "$0")"

if command -v love &> /dev/null; then
    love .
elif [ -d "/Applications/love.app" ]; then
    /Applications/love.app/Contents/MacOS/love .
elif [ -d "/Applications/Love.app" ]; then
    /Applications/Love.app/Contents/MacOS/love .
else
    echo "Love2D not found in /Applications. Please install Love2D."
    exit 1
fi
