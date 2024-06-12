#!/bin/bash
## this will be used on the vm extension installing

sudo apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
sudo /usr/bin/az aks install-cli
curl -L https://github.com/derailed/k9s/releases/download/v0.32.4/k9s_Linux_amd64.tar.gz | sudo tar xvfz - --directory /usr/local/bin 
sudo curl -L https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell -o /usr/local/bin/kubectl-node_shell 
sudo chmod +x /usr/local/bin/kubectl-node_shell 
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash
