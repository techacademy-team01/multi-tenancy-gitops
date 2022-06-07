#!/bin/sh
echo "Publising API and Enabling Portal in Sandbox Catalog..."
###################
# INPUT VARIABLES #
###################
APIC_INST_NAME='apim-demo'
APIC_NAMESPACE='tools'
APIC_ORG='cp4i-demo-org'
#PORG_NAME='cp4i-demo-org'
#PORG_TITLE='CP4I Demo Provider Org'
######################
# SET APIC VARIABLES #
######################
APIC_CATALOG='sandbox'
APIC_PORTAL_TYPE='drupal'
#APIC_REALM='admin/default-idp-1'
#APIC_ADMIN_USER='admin'
#APIC_ADMIN_ORG='admin'
#APIC_USER_REGISTRY='common-services'
APIC_MGMT_SERVER=$(oc get route "${APIC_INST_NAME}-mgmt-platform-api" -n $APIC_NAMESPACE -o jsonpath="{.spec.host}")
#PWD=$(oc get secret "${APIC_INST_NAME}-mgmt-admin-pass" -n $APIC_NAMESPACE -o jsonpath="{.data.password}"| base64 -d)
#################
# LOGIN TO APIC #
#################
echo "Login to APIC with CP4I Admin User using SSO..."
#apic login --server $APIC_MGMT_SERVER --realm $APIC_REALM -u $APIC_ADMIN_USER -p $PWD
apic login --server $APIC_MGMT_SERVER --sso --context provider
###################
# PUBLISH NEW API #
###################
echo "Getting Values to Publish API..."
TARGET_URL=$(oc get integrationserver jgr-designer-sfleads -n tools -o jsonpath='{.status.endpoints[0].uri}')'/SFLeads/lead'
PREMIUM_URL=$(oc get integrationserver jgr-mqapi-prem -n tools -o jsonpath='{.status.endpoints[0].uri}')
DEFAULT_URL=$(oc get integrationserver jgr-mqapi-dflt -n tools -o jsonpath='{.status.endpoints[0].uri}')
#USER_URL=$(apic users:list --server $APIC_MGMT_SERVER --org $APIC_ADMIN_ORG --user-registry $APIC_USER_REGISTRY | awk -v user=$APIC_ADMIN_USER '$1 == user {print $4}')
echo "Preparing API File..."
( echo "cat <<EOF" ; cat template-apic-api-def-jgrmqapiv2.yaml ;) | \
TARGET_URL=${TARGET_URL} \
PREMIUM_URL=${PREMIUM_URL} \
DEFAULT_URL=${DEFAULT_URL} \
MSG_BODY_VAL='$(message.body)' \
INVOKE_URL_VAL1='$(target-url)' \
INVOKE_URL_VAL2='$(default-url)$(my-path)' \
INVOKE_URL_VAL3='$(premium-url)$(my-path)' \
ref='$ref' \
sh > jgrmqapi_1.2.0.yaml
echo "Publishing API..."
apic draft-apis:create --server $APIC_MGMT_SERVER --org $APIC_ORG jgrmqapi_1.2.0.yaml
apic draft-products:create --server $APIC_MGMT_SERVER --org $APIC_ORG 02-jgr-mqapi-product.yaml
###################################
# UPDATE CATALOG TO ENABLE PORTAL #
###################################
echo "Getting Poratl URL..."
APIC_PORTAL_URL=$(apic portal-services:list --server $APIC_MGMT_SERVER --scope org --org $APIC_ORG | awk '{print $2}')
echo $APIC_PORTAL_URL
echo "Getting Catalog Settings..."
apic catalog-settings:get --server $APIC_MGMT_SERVER --org $APIC_ORG --catalog $APIC_CATALOG --format json
echo "Updating Catalog Settings File..."
jq  --arg PORTAL_URL $APIC_PORTAL_URL \
    --arg APIC_PORTAL_TYPE $APIC_PORTAL_TYPE \
        '.portal.type= $APIC_PORTAL_TYPE |
        .portal.portal_service_url=$PORTAL_URL |
        del(.created_at, .updated_at)' \
        catalog-setting.json > catalog-setting-updated.json
echo "Enabling Portal in Catalog..."
#apic catalog-settings:update --server $APIC_MGMT_SERVER --org $APIC_ORG --catalog $APIC_CATALOG catalog-setting-updated.json
echo "Cleaning up temp files..."
rm -f jgrmqapi_1.2.0.yaml
rm -f catalog-setting.json
rm -f catalog-setting-updated.json
echo "API has been published and Portal enabled"    