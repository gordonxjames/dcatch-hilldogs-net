# configure-lambda.ps1 — Phase 2
# Sets Lambda environment variables (ALERT_FROM_EMAIL, ALERT_TO_EMAIL) from outputs.env.
# Run from repo root: pwsh infra/configure-lambda.ps1

param()

$ErrorActionPreference = "Stop"
$ScriptDir  = $PSScriptRoot
$OutputsPath = Join-Path $ScriptDir "outputs.env"

if (-not (Test-Path $OutputsPath)) {
    Write-Error "outputs.env not found at $OutputsPath"
    exit 1
}

# Parse outputs.env
$envVars = @{}
foreach ($line in Get-Content $OutputsPath) {
    if ($line -match '^([^#=\s]+)=(.*)$') {
        $envVars[$Matches[1]] = $Matches[2]
    }
}

$FunctionName    = $envVars["LAMBDA_FUNCTION_NAME"]
$Region          = "us-east-2"
$AlertFromEmail  = $envVars["ALERT_FROM_EMAIL"]
$AlertToEmail    = $envVars["ALERT_TO_EMAIL"]

if (-not $FunctionName) { Write-Error "LAMBDA_FUNCTION_NAME not found in outputs.env"; exit 1 }
if (-not $AlertFromEmail) { Write-Error "ALERT_FROM_EMAIL not found in outputs.env"; exit 1 }
if (-not $AlertToEmail) { Write-Error "ALERT_TO_EMAIL not found in outputs.env"; exit 1 }

Write-Host "Configuring Lambda $FunctionName..."

$envJson = "Variables={ALERT_FROM_EMAIL=$AlertFromEmail,ALERT_TO_EMAIL=$AlertToEmail}"

aws lambda update-function-configuration `
    --function-name $FunctionName `
    --environment $envJson `
    --region $Region | Out-Null

Write-Host "  ALERT_FROM_EMAIL = $AlertFromEmail"
Write-Host "  ALERT_TO_EMAIL   = $AlertToEmail"
Write-Host "Lambda configuration complete."
