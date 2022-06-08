#!/usr/bin/env bash

err=0
if [ -z "${TOKEN}" ]; then 
  echo "IBM Cloud token needed in \$TOKEN"
  err=$((err+1))
fi
if [ -z "${GIT_ORG}" ]; then 
  echo "\$GIT_ORG is a required argument"
  err=$((err+1))
fi
if [ -z "${CNAME}" ]; then 
  echo "\$CNAME - cluster name is a required argument"
  err=$((err+1))
fi
if [ -z "${GH_TOKEN}" ]; then 
  echo "\$GH_TOKEN - GitHub token is required"
  err=$((err+1))
fi
if [ -z "${IBM_ENTITLEMENT_KEY}" ]; then 
  echo "\$IBM_ENTITLEMENT_KEY: - GitHub token is required"
  err=$((err+1))
fi

if [[ "${err}" -ne "0" ]]; then 
  exit 99
fi

# export USER_PWD=my-ibmcloud-pwd
# This is TechZone account:
ibmcloud login -a cloud.ibm.com -r us-south -g default -u passcode -p ${TOKEN} -g dteroks -c 39e2321422d14070954ed0b48a1db535 || exit 1
# Enter the Zone where you want to create cluster.
# You can check the zones available using the following command:
# ibmcloud oc zone ls --provider classic
ZONE="dal10"
# Enter OCP version for your cluster.
# You can check the versions available using the following command:
# ibmcloud oc versions
# This is the version I have been using for the test:
VERSION="4.8.39_openshift"
# Enter the Worker Nodes Flavor for your cluster
# You can check the flavors available using the following command:
# ibmcloud oc flavors --provider classic --zone $ZONE
# This is the one we have been using:
FLAVOR="b3c.16x64"
# Enter the VLANs to be used by your cluster.
# You can check the vlans available using the following command:
# ibmcloud oc vlan ls --zone $ZONE
# NOTE: This is the command I can not run on the TechZone account 
VLAN_PRIV=$(ibmcloud oc vlan ls --zone ${ZONE} | grep private | awk '{print $1}')
VLAN_PUB=$(ibmcloud oc vlan ls --zone ${ZONE} | grep public | awk '{print $1}')
# Enter the number of Worker Nodes for the cluster
# This is the number we agreed
NUM_WORKERS=5
# Enter the  the list of clusters you want to create
# In theory you could remove the "vlan" parameters and they would be created automatically, but you have to test
ibmcloud plugin install container-service -f

ibmcloud oc cluster create classic \
        --name $CNAME \
        --zone $ZONE \
        --version $VERSION \
        --flavor $FLAVOR \
        --workers $NUM_WORKERS \
        --private-vlan $VLAN_PRIV \
        --public-vlan $VLAN_PUB \
        --public-service-endpoint \
        --entitlement cloud_pak || exit 1

mkdir ${GIT_ORG}
PWD=$(pwd)
KUBECONFIG=${PWD}/${GIT_ORG}/kubeconfig

## loop to wait for cluster to be ready
status=$(ibmcloud oc cluster get -c $CNAME | grep "^State:"  | awk '{print $2}')
while [[ "$status" != "normal" ]]; do
  sleep 60
  echo -n "."
  status=$(ibmcloud oc cluster get -c $CNAME | grep "^State:"  | awk '{print $2}')
done

ibmcloud ks cluster config --admin -c ${CNAME} || exit 1

NFSNAMESPACE="dtenfs"
PVCNAME="dte-nfs-storage"
STORAGESIZE="500Gi"

oc create namespace ${NFSNAMESPACE}
oc project ${NFSNAMESPACE}

# create storage
cat <<EOF | oc create -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: dte-nfs-storage
 labels:
   billingType: hourly
spec:
 accessModes:
   - ReadWriteMany
 resources:
   requests:
     storage: ${STORAGESIZE}
 storageClassName: ibmc-file-gold
EOF

max_retry=10
retry=0
pvcsuccess="no"
while [ ${retry} -lt ${max_retry} ]; do 
    pvcready=$(oc get pvc ${PVCNAME} -ojson | jq -r '.status.phase')
    if [[ "$pvcready" != "Bound" ]]; then
        (( retry = retry + 1 ))
        sleep 60
    else
        pvcsuccess="yes"
        break
    fi
done

if [[ "$pvcsuccess" == "no" ]]; then 
    echo "error=dte-nfs-provisioning failed - pvc not ready in time"
    exit 1
fi 

volumename=$(oc get pvc ${PVCNAME} -ojson | jq -r '.spec.volumeName')
echo "Volume: $volumename"
nfspath=$(oc get pv $volumename -ojson | jq -r '.spec.nfs.path')
echo "NFS Path: $nfspath"
nfsserver=$(oc get pv $volumename -ojson | jq -r '.spec.nfs.server')
echo "NFS Server: $nfsserver"

#log "DEBUG" "$(cat assets/deplopyment.yaml)"

# Install
echo "Deploy nfs-provisioner"
cat <<EOF | oc create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  namespace: dtenfs
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: dtenfs
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: dtenfs
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: dtenfs
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: dtenfs
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF

oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:dtenfs:nfs-client-provisioner

cat <<EOF | oc create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dte-nfs-provisioner #DTE specific name
  labels:
    app: dte-nfs-provisioner
  namespace: dtenfs
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: dte-nfs-provisioner
  template:
    metadata:
      labels:
        app: dte-nfs-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: dtenfs/dte-nfs-provisioner
            - name: NFS_SERVER
              value: ${nfsserver}
            - name: NFS_PATH
              value: ${nfspath}
      volumes:
        - name: nfs-client-root
          nfs:
            server: ${nfsserver}
            path: ${nfspath}
EOF

cat <<EOF | oc create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
provisioner: dtenfs/dte-nfs-provisioner
parameters:
  archiveOnDelete: "false"
EOF

sleep 60
echo "Pod info"
oc get pod -l app=dte-nfs-provisioner

# Set default storage
echo "Set default storage"
oc annotate storageclass ibmc-block-gold storageclass.kubernetes.io/is-default-class-
oc annotate storageclass managed-nfs-storage storageclass.kubernetes.io/is-default-class="true"

sleep 60

cd ${GIT_ORG}
echo ${GH_TOKEN} | gh auth login --with-token

gh repo fork https://github.com/sko-master/multi-tenancy-gitops --org ${GIT_ORG} --clone
gh repo fork https://github.com/sko-master/multi-tenancy-gitops-infra --org ${GIT_ORG} --clone
gh repo fork https://github.com/sko-master/multi-tenancy-gitops-services --org ${GIT_ORG} --clone
gh repo fork https://github.com/sko-master/multi-tenancy-gitops-apps --org ${GIT_ORG} --clone
cd ..
oc apply -f $GIT_ORG/multi-tenancy-gitops/setup/ocp4x/

## wait for gitops
    while ! oc wait crd applications.argoproj.io --timeout=-1s --for=condition=Established  2>/dev/null; do sleep 30; done

oc project openshift-gitops
oc apply -f $GIT_ORG/multi-tenancy-gitops/setup/ocp4x/argocd-instance
cd $GIT_ORG/multi-tenancy-gitops
./scripts/set-git-source.sh
git add .
git commit -m "set source"
git push origin
cd ../..
oc apply -f $GIT_ORG/multi-tenancy-gitops/0-bootstrap/single-cluster/bootstrap.yaml
oc create ns tools
oc create ns ibm-common-services
oc create secret docker-registry ibm-entitlement-key --docker-server="cp.icr.io" --docker-username="cp" --docker-password="${IBM-ENTITLEMENT-KEY}" -n tools
oc create secret docker-registry ibm-entitlement-key --docker-server="cp.icr.io" --docker-username="cp" --docker-password="${IBM-ENTITLEMENT-KEY}" -n ibm-common-services
