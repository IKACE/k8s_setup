# Kubernetes Master-Worker Setup
Setup files needed for getting ready minimum requirements of a Kubernetes cluster network.

## Master Node Setup
1. prepare a kubeadm init config file, make sure to change local_ip on *advertiseAddress* and *certSANs*, *podSubnet* can be left as it is.
2. run master_setup.sh

### Setup Metrics Server
1. kubectl apply -f metrics_server.yaml
2. kubectl edit deployments.apps -n kube-system metrics-server
3. add hostNetwork:true after dnsPolicy:ClusterFirst
4. kubectl rollout restart deployment metrics-server -n kube-system
5. verify: kubectl top nodes

## Worker Node Setup
1. run worker_setup.sh
2. sudo su -
3. use join command outputted from master init, example: kubeadm join 10.0.0.1:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:79b0ee3d035eb825274aa716a1e15cbfe486dab87da431b1781a7e1677213308 
