$ErrorActionPreference = "Stop"

if (-not $env:HF_TOKEN) {
    throw "HF_TOKEN is not set. Please run `. .\scripts\load-hf-token.ps1` first."
}

# pip writes warnings to stderr, which would abort the script under "Stop".
$ErrorActionPreference = "Continue"
python -c "import huggingface_hub" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "huggingface_hub already installed, skipping pip install."
} else {
    Write-Host "Installing huggingface_hub Python library..."
    $installed = $false
    for ($i = 1; $i -le 5 -and -not $installed; $i++) {
        pip install -q huggingface_hub 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $installed = $true } else {
            Write-Host "pip install attempt $i failed; retrying..." -ForegroundColor Yellow
            Start-Sleep -Seconds 3
        }
    }
    if (-not $installed) { throw "Could not install huggingface_hub after 5 attempts." }
}
$ErrorActionPreference = "Stop"

Write-Host "Executing Python download script (retries on connection resets)..."
python scripts/download-models.py
if ($LASTEXITCODE -ne 0) { throw "Model download failed." }
