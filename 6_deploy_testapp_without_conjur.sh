#!/bin/bash
set -euo pipefail

export TEST_APP_NAMESPACE_NAME=${TEST_APP_NAMESPACE_NAME}-insecure

echo "Creating Test App namespace."

if ! oc get namespace $TEST_APP_NAMESPACE_NAME > /dev/null
then
    oc create namespace $TEST_APP_NAMESPACE_NAME
fi

oc config set-context $(oc config current-context) --namespace=$TEST_APP_NAMESPACE_NAME

echo "Build test app image"

pushd test-app/pg
    docker build -t test-app-pg:$CONJUR_NAMESPACE .
    test_app_pg_image=test-app-pg
    docker tag test-app-pg:$CONJUR_NAMESPACE $test_app_pg_image
popd

echo "Deploying test app Backend"

sed -e "s#{{ TEST_APP_PG_DOCKER_IMAGE }}#$test_app_pg_image#g" ./test-app/pg/postgres.yml |
  sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
  oc create -f -

echo "Building test app image"

pushd test-app
    docker build -t test-app:$CONJUR_NAMESPACE -f Dockerfile .
    test_app_image=test-app
    docker tag test-app:$CONJUR_NAMESPACE $test_app_image
popd

echo "Deploying test app FrontEnd"

sed -e "s#{{ TEST_APP_DOCKER_IMAGE }}#$test_app_image#g" ./test-app/test-app.yml |
    sed -e "s#{{ TEST_APP_NAMESPACE_NAME }}#$TEST_APP_NAMESPACE_NAME#g" |
    oc create -f -

echo "Waiting for services to become available"
while [ -z "$(oc describe service test-app | grep 'LoadBalancer Ingress' | awk '{ print $3 }')" ]; do
    printf "."
    sleep 1
done

echo -e "Wait for 10 seconds\n"
sleep 10s

oc describe service test-app | grep 'LoadBalancer Ingress'
app_url=$(oc describe service test-app | grep 'LoadBalancer Ingress' | awk '{ print $3 }'):8080

echo -e "Adding entry to the app\n"
curl  -d '{"name": "Insecure App"}' -H "Content-Type: application/json" $app_url/pet
