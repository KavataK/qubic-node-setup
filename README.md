# Qubic Node Setup

This repository contains an automated Bash script that installs all required dependencies and environment setup for running Qubic node a fresh Linux server.

## 🔧 What It Does

- Creates working directories.
- Downloads and extracts necessary archive.
- Installs required software packages and libraries.
- Installs Docker and Docker Compose.
- Installs VirtualBox and the Extension Pack.
- Clones necessary Qubic repositories.
- Builds `qubic-cli` and `qlogging` from source.
- Copies configuration files.
- Patches IP addresses in Docker configs.
- Makes scripts executable.

## 📝 Prerequisites

- A clean Ubuntu 22.04 system
- Must run as **root** user

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/KavataK/qubic-node-setup.git
cd qubic-node-setup

# Run the install script as root
sudo bash install.sh
