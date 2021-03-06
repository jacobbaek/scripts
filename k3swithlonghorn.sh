#!/bin/bash

# 
# install kubernetes as oneline
#

# check the OS-distribution
OSDIST=`cat /etc/os-release | grep "^PRETTY_NAME=" | awk -F\" '{print $2}'`
if [ "${INST_VELEO}" == "yes" ]; then
  INST_VELERO="yes"
fi

if [ "${INST_LONGHORN}" == "no" ]; then
  INST_LONGHORN="no"
else
  INST_LONGHORN="yes"
fi

if [ "${DEBUG}" == "yes" ]; then
  DEBUG="yes"
fi

set -e

if [[ $DEBUG == "yes" ]]; then
    set -x
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# for longhorn
function check_longhorn_env() {
  if [[ $OSDIST == *"CentOS"* ]]; then
      sudo yum install iscsi-initiator-utils -y
  elif [[ $OSDIST == *"Rocky"* ]]; then
      sudo dnf install iscsi-initiator-utils -y
  elif [[ $OSDIST == *"Ubuntu"* ]];then
      sudo apt-get update
      sudo apt install open-iscsi -y
  else
    echo "only support CentOS and Ubuntu, Rocky Linux distribution"
    exit 1
  fi
}

## https://rancher.com/docs/k3s/latest/en/installation/install-options/
# install K3s
function install_k3s() {
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -s -
  
  # prepare helm
  curl -L https://get.helm.sh/helm-v3.5.3-linux-amd64.tar.gz | tar xvfz -
  cp linux-amd64/helm /usr/local/bin
  rm -rf linux-amd64
  
  # kubectl
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  if [[ ! -d "/root/.kube" ]]; then
      mkdir /root/.kube/
      cp /var/lib/rancher/k3s/server/cred/admin.kubeconfig /root/.kube/config
  fi

  # k9s download
  mkdir /tmp/k9s
  curl -L https://github.com/derailed/k9s/releases/download/v0.24.9/k9s_Linux_x86_64.tar.gz | tar xvfz - -C /tmp/k9s
  cp /tmp/k9s/k9s /usr/local/bin
  rm -rf /tmp/k9s

  # jq command
  curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o /usr/local/bin/jq
  chmod +x /usr/local/bin/jq

  # check the k3s becoming ready
  while [[ $RET -eq 1 ]]
  do
    kubectl get nodes | grep Ready
    RET=$?
    sleep 1
  done
}

# longhorn installation
function install_longhorn() {
  # delete local-path-provisioner
  kubectl delete deploy/local-path-provisioner -n kube-system
  kubectl delete sc/local-path
  kubectl delete configmap/local-path-config -n kube-system
  #kubectl delete secret/local-path-provisioner-service-account-token-xxxxx -n kube-system

  helm repo add longhorn https://charts.longhorn.io 
  helm repo update 
  kubectl create ns longhorn-system 
  helm install longhorn longhorn/longhorn -n longhorn-system \
   --set defaultSettings.defaultDataPath="/data/longhorn" \
   --set defaultSettings.defaultDataLocality="best-effort"
}

# velero installation
function install_velero() {
  curl -L https://github.com/vmware-tanzu/velero/releases/download/v1.5.4/velero-v1.5.4-linux-amd64.tar.gz | tar xvzf -
  cp velero-v1.5.4-linux-amd64/velero /usr/local/bin
}

# main function

if [[ $INST_LONGHORN == "yes" ]]; then
  check_longhorn_env
fi

install_k3s

if [[ $INST_LONGHORN == "yes" ]]; then
  install_longhorn
fi

if [[ $INST_VELERO == "yes" ]]; then
  install_velero
fi
