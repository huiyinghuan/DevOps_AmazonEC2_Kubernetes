#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

echo "Updating the system..."
sudo yum update -y

echo "Installing Docker..."
sudo amazon-linux-extras install docker -y

echo "Enabling and starting Docker..."
sudo systemctl enable --now docker

KUBERNETES_VERSION="v1.29"
CRIO_VERSION="v1.29"

#echo "Setting SELinux in permissive mode (effectively disabling it)..."
#sudo setenforce 0
#sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo "Configuring Kubernetes repository..."
cat <<EOA | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
EOA

echo "Configuring CRI-O repository..."
cat <<EOB | sudo tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/rpm/repodata/repomd.xml.key
EOB

echo "Installing necessary components (container-selinux, CRI-O, kubelet, kubeadm, kubectl)..."
sudo yum install -y container-selinux cri-o kubelet kubeadm kubectl

echo "Enabling and starting CRI-O and kubelet services..."
sudo systemctl enable --now crio.service kubelet

echo "Initializing the Kubernetes cluster..."
sudo kubeadm init --pod-network-cidr=10.0.0.0/16 --cri-socket=unix:///var/run/crio/crio.sock --ignore-preflight-errors=all

echo "Setting up kubectl for the root user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Removing taints from control-plane nodes to allow scheduling workloads..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo "Creating a token for worker nodes to join the cluster..."
sudo kubeadm token create --print-join-command > /tmp/kubeadm_join_command.sh
echo "Token created and saved to /tmp/kubeadm_join_command.sh"

# Uncomment the lines below if you want to apply your Kubernetes manifests
# echo "Applying Kubernetes manifests for services and deployments..."
# kubectl apply -f /Users/huanhuiying/Desktop/DevOps_Docker_Kubernetes/Practical-3/k8s/deployments/react-deployment.yaml
# kubectl apply -f /Users/huanhuiying/Desktop/DevOps_Docker_Kubernetes/Practical-3/k8s/deployments/go-deployment.yaml
# kubectl apply -f /Users/huanhuiying/Desktop/DevOps_Docker_Kubernetes/Practical-3/k8s/services/react-service.yaml
# kubectl apply -f /Users/huanhuiying/Desktop/DevOps_Docker_Kubernetes/Practical-3/k8s/services/go-service.yaml

echo "Kubernetes setup process completed successfully."

