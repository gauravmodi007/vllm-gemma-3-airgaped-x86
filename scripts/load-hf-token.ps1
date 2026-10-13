# Helper script to load HF_TOKEN
if ($env:HF_TOKEN -and $env:HF_TOKEN -ne "your_token_here") { return }

$tokenPath = Join-Path $HOME '.cache\huggingface\token'
if (Test-Path -LiteralPath $tokenPath) {
    $tokenVal = (Get-Content -LiteralPath $tokenPath -Raw).Trim()
    if ($tokenVal) {
        $env:HF_TOKEN = $tokenVal
        Write-Host "Loaded HF_TOKEN from Hugging Face CLI cache." -ForegroundColor Green
        return
    }
}

$envPath = Join-Path $PSScriptRoot "..\.env"
if (Test-Path -LiteralPath $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match "^\s*HF_TOKEN\s*=\s*(.+)$") {
            $val = $matches[1].Trim(' "', "'")
            if ($val -and $val -ne "your_token_here") {
                $env:HF_TOKEN = $val
                Write-Host "Loaded HF_TOKEN from .env file." -ForegroundColor Green
                return
            }
        }
    }
}

Write-Error "HF_TOKEN not found! Please set it in the .env file."
