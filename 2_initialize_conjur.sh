#!/bin/bash
set -euo pipefail

# initialize conjur
## create the account defined in bootstrap.env
## store the admin key in the admin.key file so next script can change the password
## save the conjur certificate to store in the config map

export SERVICE_IP=$(oc get svc --namespace conjur \
                                          conjur-oss-ingress \
                                          -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo -e " Service is exposed at ${SERVICE_IP}:443\n" \
              "Ensure that domain "conjur.demo.com" has an A record to ${SERVICE_IP}\n" \
              "and only use the DNS endpoint https://conjur.demo.com:443 to connect.\n"

export POD_NAME=$(oc get pods --namespace $CONJUR_NAMESPACE \
                                         -l "app=conjur-oss,release=conjur-oss" \
                                         -o jsonpath="{.items[0].metadata.name}")
                                         
API_KEY_ADMIN=$(oc exec $POD_NAME --container=$CONJUR_APP_NAME --namespace $CONJUR_NAMESPACE conjurctl account create "$CONJUR_ACCOUNT") \
    && API_KEY_ADMIN=${API_KEY_ADMIN##* }

echo 'admin key:' $API_KEY_ADMIN
echo $API_KEY_ADMIN > admin.key
#ejecutar manualmente
###

echo "$SERVICE_IP conjur.demo.com" >> /etc/hosts
echo -e " Modified /etc/hosts and added line for $SERVICE_IP conjur.demo.com"
