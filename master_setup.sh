#!/bin/bash
# A bash script for automating k8s master machine setup
# Author: Yile Gu

echo " === k8s master node setup start ==="

# configure IPtables to see bridged traffic
echo "Configuring IPtables to see bridged traffic..."

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

echo "Disabling swap on the machine..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Installing required packages for docker..."
sudo apt-get update -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo "Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

printf "%s\n" "deb [arch=amd64  signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu xenial stable" |\
sudo tee /etc/apt/sources.list.d/docker.list

echo "Installing Docker Engine..."
sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io -y


echo "Configuring Docker deamon's cgroup driver..."
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "Verifying Docker is correctly installed..."
sudo docker run hello-world
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Docker returns error!"
    exit $retVal
fi

echo "Adding user to docker user group..."
sudo usermod -a -G docker $USER

echo "Installing k8s dependencies..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "Adding k8s GPG key..."
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "Installing kuberadm, kubelet, kubectl..."
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "Restarting CRI..."
sudo rm /etc/containerd/config.toml
sudo systemctl restart containerd

echo "Initializing kubeadm cluster..."
# while true; do
#     read -p "Local IP Address: " LOCAL_IP
#     read -p "You've entered local ip: $LOCAL_IP, proceed? (y/n): " YN
#     case $YN in
#         y ) break;;
#         n ) continue;;
#         * ) echo "Please enter y/n, default treats as n (retry)!";;
#     esac
# done
# NODE_NAME=$(hostname -s)
while true; do
    read -p "Enter kubeadm init config file path: " INIT_CFG
    read -p "You've entered file path: $INIT_CFG, proceed? (y/n): " YN
    case $YN in
        y ) 
            if test -f "$INIT_CFG"; then
                break
            else
                echo "File does not exist, please retry"
                continue
            fi
            ;;
        n ) continue;;
        * ) echo "Please enter y/n, default treats as n (retry)!";;
    esac
done
sudo kubeadm init --config $INIT_CFG
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "kubeadm init returns error!"
    exit $retVal
else
    echo "kubeadm init success, make sure to save the kubeadm outputs above for worker joins!"
    read -p "Press Enter to continue"
fi

echo "Creating kubenetes admin config file..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Enabling pod scheduling on master node..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo "Checking system pods, you should see two coredns pods pending..."
kubectl get po -n kube-system
read -p "Press Enter to continue"

echo "Installing Calico network plugin..."
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

echo " === k8s master node setup completes! ==="