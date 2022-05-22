#!/bin/bash

set -e

SYSBOX_VERSION=$1
SHIFTFS_BRANCH=$2

sudo apt-get update
sudo apt-get install -yy \
    jq \
    ca-certificates \
    curl \
    wget \
    gnupg \
    make \
    dkms \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo usermod -aG docker "$USER"

systemctl enable docker
systemctl start docker

curl -SL https://downloads.nestybox.com/sysbox/releases/v"$SYSBOX_VERSION"/sysbox-ce_"$SYSBOX_VERSION"-0.linux_amd64.deb -o sysbox-ce.deb
sudo apt-get install -yy ./sysbox-ce.deb
docker info | grep -i runtime

git clone -b "$SHIFTFS_BRANCH" https://github.com/toby63/shiftfs-dkms.git shiftfs-"$SHIFTFS_BRANCH"
cd shiftfs-"$SHIFTFS_BRANCH"
./update1
sudo make -f Makefile.dkms
modinfo shiftfs