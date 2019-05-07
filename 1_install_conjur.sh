#!/bin/bash
set -euo pipefail

## installing using helm
##

##creating namespace
if ! oc get namespace $CONJUR_NAMESPACE > /dev/null
then
    oc create namespace "$CONJUR_NAMESPACE"
fi

# Install Helm Client
curl -ks https://storage.googleapis.com/kubernetes-helm/helm-v2.13.1-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin
sudo chmod a+x /usr/local/bin/helm
helm init --client-only

sleep 2


### Install Helm Server
export TILLER_NAMESPACE=tiller
oc new-project tiller
oc project tiller
oc policy add-role-to-user edit "system:serviceaccount:${TILLER_NAMESPACE}:tiller"
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:tiller:tiller --as=system:admin
oc process -f https://quincycheng.github.io/tiller-template.yaml -p TILLER_NAMESPACE="${TILLER_NAMESPACE}" | oc create -f -
oc rollout status deployment tiller

sleep 2


### Update Chart
helm repo add cyberark https://cyberark.github.io/helm-charts
helm repo update

sleep 2

### 
oc project conjur
oc policy add-role-to-user edit "system:serviceaccount:${TILLER_NAMESPACE}:tiller"


helm install cyberark/conjur-oss \
    --set ssl.hostname=$CONJUR_HOSTNAME_SSL,dataKey="$(docker run --rm cyberark/conjur data-key generate)",authenticators="authn-k8s/dev\,authn" \
    --namespace "$CONJUR_NAMESPACE" \
    --name "$CONJUR_APP_NAME"

echo "Wait for 5 seconds"
sleep 5s

oc get svc  conjur-oss-ingress -n $CONJUR_NAMESPACE
