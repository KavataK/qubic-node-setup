#!/bin/bash

# Ensure the script is run with one parameter
echo "Starting deploy script..."
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [github]"
    exit 1
fi

GITHUB=$1

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
./run_win_build.sh -h 46.17.97.73 -u Administrator -w QubicQubic1! -g $GITHUB -s seeds.txt -r peers.txt -m release -o . -c config.yaml | tee /root/qubic/qubic-efi-cross-build/build.log

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

sleep 2
cd /root/qubic/scripts/ || exit 1
python3 broadcaster.py
nohup python3 epoch_switcher.py > /root/qubic/scripts/epoch_switcher.log 2>&1 &

# Step 5: Start Docker Compose services for qubic-http and qubic-nodes

cd /root/qubic/qubic_docker/ || exit 1
export HOST_IP=$(hostname -I | awk '{print $1}')
echo "HOST_IP=$HOST_IP" > .env
docker-compose up -d
cd /root/qubic/qubic_docker/spectrumData || exit 1
nohup ./setupSpectrumData.sh --epoch $EPOCH_VALUE > spectrum_setup.log 2>&1 &
sleep 5

# Get the local IP address
IP=$HOST_IP

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
