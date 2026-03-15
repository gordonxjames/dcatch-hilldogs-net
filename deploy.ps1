# deploy.ps1 — Build and deploy the Delta Catcher frontend
# Reads S3_BUCKET and CF_DISTRIBUTION_ID from infra/outputs.env at runtime.
# Usage: pwsh deploy.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputsEnv = Join-Path $ScriptDir 'infra\outputs.env'

if (-not (Test-Path $OutputsEnv)) {
    Write-Error "infra/outputs.env not found. Copy outputs.env.template and populate it."
    exit 1
}

# Parse key=value pairs from outputs.env
$env_vars = @{}
foreach ($line in Get-Content $OutputsEnv) {
    if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
    $parts = $line -split '=', 2
    $env_vars[$parts[0].Trim()] = $parts[1].Trim()
}

$S3Bucket       = $env_vars['S3_BUCKET']
$DistributionId = $env_vars['CF_DISTRIBUTION_ID']

if (-not $S3Bucket -or -not $DistributionId) {
    Write-Error "S3_BUCKET or CF_DISTRIBUTION_ID missing from infra/outputs.env"
    exit 1
}

Write-Host "==> S3 bucket:      $S3Bucket"
Write-Host "==> Distribution:   $DistributionId"

# Build
$FrontendDir = Join-Path $ScriptDir 'frontend'
Push-Location $FrontendDir
try {
    Write-Host "`n==> npm install"
    npm install

    Write-Host "`n==> npm run build"
    npm run build
} finally {
    Pop-Location
}

# Sync to S3
$DistDir = Join-Path $FrontendDir 'dist'
Write-Host "`n==> Syncing dist/ to s3://$S3Bucket"
aws s3 sync $DistDir "s3://$S3Bucket" --delete

# Invalidate CloudFront cache
Write-Host "`n==> Invalidating CloudFront distribution $DistributionId"
aws cloudfront create-invalidation --distribution-id $DistributionId --paths "/*"

Write-Host "`n==> Deploy complete."
