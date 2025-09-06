#!/bin/bash

# Ensure the script is run with one parameter
echo "Starting deploy script..."
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [github]"
    exit 1
fi

GITHUB=$1

# Save GitHub link to file for network monitor (add to top of file)
echo "Saving GitHub link to file..."
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
NEW_LINK_ENTRY="$CURRENT_DATE|$GITHUB"

if [ -f "/root/qubic/github_link.txt" ]; then
    # Create temporary file with new link at top
    echo "$NEW_LINK_ENTRY" > /tmp/github_link_temp.txt
    cat /root/qubic/github_link.txt >> /tmp/github_link_temp.txt
    mv /tmp/github_link_temp.txt /root/qubic/github_link.txt
else
    echo "$NEW_LINK_ENTRY" > /root/qubic/github_link.txt
fi
echo "GitHub link saved: $GITHUB at $CURRENT_DATE"

# Check if any running Docker container was started with /entrypoint.sh
if docker ps --format '{{.ID}} {{.Command}}' | grep -q '"/entrypoint.sh"'; then
  echo "!!!!!Testnet is still running. Please stop and clean up the node using:"
  echo "./cleanup.sh"
  exit 1
fi

# Extract owner, repo, and branch from GitHub URL
if [[ "$GITHUB" =~ https://github.com/([^/]+)/([^/]+)/tree/(.+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    BRANCH="${BASH_REMATCH[3]}"
    REPO_URL="https://github.com/$OWNER/$REPO"
    PUBLIC_SETTINGS_URL="https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH/src/public_settings.h"
    QUBIC_CPP_URL="https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH/src/qubic.cpp"
else
    echo "Error: GitHub URL must be in the format https://github.com/owner/repo/tree/branch_name"
    exit 1
fi

# Fetch EPOCH value from GitHub
EPOCH_VALUE=$(curl -s "$PUBLIC_SETTINGS_URL" | grep -E '#define EPOCH [0-9]+' | sed -E 's/.*#define EPOCH ([0-9]+).*/\1/')

if [ -z "$EPOCH_VALUE" ]; then
    echo "Error: Failed to extract EPOCH value from $PUBLIC_SETTINGS_URL"
    exit 1
fi

echo "Detected EPOCH: $EPOCH_VALUE"

# Step 1: Prepare VHD
sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 -f vpc /root/qubic/qubic.vhd
sudo fsck.vfat -a /dev/nbd0p1
sudo qemu-nbd -d /dev/nbd0
echo "Mounting VHD..."
LOOP_DEVICE=$(sudo losetup -f --show --partscan /root/qubic/qubic.vhd)
MOUNT_POINT="/mnt/qubic"
sudo mount ${LOOP_DEVICE}p1 $MOUNT_POINT
echo "VHD mounted on $LOOP_DEVICE"

# Clean up VHD (remove all except 'efi/')
find $MOUNT_POINT -mindepth 1 -maxdepth 1 ! -name "efi" -exec sudo rm -rf {} +

# Copy new files to VHD (assuming files are in /root/qubic/filesForVHD/)
sudo cp -r /root/qubic/filesForVHD/* $MOUNT_POINT/

# Rename files to match current epoch
for file in $MOUNT_POINT/*.*; do
    if [[ $file =~ (.*)\.[0-9]+$ ]]; then
        sudo mv "$file" "${BASH_REMATCH[1]}.$EPOCH_VALUE"
    fi
done

echo "Listing directory structure with tree:"
sudo tree "$MOUNT_POINT"

# Unmount and detach loop device
cd /
sudo umount $MOUNT_POINT
sudo losetup -d $LOOP_DEVICE
echo "VHD prepared"

# Step 2: Compile the Qubic.efi file 
echo "Compiling Qubic.efi..."
cd /root/qubic/qubic-efi-cross-build || exit 1
./run_win_build.sh -h 5.39.218.156 -u qubic -w qubic -g $GITHUB -s seeds.txt -r peers.txt -m release -o . -c config.yaml | tee /root/qubic/qubic-efi-cross-build/build.log

# Wait until the build is completed successfully
echo "Waiting for Qubic.efi compilation to complete..."
while ! grep -q "==== Build completed successfully (Qubic.efi only) ====" /root/qubic/qubic-efi-cross-build/build.log; do
    sleep 5
done
echo "Qubic.efi compilation completed."

# Step 3: Start Docker container in the current terminal
echo "Starting Docker container..."
cd /root/qubic/qubic_docker || exit 1
rm -r /root/qubic/qubic_docker/store
rm -r /root/qubic/qubic_docker/mongo-data 
script -qc "./run.sh --epoch $EPOCH_VALUE --vhd /root/qubic/qubic.vhd --port 31841 --memory 60000 --cpus 10 --efi /root/qubic/qubic-efi-cross-build/Qubic.efi" /dev/null &

sleep 2
# Step 4: Run broadcaster script in background
echo "Waiting for the node to start up..."

# Get the local IP address first
export HOST_IP=$(hostname -I | awk '{print $1}')
IP=$HOST_IP

# Check if IP is valid
if [ -z "$IP" ]; then
    echo "Error: Could not determine local IP address"
    exit 1
fi
echo "Using IP address: $IP"

sleep 2
cd /root/qubic/scripts/ || exit 1
python3 broadcaster.py
nohup python3 epoch_switcher.py > /root/qubic/scripts/epoch_switcher.log 2>&1 &
nohup python3 network_monitor.py --node_ips $IP --node_port 31841 > /root/qubic/scripts/logs/network_monitor.log 2>&1 &
nohup python3 f9.py --node_ips $IP --node_port 31841 > /root/qubic/scripts/logs/f9.log 2>&1 &

# Step 5: Start Docker Compose services for qubic-http and qubic-nodes

cd /root/qubic/qubic_docker/ || exit 1
echo "HOST_IP=$HOST_IP" > .env
docker-compose up -d
cd /root/qubic/qubic_docker/spectrumData || exit 1
nohup ./setupSpectrumData.sh --epoch $EPOCH_VALUE > spectrum_setup.log 2>&1 &
sleep 5

# Display deployment info
echo "======================================================================================================================="
echo "Deployment completed successfully."
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "RPC is available at: http://$IP:8000/v1/tick-info"
echo "The Qubic Stats API: http://$IP:8000/v1/latest-stats"
echo "Demo App: http://$IP:8088"
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                  HOW TO CONNECT TO YOUR DEDICATED NODE                     ║"
echo "╠════════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                           ║"
echo "║  1. Open the Qubic application in your browser:                           ║"
echo "║     » http://$IP:8088                                                     ║"
echo "║                                                                           ║"
echo "║  2. Click on the 'Connect' link at the top right corner                   ║"
echo "║                                                                           ║"
echo "║  3. Select 'Connect to Server' from the dropdown menu                     ║"
echo "║                                                                           ║"
echo "║  4. Enter your node URL:                                                  ║"
echo "║     » http://$IP:8000                                   ║"
echo "║                                                                           ║"
echo "║  5. Click 'Connect' and refresh the page                                  ║"
echo "║                                                                           ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "To connect to the testnet via qubic-cli, use:"
echo "_______________________"
echo "|                     |"
echo "| IP: $IP  |"
echo "| Port: 31841         |"
echo "|_____________________|"
echo "Example commands:"
cd /root/qubic/scripts || exit 1
echo "./qubic-cli -nodeip $IP -nodeport 31841 -getcurrenttick"
echo "Response:"
./qubic-cli -nodeip $IP -nodeport 31841 -getcurrenttick

echo "./qubic-cli -nodeip $IP -nodeport 31841 -getbalance WEVWZOHASCHODGRVRFKZCGUDGHEDWCAZIZXWBUHZEAMNVHKZPOIZKUEHNQSJ"
echo "Response:"
./qubic-cli -nodeip $IP -nodeport 31841 -getbalance WEVWZOHASCHODGRVRFKZCGUDGHEDWCAZIZXWBUHZEAMNVHKZPOIZKUEHNQSJ
echo "======================================================================================================================="
