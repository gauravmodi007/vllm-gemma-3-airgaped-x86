param([switch]$FixMultus)

# Pre-flight checks. Run `& crc oc-env | Invoke-Expression` first if `oc` is not found.
$NAMESPACE = "vllm-gemma-3-x86"

if (-not (Get-Command oc -ErrorAction SilentlyContinue)) {
    throw "oc not found. Run: & crc oc-env | Invoke-Expression"
}

$who = oc whoami 2>$null
if ($LASTEXITCODE -ne 0) { throw "Not logged in to the cluster (oc whoami failed). Is CRC running? Try: crc status" }
Write-Host "Logged in as: $who" -ForegroundColor Green

$cutoff = (Get-Date).ToUniversalTime().AddMinutes(-15)
$unauth = oc get events -n $NAMESPACE --field-selector reason=FailedCreatePodSandBox -o json 2>$null |
    ConvertFrom-Json | ForEach-Object { $_.items } |
    Where-Object { $_.message -match 'Unauthorized' -and ([datetime]$_.lastTimestamp).ToUniversalTime() -gt $cutoff }

if ($unauth) {
    Write-Host "Found pod sandbox errors caused by Multus 'Unauthorized' (stale token)." -ForegroundColor Yellow
    if ($FixMultus) {
        oc delete pod -n openshift-multus -l app=multus
        oc delete pod -n openshift-multus -l app=multus-additional-cni-plugins
        Write-Host "Multus pods restarted. Delete any stuck pods and retry." -ForegroundColor Green
    } else {
        Write-Host "Re-run with -FixMultus to restart the Multus pods." -ForegroundColor Yellow
    }
} else {
    Write-Host "No Multus 'Unauthorized' sandbox errors found." -ForegroundColor Green
}
