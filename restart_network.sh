#!/bin/bash

# Script to restart the network
# This script is called by network_monitor.py when network is unresponsive

echo "Starting network restart process..."

# Read GitHub link from file (first line)
if [ -f "/root/qubic/github_link.txt" ]; then
    FIRST_LINE=$(head -n 1 /root/qubic/github_link.txt)
    echo "First line from file: $FIRST_LINE"
    
    # Parse the line: "YYYY-MM-DD HH:MM:SS|GITHUB_LINK"
    if [[ "$FIRST_LINE" == *"|"* ]]; then
        GITHUB_LINK=$(echo "$FIRST_LINE" | cut -d'|' -f2)
        TIMESTAMP=$(echo "$FIRST_LINE" | cut -d'|' -f1)
        echo "GitHub link read from $TIMESTAMP: $GITHUB_LINK"
    else
        # Fallback for old format (just the link)
        GITHUB_LINK="$FIRST_LINE"
        echo "GitHub link read (old format): $GITHUB_LINK"
    fi
else
    echo "Error: GitHub link file not found"
    exit 1
fi

# Run cleanup
echo "Running cleanup..."
cd /root/qubic/qubic_docker
./cleanup.sh

# Wait a bit for cleanup to complete
sleep 10

# Run deploy
echo "Running deploy with GitHub link: $GITHUB_LINK"
./deploy.sh "$GITHUB_LINK"

echo "Network restart completed"
