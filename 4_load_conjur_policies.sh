#!/bin/bash
set -euo pipefail

export SERVICE_IP=$(oc get svc --namespace conjur \
     conjur-oss-ingress \
     -o jsonpath='{.status.loadBalancer.ingress[0].ip}')


rm -rf mydata/

docker run --rm -it --add-host conjur.demo.com:$SERVICE_IP -v $(pwd)/mydata/:/root --entrypoint bash cyberark/conjur-cli:5 -c "yes yes | conjur init -a $CONJUR_ACCOUNT -u $CONJUR_URL"
docker run --rm -it --add-host conjur.demo.com:$SERVICE_IP -v $(pwd)/mydata/:/root cyberark/conjur-cli:5 authn login -u admin -p $CONJUR_ADMIN_PASSWORD

cp -rf policy mydata/policy

docker run --rm -it --add-host conjur.demo.com:$SERVICE_IP -v $(pwd)/mydata/:/root cyberark/conjur-cli:5 policy load root /root/policy/users.yml
docker run --rm -it --add-host conjur.demo.com:$SERVICE_IP -v $(pwd)/mydata/:/root cyberark/conjur-cli:5 policy load root /root/policy/app-id.yml
docker run --rm -it --add-host conjur.demo.com:$SERVICE_IP -v $(pwd)/mydata/:/root cyberark/conjur-cli:5 policy load root /root/policy/cluster-auth-svc.yml
docker run --rm -it --add-host conjur.demo.com:$SERVICE_IP -v $(pwd)/mydata/:/root cyberark/conjur-cli:5 policy load root /root/policy/app-identity-access-to-secrets.yml
docker run --rm -it --add-host conjur.demo.com:$SERVICE_IP -v $(pwd)/mydata/:/root cyberark/conjur-cli:5 policy load root /root/policy/app-access.yml

docker run --rm -it --add-host conjur.demo.com:$SERVICE_IP -v $(pwd)/mydata/:/root cyberark/conjur-cli:5 variable values add orquestador-ajustadores-app/db-username "test_app"
docker run --rm -it --add-host conjur.demo.com:$SERVICE_IP -v $(pwd)/mydata/:/root cyberark/conjur-cli:5 variable values add orquestador-ajustadores-app/db-password "5b3e5f75cb3cdc725fe40318"
docker run --rm -it --add-host conjur.demo.com:$SERVICE_IP -v $(pwd)/mydata/:/root cyberark/conjur-cli:5 variable values add orquestador-ajustadores-app/url "postgresql://test-summon-sidecar-app-backend.orquestador.svc.cluster.local:5432/postgres"
