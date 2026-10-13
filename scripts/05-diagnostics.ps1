$ErrorActionPreference = "Continue"
$NAMESPACE = "vllm-gemma-3-x86"

Write-Host "=================== POD STATUS ===================" -ForegroundColor Yellow
oc get pods -n $NAMESPACE

Write-Host "`n=================== MEMORY USAGE (TOP POD) ===================" -ForegroundColor Yellow
oc adm top pod -n $NAMESPACE

$POD_NAME = (oc get pods -n $NAMESPACE -l app=gemma-1b-offline -o jsonpath='{.items[0].metadata.name}')
if ([string]::IsNullOrWhiteSpace($POD_NAME)) {
    Write-Error "No active pod found with label app=gemma-1b-offline"
    exit 1
}

Write-Host "`n=================== POD EVENTS ===================" -ForegroundColor Yellow
oc describe pod $POD_NAME -n $NAMESPACE | Select-String -Pattern "(?i)Events:" -Context 0,20

Write-Host "`n=================== PREVIOUS TERMINATED LOGS ===================" -ForegroundColor Yellow
$prevLogs = oc logs $POD_NAME -n $NAMESPACE --previous 2>$null
if ($LASTEXITCODE -eq 0 -and $prevLogs) { $prevLogs } else { Write-Host "No previous container restart recorded." }

Write-Host "`n=================== CURRENT LOGS (TAIL 60) ===================" -ForegroundColor Yellow
oc logs $POD_NAME -n $NAMESPACE --tail=60
