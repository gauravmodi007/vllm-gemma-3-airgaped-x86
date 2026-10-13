$ErrorActionPreference = "Stop"
$NAMESPACE = "vllm-gemma-3-x86"

Write-Host "Creating namespace $NAMESPACE..."
$nsYaml = oc create namespace $NAMESPACE --dry-run=client -o yaml
$nsYaml | oc apply -f -

Write-Host "Granting anyuid SCC to default service account..."
oc adm policy add-scc-to-user anyuid -z default -n $NAMESPACE

Write-Host "Applying PersistentVolumeClaim (20Gi)..."
oc apply -f k8s/01-pvc.yaml -n $NAMESPACE
