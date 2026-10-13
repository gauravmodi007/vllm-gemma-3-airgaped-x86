$ErrorActionPreference = "Stop"
$NAMESPACE = "vllm-gemma-3-x86"

$ROUTE_HOST = (oc get route gemma-1b-offline -n $NAMESPACE -o jsonpath='{.spec.host}')
if ([string]::IsNullOrWhiteSpace($ROUTE_HOST)) { throw "Could not resolve API route hostname." }

$URI = "http://$ROUTE_HOST/v1/chat/completions"

# Determine which model is currently configured in the deployment
$DEPLOYED_MODEL = (oc get deployment gemma-1b-offline -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].args[1]}')
if ([string]::IsNullOrWhiteSpace($DEPLOYED_MODEL)) {
    Write-Warning "Could not dynamically read the model path. Defaulting to 1B Quantized."
    $DEPLOYED_MODEL = "/models-cache/offline-models/RedHatAI/gemma-3-1b-it-quantized.w8a8"
}

$BODY = @{
    model = $DEPLOYED_MODEL
    messages = @(
        @{ role = 'user'; content = 'Explain air-gapped computer networks in one simple sentence.' }
    )
    max_tokens = 50
    temperature = 0.1
} | ConvertTo-Json -Depth 10

Write-Host "Sending test prompt to $URI..."
Write-Host "Using Model Target: $DEPLOYED_MODEL" -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $URI -Method Post -ContentType "application/json" -Body $BODY
    Write-Host "`n=================== MODEL RESPONSE ===================" -ForegroundColor Cyan
    Write-Host $response.choices[0].message.content -ForegroundColor Green
    Write-Host "======================================================`n"
} catch {
    Write-Error "Inference request failed. Run .\scripts\05-diagnostics.ps1 to inspect pod logs.`nDetails: $_"
    exit 1
}
