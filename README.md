# Qubic Node Setup

This repository contains an automated Bash script that installs all required dependencies and sets up the environment for running a Qubic node on a fresh Linux server.

## 🧾 Minimum Requirements

- **Operating System:** Ubuntu 22.04 (clean install)
- **Storage:** At least 50 GB of free disk space
- **Memory (RAM):** 64 GB or more
- **Permissions:** Must be run as **root**

## 🔧 What It Does

- Creates working directories
- Downloads and extracts necessary archives
- Installs required software packages and libraries
- Installs Docker and Docker Compose
- Installs VirtualBox and Extension Pack
- Clones necessary Qubic repositories
- Builds `qubic-cli` and `qlogging` from source
- Copies configuration files
- Patches IP addresses in Docker configs
- Makes scripts executable

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/KavataK/qubic-node-setup.git
cd qubic-node-setup

# Run the install script as root
sudo bash install.sh
```

---

## 🧪 Hackathon Version

For a version tailored specifically for hackathons, use the `hackathon` branch:

```bash
git clone -b hackathon https://github.com/KavataK/qubic-node-setup.git
cd qubic-node-setup
sudo bash install.sh
```

> ⚠️ This version is optimized for testing and development. Not recommended for production environments.
