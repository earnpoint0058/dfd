#!/bin/bash

set -e  # Exit on error

echo "=== Updating system packages ==="
sudo apt-get update && sudo apt-get upgrade -y

echo "=== Installing essential packages ==="
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano \
automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev \
tar clang bsdmainutils ncdu unzip libleveldb-dev -y

echo "=== Cleaning up conflicting Docker packages ==="
sudo apt update -y && sudo apt upgrade -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y $pkg
done

echo "=== Setting up Docker repository ==="
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Installing Docker ==="
sudo apt update -y && sudo apt upgrade -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Testing Docker ==="
sudo docker run hello-world

echo "=== Installing Drosera ==="
curl -L https://app.drosera.io/install | bash

echo "=== Reloading bash configuration ==="
source /root/.bashrc || true

echo "=== Updating Drosera ==="
droseraup

echo "=== Installing Foundry ==="
curl -L https://foundry.paradigm.xyz | bash
source /root/.bashrc || true
foundryup

echo "=== Installing Bun ==="
curl -fsSL https://bun.sh/install | bash

echo "=== Creating Drosera trap folder ==="
mkdir -p my-drosera-trap
cd my-drosera-trap

echo "=== Setup Complete ==="
