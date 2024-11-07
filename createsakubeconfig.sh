#!/bin/bash

SANAME="testsa"
NSNAME="testns"

namespace() {
kubectl create ns $NSNAME
}

serviceaccount(){
kubectl create serviceaccount $SANAME -n $NSNAME
kubectl apply -f - << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SANAME}-secret
  namespace: ${NSNAME}
  annotations:
    kubernetes.io/service-account.name: ${SANAME}
type: kubernetes.io/service-account-token
EOF
}

role() {
kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${NSNAME}
  name: ${SANAME}-role
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list", "create"]
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods/exec"]
  verbs: ["create"]
EOF

kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${SANAME}-rb
  namespace: ${NSNAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${SANAME}-role
subjects:
- kind: ServiceAccount
  name: ${SANAME}
  namespace: ${NSNAME}
EOF
}

kubeconfig() {
clustername=$(kubectl config view -o jsonpath='{.clusters[].name}')
clusterserver=$(kubectl config view -o jsonpath='{.clusters[].cluster.server}')
ca=$(kubectl --namespace="${NSNAME}" get secret/"${SANAME}-secret" -o=jsonpath='{.data.ca\.crt}')
token=$(kubectl --namespace="${NSNAME}" get secret/"${SANAME}-secret" -o=jsonpath='{.data.token}' | base64 --decode)
cat << EOF > kubeconfig
apiVersion: v1
kind: Config
clusters:
  - name: ${clustername}
    cluster:
      certificate-authority-data: ${ca}
      server: ${clusterserver}
contexts:
  - name: ${SANAME}@${clustername}
    context:
      cluster: ${clustername}
      namespace: ${NSNAME}
      user: ${SANAME}
users:
  - name: ${SANAME}
    user:
      token: ${token}
current-context: ${SANAME}@${clustername}
EOF
}

set -o errexit
namespace
serviceaccount
role
kubeconfig

