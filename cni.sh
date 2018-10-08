#!/bin/bash

# Download CNI
mkdir -p /opt/cni/bin && cd /opt/cni/bin
export CNI_URL="https://github.com/containernetworking/plugins/releases/download"
echo "${CNI_URL}/v0.7.1/cni-plugins-amd64-v0.7.1.tgz"
wget -qO- --show-progress "${CNI_URL}/v0.7.1/cni-plugins-amd64-v0.7.1.tgz" | tar -zx
