#!/bin/bash
# A bash script for automating GPU setup for k8s
# Author: Yile Gu
# reference: https://docs.nvidia.com/datacenter/cloud-native/kubernetes/install-k8s.html#step-4-setup-nvidia-software

# === Install NVIDIA Drivers ===

# Install the kernel headers and development packages for the currently running kernel
sudo apt-get install linux-headers-$(uname -r)

# Setup the CUDA network repository and ensure packages on the CUDA network repository have priority over the Canonical repository
distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g') \
   && wget https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/cuda-$distribution.pin \
   && sudo mv cuda-$distribution.pin /etc/apt/preferences.d/cuda-repository-pin-600

# Install the CUDA repository GPG key
sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/7fa2af80.pub \
   && echo "deb http://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64 /" | sudo tee /etc/apt/sources.list.d/cuda.list

# Update the apt repository cache and install the driver using the cuda-drivers or cuda-drivers-<branch-number> meta-package. Use the --no-install-recommends option for a lean driver install without any dependencies on X packages. This is particularly useful for headless installations on cloud instances
sudo apt-get update
sudo apt-get -y install cuda-drivers --allow-unauthenticated

# === Install NVIDIA Container Toolkit ===

# First, setup the stable repository for the NVIDIA runtime and the GPG key
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
   && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - \
   && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Assume Docker runtime for default, install the nvidia-docker2 package
# sudo apt-get update \
#    && sudo apt-get install -y nvidia-docker2

# Modify /etc/docker/daemon.json
# {
#   "exec-opts": ["native.cgroupdriver=systemd"],
#   "log-driver": "json-file",
#   "log-opts": {
#     "max-size": "100m"
#   },
#   "storage-driver": "overlay2",
#    "default-runtime": "nvidia",
#       "runtimes": {
#                 "nvidia": {
#                                 "path": "/usr/bin/nvidia-container-runtime",
#                                             "runtimeArgs": []
#                                                   }
#                                                      }
# }
# sudo systemctl restart docker

# Install nvidia-container-runtime package
sudo apt-get update \
   && sudo apt-get install -y nvidia-container-runtime

# Test a CUDA container
# sudo docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu16.04 nvidia-smi

# Add the following settings to /etc/containerd/config.toml
# +++ /etc/containerd/config.toml 2020-12-17 19:27:02.019027793 +0000

#    ignore_image_defined_volumes = false
#    [plugins."io.containerd.grpc.v1.cri".containerd]
#       snapshotter = "overlayfs"

#       default_runtime_name = "nvidia"
#       no_pivot = false
#       disable_snapshot_annotations = true
#       discard_unpacked_layers = false

#          privileged_without_host_devices = false
#          base_runtime_spec = ""
#          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
#               SystemdCgroup = true
#          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
#             privileged_without_host_devices = false
#             runtime_engine = ""
#             runtime_root = ""
#             runtime_type = "io.containerd.runc.v1"
#             [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
#               BinaryName = "/usr/bin/nvidia-container-runtime"
#               SystemdCgroup = true
#    [plugins."io.containerd.grpc.v1.cri".cni]
#       bin_dir = "/opt/cni/bin"
#       conf_dir = "/etc/cni/net.d"

# Restart containerd
sudo systemctl daemon-reload
sudo systemctl restart containerd

# === Install NVIDIA Device Plugin ===

# First, install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 \
   && chmod 700 get_helm.sh \
   && ./get_helm.sh

# Add the nvidia-device-plugin helm repository
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin \
   && helm repo update

# Deploy the device plugin
helm install --generate-name nvdp/nvidia-device-plugin -n kube-system

#
docker run --security-opt=no-new-privileges --cap-drop=ALL --restart always --network=none -it -v /var/lib/kubelet/device-plugins:/var/lib/kubelet/device-plugins nvidia/k8s-device-plugin:v0.9.0

kubectl taint nodes h1 nvidia.com/gpu=value:NoSchedule