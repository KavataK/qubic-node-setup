#!/bin/bash

# Script Name: cleanup.sh
# Description: This script kills the broadcaster.py process, stops the Docker container running the qubic-docker image, kills the go-qubic-nodes process, stops the ./server process, kills the epoch_switcher.py process, and runs docker-compose down in the /root/qubic/qubic-docker/ directory.

# Step 1: Kill the broadcaster.py process
echo "Killing broadcaster.py process..."
pkill -f broadcaster.py

# Check if the process was killed
if [ $? -eq 0 ]; then
    echo "broadcaster.py process killed successfully."
else
    echo "Failed to kill broadcaster.py process or it was not running."
fi

# Step 2: Stop the Docker container running the qubic-docker image
echo "Finding and stopping the Docker container with image qubic-docker..."

# Get the Container ID of the running qubic-docker container
CONTAINER_ID=$(docker ps --filter "ancestor=qubic-docker" -q)

if [ -z "$CONTAINER_ID" ]; then
    echo "No running container found with image qubic-docker."
else
    echo "Stopping container with ID: $CONTAINER_ID"
    docker stop "$CONTAINER_ID"

    if [ $? -eq 0 ]; then
        echo "Container $CONTAINER_ID stopped successfully."
    else
        echo "Failed to stop container $CONTAINER_ID."
    fi
fi

# Step 3: Kill the epoch_switcher.py process
echo "Killing epoch_switcher.py process..."
pkill -f epoch_switcher.py
if [ $? -eq 0 ]; then
    echo "epoch_switcher.py process killed successfully."
else
    echo "Failed to kill epoch_switcher.py process or it was not running."
fi

# Step 4: Kill processes with "node_ips {IP}"
echo "Detecting system IP address..."
CURRENT_IP=$(hostname -I | awk '{print $1}')
if [ -n "$CURRENT_IP" ]; then
    echo "System IP detected: $CURRENT_IP"
    echo "Killing processes with node_ips $CURRENT_IP ..."
    pkill -f "node_ips $CURRENT_IP"
    if [ $? -eq 0 ]; then
        echo "Processes with node_ips $CURRENT_IP killed successfully."
    else
        echo "No processes found with node_ips $CURRENT_IP or failed to kill."
    fi
else
    echo "Failed to detect system IP. Skipping node_ips process cleanup."
fi

# Step 5: Run docker-compose down in /root/qubic/qubic-docker/
echo "Running docker-compose down in /root/qubic/qubic-docker/..."
if cd /root/qubic/qubic_docker/; then
    docker-compose down
    if [ $? -eq 0 ]; then
        echo "docker-compose down executed successfully."
    else
        echo "Failed to execute docker-compose down."
    fi
else
    echo "Directory /root/qubic/qubic-docker/ does not exist. Skipping docker-compose down."
fi

echo "Cleanup script execution completed."
