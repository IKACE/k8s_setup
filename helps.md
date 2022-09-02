Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.0.0.1:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:79b0ee3d035eb825274aa716a1e15cbfe486dab87da431b1781a7e1677213308 

# master node setup
1. prepare a kubeadm init config file, make sure to change local_ip on *advertiseAddress* and *certSANs*, *podSubnet* can be left as it is.
2. run master_setup.sh

## setup metrics server
1. kubectl apply -f metrics_server.yaml
2. kubectl edit deployments.apps -n kube-system metrics-server
3. add hostNetwork:true after dnsPolicy:ClusterFirst
4. kubectl rollout restart deployment metrics-server -n kube-system
5. verify: kubectl top nodes

# worker node setup
1. run worker_setup.sh
2. use join command outputted from master init, example: kubeadm join 10.0.0.1:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:79b0ee3d035eb825274aa716a1e15cbfe486dab87da431b1781a7e1677213308 