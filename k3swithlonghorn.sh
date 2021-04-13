#!/bin/bash

# 
# install kubernetes as oneline
#

# check the OS-distribution
OSDIST=`cat /etc/os-release | grep "^PRETTY_NAME=" | awk -F\" '{print $2}'`
INST_VELERO="no"

set -e
set -x

## https://rancher.com/docs/k3s/latest/en/installation/install-options/
# install K3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXE="--no-deploy trafik" sh -

# prepare helm
curl -L https://get.helm.sh/helm-v3.5.3-linux-amd64.tar.gz | tar xvfz -
cp linux-amd64/helm /usr/local/bin
rm -f linux-amd64

# kubectl 
kubectl get nodes
cp /var/lib/rancher/k3s/server/cred/admin.kubeconfig /root/.kube/config

# delete local-path
kubectl delete deploy/local-path-provisioner -n kube-system
kubectl delete sc/local-path
kubectl delete configmap/local-path-config
kubectl delete secret/

# longhorn

if [[ $OSDIST == *"CentOS"* ]]; then
    sudo yum install iscsi-initiator-utils -y
elif [[ $OSDIST == *"Ubuntu"* ]];then
    sudo apt-get update
    sudo apt install open-iscsi -y
else
    echo "only support centos and ubuntu OS distribution"
    exit 1
fi

helm repo add longhorn https://charts.longhorn.io 
helm repo update 
kubectl create ns longhorn-system 
helm install longhorn longhorn/longhorn -n longhorn-system \
 --set defaultSettings.defaultDataPath="/data/longhorn" \
 --set defaultSettings.defaultDataLocality="best-effort"

# velero
if [[ $INST_VELERO == "yes" ]]; then
    curl -L https://github.com/vmware-tanzu/velero/releases/download/v1.5.4/velero-v1.5.4-linux-amd64.tar.gz | tar xvzf -
    cp velero-v1.5.4-linux-amd64/velero /usr/local/bin
fi
