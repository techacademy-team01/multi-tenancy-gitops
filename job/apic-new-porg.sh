#!/usr/bin/env bash
echo "Creating new Provider Organization..."
###################
# INPUT VARIABLES #
###################
APIM_STATUS=$(oc get apiconnectcluster apim-demo -n tools -o jsonpath='{.status.phase}')
if [ -z "${APIM_STATUS}" ]; then
   echo "APIC not found" 
   sleep 10
   exit 999
elif [ "${APIM_STATUS}" == "Pending" ]; then
  echo -n "APIC is still pending"
  while [ "${APIM_STATUS}" == "Pending" ]; do
    sleep 60
    echo -n "."
    APIM_STATUS=$(oc get apiconnectcluster apim-demo -n tools -o jsonpath='{.status.phase}')
  done
fi

APIC_INST_NAME='apim-demo'
APIC_NAMESPACE='tools'
PORG_NAME='cp4i-demo-org'
PORG_TITLE='CP4I Demo Provider Org'
######################
# SET APIC VARIABLES #
######################
APIC_REALM='admin/default-idp-1'
APIC_ADMIN_USER='admin'
APIC_ADMIN_ORG='admin'
APIC_USER_REGISTRY='common-services'
APIC_MGMT_SERVER=$(oc get route "${APIC_INST_NAME}-mgmt-platform-api" -n $APIC_NAMESPACE -o jsonpath="{.spec.host}")
PWD=$(oc get secret "${APIC_INST_NAME}-mgmt-admin-pass" -n $APIC_NAMESPACE -o jsonpath="{.data.password}"| base64 -d)
#################
# LOGIN TO APIC #
#################
echo "Login to APIC with CMC Admin User..."
apic login --server $APIC_MGMT_SERVER --realm $APIC_REALM -u $APIC_ADMIN_USER -p $PWD
###########################
# CREATE NEW PROVIDER ORG #
###########################
echo "Getting Values to Create Provider Organization..."
USER_URL=$(apic users:list --server $APIC_MGMT_SERVER --org $APIC_ADMIN_ORG --user-registry $APIC_USER_REGISTRY | awk -v user=$APIC_ADMIN_USER '$1 == user {print $4}')
echo "Preparing POrg File for user " $APIC_ADMIN_USER
( echo "cat <<EOF" ; cat template-apic-provider-org.json ;) | \
PORG_NAME=${PORG_NAME} \
PORG_TITLE=${PORG_TITLE} \
USER_URL=${USER_URL} \
sh > provider-org.json 2>/dev/null
echo "Creating PORG for user " $APIC_ADMIN_USER
apic orgs:create --server $APIC_MGMT_SERVER provider-org.json
echo "Cleaning up temp files..."
rm -f provider-org.json
echo "Provider Organization has been created."