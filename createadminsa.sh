#!/bin/bash

#
#
#

ContextName="jacob"

function create_sa() {
  kubectl create sa $ContextName-sa
  secret=$(kubectl get sa $ContextName-sa -o jsonpath='{.secrets[].name}')
  kubectl get secret $secret -o json | jq -r '.data."ca.crt"' | base64 -d > ca.crt
  user_token=$(kubectl get secret $secret -o json | jq -r '.data.token' | base64 -d)
  name=$(kubectl config get-contexts `kubectl config current-context` | awk '{print $3}' | tail -n 1)
  endpoint=`kubectl config view -o jsonpath="{.clusters[?(@.name == \"$name\")].cluster.server}"`
  
  kubectl config set-cluster $ContextName-cluster --embed-certs=true --server=$endpoint --certificate-authority=./ca.crt
  kubectl config set-credentials $ContextName-user --token=$user_token
  
  cat << EOF >> rbac-config-$ContextName-sa.yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: ${ContextName}-sa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: ${ContextName}-sa
    namespace: default
EOF
  
  kubectl create -f rbac-config-$ContextName-sa.yaml
  kubectl config set-context $ContextName-context --cluster=$ContextName-cluster --user=$ContextName-user
}

create_sa
