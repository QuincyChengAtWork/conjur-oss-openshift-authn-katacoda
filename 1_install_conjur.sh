#!/bin/bash
set -euo pipefail

## installing using helm
##

##creating namespace
if ! oc get namespace $CONJUR_NAMESPACE > /dev/null
then
    oc create namespace "$CONJUR_NAMESPACE"
fi

helm init
oc create serviceaccount --namespace kube-system tiller
oc create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller --upgrade

helm repo add cyberark https://cyberark.github.io/helm-charts
helm repo update

sleep 5

helm install cyberark/conjur-oss \
    --set ssl.hostname=$CONJUR_HOSTNAME_SSL,dataKey="$(docker run --rm cyberark/conjur data-key generate)",authenticators="authn-k8s/dev\,authn" \
    --namespace "$CONJUR_NAMESPACE" \
    --name "$CONJUR_APP_NAME"

echo "Wait for 5 seconds"
sleep 5s

oc get svc  conjur-oss-ingress -n $CONJUR_NAMESPACE
