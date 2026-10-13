$ErrorActionPreference = "Stop"
$NAMESPACE = "vllm-gemma-3-x86"

Write-Host "Deploying Air-gapped vLLM Application..."
oc apply -f k8s/03-gemma-offline-app.yaml -n $NAMESPACE

Write-Host "Waiting for pod rollout..."
Write-Host "(Since models are already on disk and networking is disabled, this should be fast)..."
oc rollout status deployment/gemma-1b-offline -n $NAMESPACE --timeout=900s
if ($LASTEXITCODE -ne 0) {
    Write-Host "Rollout failed. Diagnostics:" -ForegroundColor Red
    oc get pods -n $NAMESPACE
    $pod = oc get pods -n $NAMESPACE -l app=gemma-1b-offline -o jsonpath='{.items[0].metadata.name}'
    if ($pod) {
        oc describe pod $pod -n $NAMESPACE | Select-String -Pattern "Events:" -Context 0,15
        oc logs $pod -n $NAMESPACE --previous --tail=30 2>&1
    }
    throw "Deployment rollout failed. See output above or run .\scripts\05-diagnostics.ps1"
}

Write-Host "Air-gapped deployment successfully rolled out!" -ForegroundColor Green
