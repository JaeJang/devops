#! bin/bash
LOCAL_PATH=$1
REGISTRY=939798846182.dkr.ecr.us-west-2.amazonaws.com/develop

if [ "$LOCAL_PATH" == "" ]; then
    echo "Path to service-php-api is needed (ex. sudo sh link-php-to-minikube.sh /Users/jae/Development/PayHQ/payhq/service-php-api)"
    exit 1
fi

PATH_API=$1/api

kubectl -nhq patch deployment/php --type='json' -p="[{'op':'add', 'path':'/spec/template/spec/volumes/-', 'value':{'name':'php-local-files', 'hostPath':{'path': '$PATH_API'}}}]"
kubectl -nhq patch deployment/php --type='json' -p="[{'op':'add', 'path':'/spec/template/spec/containers/0/volumeMounts/-', 'value':{'name':'php-local-files', 'mountPath':'/home/sites/payfirma-api/current/api'}}]"

minikube ssh "cd $LOCAL_PATH && docker build -t $REGISTRY/php:develop ."

kubectl -n hq set image deployments/php php=$REGISTRY/php:develop

kubectl delete pod -nhq -l app=php