$ErrorActionPreference = "Stop"
$NAMESPACE = "vllm-gemma-3-x86"
$POD = "gemma-model-loader"
$MAX_ATTEMPTS = 4

if (-not (Test-Path "./offline-models")) {
    throw "Folder ./offline-models not found. Run 00-download-models.ps1 first."
}

# Model folders are <org>/<model> under ./offline-models
$models = Get-ChildItem ./offline-models -Directory | ForEach-Object {
    $org = $_.Name
    Get-ChildItem $_.FullName -Directory | ForEach-Object { "$org/$($_.Name)" }
}
if (-not $models) { throw "No model folders found in ./offline-models." }

function Get-LocalSize($path) {
    # The .cache folder is download metadata and is not needed in the cluster.
    (Get-ChildItem $path -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.cache\\' } |
        Measure-Object Length -Sum).Sum
}

Write-Host "1. Deploying temporary Loader Pod..."
oc delete pod/$POD -n $NAMESPACE --ignore-not-found --wait=true | Out-Null
oc apply -f k8s/02-loader-pod.yaml -n $NAMESPACE

Write-Host "2. Waiting for Loader Pod to be ready (mounting PVC)..."
oc wait --for=condition=ready pod/$POD -n $NAMESPACE --timeout=180s
if ($LASTEXITCODE -ne 0) {
    Write-Host "Loader pod not ready. If events show 'Multus ... Unauthorized', run .\scripts\00-preflight.ps1 -FixMultus" -ForegroundColor Yellow
    oc get events -n $NAMESPACE --sort-by=.lastTimestamp | Select-Object -Last 5
    throw "Loader pod did not become ready."
}

Write-Host "3. Transferring models one at a time (with retries and size verification)..."
foreach ($m in $models) {
    $src = "./offline-models/$m"
    $localSize = Get-LocalSize $src
    $ok = $false
    for ($i = 1; $i -le $MAX_ATTEMPTS -and -not $ok; $i++) {
        Write-Host "   $m (attempt $i/$MAX_ATTEMPTS)..."
        oc exec $POD -n $NAMESPACE -- sh -c "rm -rf '/models-cache/offline-models/$m'; mkdir -p '/models-cache/offline-models/$(Split-Path $m)'"
        $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        # Relative source path: a drive-letter path (C:\...) is misread by oc cp as a pod:path spec.
        oc cp $src "${NAMESPACE}/${POD}:/models-cache/offline-models/$m" 2>&1 | Out-Null
        $ErrorActionPreference = $prev
        $sizes = oc exec $POD -n $NAMESPACE -- find "/models-cache/offline-models/$m" -type f -not -path "*/.cache/*" -exec stat -c %s "{}" "+" 2>$null
        $remoteSize = [int64](($sizes | Where-Object { $_ -match '^\d+$' } | Measure-Object -Sum).Sum)
        if ($remoteSize -eq $localSize) { $ok = $true } else {
            Write-Host "   Size mismatch (local=$localSize remote=$remoteSize); retrying..." -ForegroundColor Yellow
        }
    }
    if (-not $ok) { throw "Failed to transfer $m after $MAX_ATTEMPTS attempts." }
    Write-Host "   $m verified ($localSize bytes)." -ForegroundColor Green
}

Write-Host "4. Transfer complete. Deleting temporary Loader Pod..."
oc delete pod/$POD -n $NAMESPACE

Write-Host "Models are successfully staged in the OpenShift PVC!" -ForegroundColor Green
