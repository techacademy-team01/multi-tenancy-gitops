#!/usr/bin/env bash
# Before running the script you need to set two environment variables called "MAILTRAP_USER" and "MAILTRAP_PWD" with your maintrap info, using these command: 
# "export MAILTRAP_USER=my-mailtrap-user"
# "export MAILTRAP_PWD=my-mailtrap-pwd"
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
if [ -z ${MAILTRAP_USER} ]; then
  echo '$MAILTRAP_USER is required'
  exit 999
fi

echo "Configuring APIC..."
###################
# INPUT VARIABLES #
###################
APIC_INST_NAME='apim-demo'
APIC_NAMESPACE='tools'
MAILTRAP_HOST='smtp.mailtrap.io'
MAILTRAP_PORT=2525
ADMINUSER_EMAIL='admin@cp4i.demo.net'
######################
# SET APIC VARIABLES #
######################
APIC_REALM='admin/default-idp-1'
APIC_ADMIN_USER='admin'
APIC_ADMIN_ORG='admin'
APIC_MAILSERVER_NAME='dummy-mail-server'
APIC_USER_REGISTRY='common-services'
APIC_MGMT_SERVER=$(oc get route "${APIC_INST_NAME}-mgmt-platform-api" -n $APIC_NAMESPACE -o jsonpath="{.spec.host}")
PWD=$(oc get secret "${APIC_INST_NAME}-mgmt-admin-pass" -n $APIC_NAMESPACE -o jsonpath="{.data.password}"| base64 -d)
#################
# LOGIN TO APIC #
#################
echo "Login to APIC with CMC Admin User... $HOME"
apic login --accept-license --server $APIC_MGMT_SERVER --realm $APIC_REALM -u $APIC_ADMIN_USER -p $PWD
##################################################
# INITIAL APIC CONFIGURATION RIGHT AFTER INSTALL #
# UPDATE EMAIL SERVER WITH MAILTRAP INFO AND     #
# ADMIN ACCOUNT EMAIL FIELD.                     #
################################################## 
echo "Getting Mail Server Info..."
apic mail-servers:get --server $APIC_MGMT_SERVER --org $APIC_ADMIN_ORG --format json $APIC_MAILSERVER_NAME
echo "Updating Mail Server Info..."
jq --arg MAILTRAP_HOST $MAILTRAP_HOST \
    --argjson MAILTRAP_PORT $MAILTRAP_PORT \
    --arg MAILTRAP_USER $MAILTRAP_USER \
    --arg MAILTRAP_PWD $MAILTRAP_PWD \
     '.host=$MAILTRAP_HOST |
     .port=$MAILTRAP_PORT |
     .credentials.username=$MAILTRAP_USER |
     .credentials.password=$MAILTRAP_PWD | 
     del(.created_at, .updated_at)' \
    "${APIC_MAILSERVER_NAME}.json"  > "${APIC_MAILSERVER_NAME}-updated.json"
echo "Updating Mail Server..."
apic mail-servers:update --server $APIC_MGMT_SERVER --org $APIC_ADMIN_ORG $APIC_MAILSERVER_NAME "${APIC_MAILSERVER_NAME}-updated.json"
echo "Getting CMC Admin User Info..."
apic users:get --server $APIC_MGMT_SERVER --org $APIC_ADMIN_ORG --user-registry $APIC_USER_REGISTRY --format json $APIC_ADMIN_USER
echo "Updating CMC Admin User eMail Info..."
jq --arg ADMINUSER_EMAIL $ADMINUSER_EMAIL \
     '.email=$ADMINUSER_EMAIL | 
     del(.created_at, .updated_at, .last_login_at)' \
     "${APIC_ADMIN_USER}.json" > "${APIC_ADMIN_USER}-updated.json"
echo "Updating CMC Admin User..."
apic users:update --server $APIC_MGMT_SERVER --org $APIC_ADMIN_ORG --user-registry $APIC_USER_REGISTRY $APIC_ADMIN_USER "${APIC_ADMIN_USER}-updated.json"
echo "Cleaning up temp files..."
rm -f "${APIC_MAILSERVER_NAME}.json"
rm -f "${APIC_MAILSERVER_NAME}-updated.json"
rm -f "${APIC_ADMIN_USER}.json"
rm -f "${APIC_ADMIN_USER}-updated.json"
echo "APIC has been configured."