#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Wait for the master node to be ready
sleep 60

# Update the system
sudo yum update -y
sudo amazon-linux-extras install docker -y

# Enable and start Docker service
sudo systemctl enable --now docker

KUBERNETES_VERSION="v1.29"
CRIO_VERSION="v1.29"

# Set SELinux in permissive mode (effectively disabling it)
#  sudo setenforce 0
#  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Configure Kubernetes repository
cat <<EOA | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
EOA

# Configure CRI-O repository
cat <<EOB | sudo tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/rpm/repodata/repomd.xml.key
EOB

# Install necessary components
sudo yum install -y container-selinux cri-o kubelet kubeadm kubectl

# Start and enable CRI-O and kubelet services
sudo systemctl enable --now crio.service kubelet

# Retrieve the join command from the master node and execute it to join the cluster
# Uncomment and update MASTER_NODE_IP
# MASTER_NODE_IP="<MASTER_NODE_IP>"
# JOIN_COMMAND=$(ssh -o StrictHostKeyChecking=no -i /path/to/your/key.pem ubuntu@$MASTER_NODE_IP 'cat /tmp/kubeadm_join_command.sh')
# eval $JOIN_COMMAND

