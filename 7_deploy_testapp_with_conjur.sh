#!/bin/bash
set -euo pipefail

source bootstrap.env

echo "Creating Test App namespace."

if ! kubectl get namespace $TEST_APP_NAMESPACE_NAME > /dev/null
then
    kubectl create namespace $TEST_APP_NAMESPACE_NAME
fi

kubectl config set-context $(kubectl config current-context) --namespace=$TEST_APP_NAMESPACE_NAME

echo "Adding Role Binding for conjur service account"

kubectl create -f ./kubernetes/test-app-conjur-authenticator-role-binding.yml

echo "Storing non-secret conjur cert as test app configuration data"

kubectl delete --ignore-not-found=true configmap conjur-cert

# Store the Conjur cert in a ConfigMap.
kubectl create configmap conjur-cert --from-file=ssl-certificate=./conjur-$CONJUR_ACCOUNT.pem

echo "Conjur cert stored."

echo "Pushing postgres image to google registry"

pushd test-app/pg
    docker build -t test-app-pg:$CONJUR_NAMESPACE .
    test_app_pg_image=test-app-pg
    docker tag test-app-pg:$CONJUR_NAMESPACE $test_app_pg_image
popd

echo "Deploying test app Backend"

sed -e "s#{{ TEST_APP_PG_DOCKER_IMAGE }}#$test_app_pg_image#g" ./test-app/pg/postgres.yml |
  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
  kubectl create -f -

echo "Building test app image"

pushd test-app
    docker build -t test-app:$CONJUR_NAMESPACE -f Dockerfile.conjur .
    test_app_image=test-sidecar-app
    docker tag test-app:$CONJUR_NAMESPACE $test_app_image
popd

echo "Deploying test app FrontEnd"

conjur_authenticator_url=$CONJUR_URL/authn-k8s/$AUTHENTICATOR_ID
export SERVICE_IP=$(kubectl get svc --namespace conjur \
                                          conjur-oss-ingress \
                                          -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_app_image#g" ./test-app/test-app-conjur.yml |
  sed -e "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
  sed -e "s#{{ CONJUR_APPLIANCE_URL }}#$CONJUR_URL#g" |
  sed -e "s#{{ CONJUR_AUTHN_URL }}#$conjur_authenticator_url#g" |
  sed -e "s#{{ SERVICE_IP }}#$SERVICE_IP#g" |
  kubectl create -f -


echo "Waiting for services to become available"
while [ -z "$(kubectl describe service test-app-summon-sidecar | grep 'LoadBalancer Ingress' | awk '{ print $3 }')" ]; do
    printf "."
    sleep 1
done

kubectl describe service test-app-summon-sidecar | grep 'LoadBalancer Ingress'

app_url=$(kubectl describe service test-app-summon-sidecar | grep 'LoadBalancer Ingress' | awk '{ print $3 }'):8080

#########


  $cli create configmap test-app-secretless-config \
    --from-file=etc/secretless.yml

  sleep 5

  ensure_env_database
  case "${TEST_APP_DATABASE}" in
  postgres)
    PORT=5432
    PROTOCOL=postgresql
    ;;
  mysql)
    PORT=3306
    PROTOCOL=mysql
    ;;
  esac
  secretless_db_url="$PROTOCOL://localhost:$PORT/test_app"

  sed "s#{{ CONJUR_VERSION }}#$CONJUR_VERSION#g" ./$PLATFORM/test-app-secretless.yml |
    sed "s#{{ SECRETLESS_IMAGE }}#$secretless_image#g" |
    sed "s#{{ SECRETLESS_DB_URL }}#$secretless_db_url#g" |
    sed "s#{{ CONJUR_AUTHN_URL }}#$conjur_authenticator_url#g" |
    sed "s#{{ CONJUR_AUTHN_LOGIN_PREFIX }}#$conjur_authn_login_prefix#g" |
    sed "s#{{ CONFIG_MAP_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    sed "s#{{ CONJUR_ACCOUNT }}#$CONJUR_ACCOUNT#g" |
    sed "s#{{ CONJUR_APPLIANCE_URL }}#$conjur_appliance_url#g" |
    kubectl create -f -

  echo "Secretless test app deployed."




####




echo -e "Wait for 20 seconds\n"
sleep 20s

echo -e "Adding entry to the sidecar app\n"
curl  -d '{"name": "Mr. Sidecar"}' -H "Content-Type: application/json" $app_url/pet
