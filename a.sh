#! bin/bash
LOCAL_PATH=$1
REGISTRY=939798846182.dkr.ecr.us-west-2.amazonaws.com/develop

if [ "$LOCAL_PATH" == "" ]; then
    echo "Path to service-php-api is needed"
    exit 1
fi

touch php-local-deployment.yaml
cat > php-local-deployment.yaml << EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: php
  namespace: hq
spec:
  replicas: 4
  template:
    metadata:
      labels:
        app: php
      annotations:
        repo: php
    spec:
      volumes:
      - name: php-local-file
        hostPath: 
          path: $LOCAL_PATH/api
      - name: media-persistent-storage
        persistentVolumeClaim:
          claimName: media-pv-claim
      - name: server-keystore
        secret:
          secretName: server-keystore
      containers:
      - name: php
        volumeMounts:
        - name: php-local-file
          mountPath: /home/sites/payfirma-api/current/api
        - name: media-persistent-storage
          mountPath: /home/sites/payfirma-api/media/
        - name: server-keystore
          mountPath: /run/secrets/server-keystore
          readOnly: true
        image: 939798846182.dkr.ecr.us-west-2.amazonaws.com/develop/php:latest
        imagePullPolicy: Always
        readinessProbe:
          httpGet:
            port: 8443
            path: /transactions_for_java
            scheme: HTTPS
        livenessProbe:
          initialDelaySeconds: 900
          periodSeconds: 60
          httpGet:
            port: 8443
            path: /transactions_for_java
            scheme: HTTPS
        resources:
          requests:
            memory: 100Mi
          limits:
            memory: 700Mi
        ports:
        - containerPort: 8443
          name: https
        env:
        - name: NEWRELIC_ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: crux-config
              key: NEWRELIC_ENVIRONMENT
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-password
              key: DB_PASSWORD
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-username
              key: DB_USERNAME
        - name: EXTRA_JAVA_OPTS
          valueFrom:
            configMapKeyRef:
              name: crux-config
              key: EXTRA_JAVA_OPTS
              optional: true
        - name: KEY_STORE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: key-store-password
              key: KEY_STORE_PASSWORD
        - name: CERT_ALIAS
          valueFrom:
            configMapKeyRef:
              name: crux-config
              key: CERT_ALIAS
EOF
kubectl -nhq patch deployment/php --type='json' -p='[{"op":"add", "path":"/spec/template/spec/volumes/-", "value":{"name":"php-local-files", "hostPath":{"path": "$LOCAL_PATH/api"}}}]'
kubectl -nhq patch deployment/php --type='json' -p='[{"op":"add", "path":"/spec/template/spec/containers/0/volumeMounts/-", "value":{"name":"php-local-files", "mountPath":"/home/sites/payfirma-api/current/api"}}]'

#kubectl delete deployment -nhq php
kubectl create -f php-local-deployment.yaml
kubectl -nhq patch deployment/php -p "{\"spec\":{\"replicas\": 1}}"
kubectl -nhq patch deployment/php --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "IfNotPresent"}]'
kubectl -nhq patch deployment/php --type='json' -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/readinessProbe"}]'
kubectl -nhq patch deployment/php --type='json' -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/livenessProbe"}]'
kubectl -nhq patch deployment/php --type='json' -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/resources"}]'
kubectl -nhq patch deployment/php --type='json' -p='[{"op": "remove", "path": "/spec/template/spec/affinity"}]'
minikube ssh "cd $LOCAL_PATH && docker build -t $REGISTRY/php:develop ."
kubectl -n hq set image deployments/php php=$REGISTRY/php:develop
kubectl delete pod -nhq -l app=php
rm php-local-deployment.yaml