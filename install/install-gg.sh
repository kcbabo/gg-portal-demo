#!/bin/bash

set +x -e

source ./env.sh

# Check that required env-vars have been set.
if [ -z "$GLOO_GATEWAY_LICENSE_KEY" ]
then
      printf "\nThe 'GLOO_GATEWAY_LICENSE_KEY' environment variable is empty. This environment variable, set to a valid Gloo Gateway License Key, is required to run the installation.\n"
      exit 1
fi

kubectl create ns gloo-mesh || true
kubectl create ns gloo-mesh-addons || true

helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
if [ "$BACKSTAGE_ENABLED" = true ] ; then
  helm repo add ddoyle-gloo-demo https://duncandoyle.github.io/gloo-demo-helm-charts
fi

helm repo update

if [ "$DEV_VERSION" = true ] ; then
  # export MESH_CRD_URL="https://storage.googleapis.com/gloo-platform-dev/helm-charts/gloo-mesh-crds/gloo-mesh-crds-${GLOO_VERSION}.tgz"
  # export MESH_CHART_URL="https://storage.googleapis.com/gloo-platform-dev/helm-charts/gloo-mesh-enterprise/gloo-mesh-enterprise-${GLOO_VERSION}.tgz"
  export MESH_CRD_URL="https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts/gloo-platform-crds-${GLOO_VERSION}.tgz"
  export MESH_CHART_URL="https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts/gloo-platform-${GLOO_VERSION}.tgz"
fi

MESH_HOME=$HOME/.gloo-mesh
MESHCTL_BIN=$MESH_HOME/bin
  
if [ "$DEV_VERSION" = false ] ; then
  curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v$GLOO_VERSION sh -  
else 
  mkdir -p ${MESHCTL_BIN}
  rm ${MESHCTL_BIN}/meshctl || true
  if [  "$(uname -m)" = "aarch64" ]; then
	  GOARCH=arm64
  elif [ "$(uname -m)" = "arm64" ]; then
	  GOARCH=arm64
  else
	  GOARCH=amd64
  fi
  GLOO_MESH_VERSION=v$GLOO_VERSION
  wget "https://storage.googleapis.com/gloo-platform-dev/meshctl/${GLOO_MESH_VERSION}/meshctl-darwin-${GOARCH}" -O ${MESHCTL_BIN}/meshctl
  chmod +x ${MESHCTL_BIN}/meshctl
fi

$MESHCTL_BIN/meshctl version

# install CRDs
if [ "$DEV_VERSION" = false ] ; then
  printf "\nInstalling Gloo Gateway CRDs ...\n"
  helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds \
    --namespace=gloo-mesh \
    --create-namespace \
    --version $GLOO_VERSION
else
  helm install gloo-platform-crds $MESH_CRD_URL \
    --namespace=gloo-mesh \
    --create-namespace 
fi

if [ "$DEV_VERSION" = false ] ; then
  GLOO_GATEWAY_HELM_VALUES_FILE=gloo-gateway-single.yaml
else
  GLOO_GATEWAY_HELM_VALUES_FILE=gloo-gateway-single-dev.yaml
fi

if [ "$API_ANALYTICS_ENABLED" = true ] ; then
  if [ "$DEV_VERSION" = false ] ; then
    GLOO_GATEWAY_HELM_VALUES_FILE=gloo-gateway-single-api-analytics.yaml
  else
    GLOO_GATEWAY_HELM_VALUES_FILE=gloo-gateway-single-api-analytics-dev.yaml
  fi
  printf "\nInstalling Clickhouse password authentication secret.\n"
  kubectl apply -f ../misc/clickhouse-auth-secret.yaml
fi

echo "Gloo Version: $GLOO_VERSION"
echo "Gloo Gateway Values File: $GLOO_GATEWAY_HELM_VALUES_FILE"

# install GG with addons
printf "\nInstalling Gloo Gateway ...\n"
if [ "$DEV_VERSION" = false ] ; then
  helm upgrade --install gloo-platform gloo-platform/gloo-platform \
    --namespace gloo-mesh \
    --version $GLOO_VERSION \
    --values $GLOO_GATEWAY_HELM_VALUES_FILE \
    --set common.cluster=$CLUSTER_NAME \
    --set licensing.glooGatewayLicenseKey=$GLOO_GATEWAY_LICENSE_KEY
else
  helm install gloo-platform $MESH_CHART_URL \
    --namespace gloo-mesh \
    --values $GLOO_GATEWAY_HELM_VALUES_FILE \
    --set common.cluster=$CLUSTER_NAME \
    --set licensing.glooGatewayLicenseKey=$GLOO_GATEWAY_LICENSE_KEY
fi

printf "\nWaiting for gloo-mesh-gateways namespace...\n"
until kubectl get ns gloo-mesh-gateways &>/dev/null; do
  sleep 3
done

printf "\nWaiting for gateway deployment creation...\n"
until kubectl get deployment -n gloo-mesh-gateways istio-ingressgateway-$ISTIO_REVISION &>/dev/null; do
  sleep 3
done

printf "Waiting for ingress gateway deployment to be ready, this might take a while...\n"
kubectl rollout status deployment -n gloo-mesh-gateways istio-ingressgateway-$ISTIO_REVISION --timeout=5m
printf "Ingress gateway deployment ready!\n\n"

# Create gateway
kubectl apply -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualGateway
metadata:
  name: istio-ingressgateway
  namespace: ${GATEWAY_NAMESPACE}
spec:
  listeners:
    - http: {}
      port:
        number: 80
      allowedRouteTables:
        - host: api.example.com
        - host: graphql.api.example.com
        - host: developer.example.com
        - host: developer.partner.example.com
        - host: keycloak.example.com
        - host: grafana.example.com
        - host: argocd.example.com
  workloads:
  - selector:
      labels:
        istio: ingressgateway
      cluster: ${CLUSTER_NAME}
EOF

sleep 3

GW_HOST=$(kubectl get svc -n gloo-mesh-gateways istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
[[ -z "$GW_HOST" ]] && { GW_HOST=$(kubectl get svc -n gloo-mesh-gateways istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}');}
printf "\nIngress gateway hostame: %s\n" $GW_HOST

pushd ../
printf "\nInstalling Keycloak\n"
kubectl create ns keycloak
#kubectl -n keycloak create -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/21.0.2/kubernetes-examples/keycloak.yaml
kubectl -n keycloak create -f misc/keycloak.yaml
kubectl -n keycloak rollout status deploy/keycloak
KC_HOST=$(kubectl -n keycloak get svc keycloak -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
[[ -z "$KC_HOST" ]] && { KC_HOST=$(kubectl -n keycloak get svc keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}');}
printf "\nKeycloak service hostname: %s\n\n" $KC_HOST

kubectl apply -f keycloak-example-com-rt.yaml

# API Usage & Analytics
if [ "$API_ANALYTICS_ENABLED" = true ] ; then
  printf "\nAPI Usage & Analytics: Deploying Grafana and Grafana Dashboards.\n"
  kubectl apply -f misc/dashboards.yaml
  kubectl apply -f misc/grafana.yaml
  kubectl apply -f grafana-example-com-rt.yaml
fi
popd

if [ "$BACKSTAGE_ENABLED" = true ] ; then
  kubectl create ns backstage

  # Create a backstage service account that can access the Kubernetes API.
  kubectl -n backstage create serviceaccount backstage-kube-sa
  
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: Secret
  metadata:
    name: backstage-kube-sa-secret
    namespace: backstage
    annotations:
      kubernetes.io/service-account.name: backstage-kube-sa
  type: kubernetes.io/service-account-token
EOF

  kubectl apply -f - <<EOF
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRole
  metadata:
    name: backstage-read-only
  rules:
    - apiGroups:
        - '*'
      resources:
        - pods
        - configmaps
        - services
        - deployments
        - replicasets
        - horizontalpodautoscalers
        - ingresses
        - statefulsets
        - limitranges
        - daemonsets
        - routetables
      verbs:
        - get
        - list
        - watch
    - apiGroups:
        - batch
      resources:
        - jobs
        - cronjobs
      verbs:
        - get
        - list
        - watch
    - apiGroups:
        - metrics.k8s.io
      resources:
        - pods
      verbs:
        - get
        - list
EOF

  kubectl apply -f - <<EOF
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: backstage-kube-sa-read-only
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: backstage-read-only
  subjects:
  - kind: ServiceAccount
    name: backstage-kube-sa
    namespace: backstage
EOF

  printf "\nDeploying Backstage.\n"
  helm upgrade --install gp-portal-demo-backstage ddoyle-gloo-demo/gp-portal-demo-backstage --namespace backstage --create-namespace --version 0.1.4 \
  --set kubernetes.skipTLSVerify=true

fi