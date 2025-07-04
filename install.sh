#!/bin/bash

set -e

# === Helper function ===
echo_info() {
    echo -e "\n\033[1;34m[INFO]\033[0m $1\n"
}

PROJECT_ROOT="$(dirname "$(realpath "$0")")"

# Update packages and install pip & gdown
sudo apt update -y && \
sudo apt install -y python3-pip unzip tree && \
pip3 install gdown

# === Step 1: Create main project directory ===
echo_info "Creating /root/qubic directory..."
mkdir -p /root/qubic

# === Step 2: Download VHD and extract in background ===
echo_info "Downloading 32GBVHD.zip from Google Drive..."
gdown --id 1Qz-axY4AmGCL_JVjBdYVBYFdNqJ8T05B --no-cookies --quiet

echo_info "Extracting 32GBVHD.zip to /root/qubic (in background)..."
unzip -o 32GBVHD.zip -d /root/qubic/ &
bg_unzip_pid=$!

# === Step 3: Download IPOSCHM25.zip and extract ===
echo_info "Downloading IPOSCHM25.zip from Google Drive..."
gdown --id 1-TC1O13e0InESqmkG-QGlyvCaT8fEsI6 --no-cookies --quiet

mkdir -p /root/qubic/filesForVHD
unzip -o IPOSCHM25.zip -d /root/qubic/filesForVHD

# === Step 4: Download and install libvpx7 ===
echo_info "Downloading and installing libvpx7..."
gdown --id 1q7loi8oFfKa-TSLuuMMGBjP2BYm-OxWH --no-cookies --quiet

dpkg -i libvpx7_1.11.0-2ubuntu2.3_amd64.deb || apt -f install -y

# === Step 5: Install system dependencies ===
echo_info "Installing system packages..."
apt update
apt install -y sshpass freerdp2-x11 git libxcb-cursor0 cmake make build-essential \
    gcc-12 g++-12 dkms linux-headers-$(uname -r) gcc perl docker.io curl

# === Step 6: Create mount directory ===
sudo mkdir -p /mnt/qubic

# === Step 7: Install VirtualBox and Extension Pack ===
echo_info "Installing VirtualBox and Extension Pack..."
wget https://download.virtualbox.org/virtualbox/7.1.4/virtualbox-7.1_7.1.4-165100~Ubuntu~jammy_amd64.deb
wget https://download.virtualbox.org/virtualbox/7.1.4/Oracle_VirtualBox_Extension_Pack-7.1.4.vbox-extpack

dpkg -i virtualbox-7.1_7.1.4-165100~Ubuntu~jammy_amd64.deb || apt -f install -y
VBoxManage extpack install Oracle_VirtualBox_Extension_Pack-7.1.4.vbox-extpack --accept-license=eb31505e56e9b4d0fbca139104da41ac6f6b98f8e78968bdf01b1f3da3c4f9ae

modprobe -r vboxnetflt vboxnetadp vboxpci vboxdrv || true
/sbin/vboxconfig || true

# === Step 8: Install Docker Compose ===
echo_info "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# === Step 9: Clone repositories ===
echo_info "Cloning GitHub repositories..."
cd /root/qubic
git clone https://github.com/icyblob/qubic_docker.git
git clone https://github.com/icyblob/qubic-efi-cross-build.git
git clone https://github.com/qubic/qlogging.git
git clone https://github.com/qubic/qubic-cli.git

# === Step 10: Build qubic-cli ===
echo_info "Building qubic-cli..."
cd /root/qubic/qubic-cli
mkdir -p build && cd build
cmake ../
make

# === Step 11: Build qlogging ===
echo_info "Building qlogging..."
cd /root/qubic/qlogging
mkdir -p build && cd build
cmake ../
make

# === Step 12: Move configuration files ===
echo_info "Placing configuration files..."
cp "$PROJECT_ROOT/config.yaml" /root/qubic/qubic-efi-cross-build/
cp "$PROJECT_ROOT/seeds.txt" /root/qubic/qubic-efi-cross-build/
cp -r "$PROJECT_ROOT/scripts" /root/qubic/

echo -e "127.0.0.1\n$(hostname -I | awk '{print $1}')" > /root/qubic/qubic-efi-cross-build/peers.txt

cp "$PROJECT_ROOT/cleanup.sh" /root/qubic/qubic_docker/
cp "$PROJECT_ROOT/deploy.sh" /root/qubic/qubic_docker/
cp "$PROJECT_ROOT/qubic-cli" /root/qubic/qubic_docker/
cp "$PROJECT_ROOT/docker-compose.yaml" /root/qubic/qubic_docker/
mkdir -p /root/qubic/qubic_docker/spectrumData/
cp "$PROJECT_ROOT/qubic-stats-processor" /root/qubic/qubic_docker/spectrumData/
cp "$PROJECT_ROOT/setupSpectrumData.sh" /root/qubic/qubic_docker/spectrumData/
cp /root/qubic/filesForVHD/spectrum.158 /root/qubic/qubic_docker/spectrumData/

# === Step 13: Patch docker-compose.yaml with current IP ===
echo_info "Updating docker-compose.yaml with server IP..."
server_ip=$(hostname -I | awk '{print $1}')
sed -i 's|^\(\s*QUBIC_EVENTS_POOL_NODE_PASSCODES:\s*"\).*|\1'"$server_ip"':AAAAAAAAAAEAAAAAAAAAAgAAAAAAAAADAAAAAAAAAAQ="|' /root/qubic/qubic_docker/docker-compose.yaml
sed -i "s/\"IP\"/\"$server_ip\"/" /root/qubic/qubic_docker/docker-compose.yaml

# === Step 14: Set permissions ===
echo_info "Setting execution permissions..."
chmod -R +x /root/qubic/

# === Final: Wait for unzip ===
echo_info "Waiting for VHD unzip to finish..."
wait $bg_unzip_pid

echo_info "Setup completed successfully."
