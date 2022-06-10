#!/usr/bin/env bash

## CloudPak console: 
CP_URL=$(oc get route -n tools integration-navigator-pn -o template --template='https://{{.spec.host}}')
CP_PWD=$(oc extract -n ibm-common-services secrets/platform-auth-idp-credentials --keys=admin_password --to=- | tail -1) 

ARGO_URL=$(oc get route -n openshift-gitops openshift-gitops-cntk-server -o template --template='https://{{.spec.host}}')
ARGO_PWD=$(oc extract secrets/openshift-gitops-cntk-cluster --keys=admin.password -n openshift-gitops --to=- | tail -1)

echo "$ARGO_URL"
echo "admin/$ARGO_PWD"

echo "$CP_URL"
echo "admin/$CP_PWD"