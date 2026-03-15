# make-zip.ps1 — builds lambda.zip for deployment
# Run from infra/lambda/: pwsh make-zip.ps1

Set-Location $PSScriptRoot
npm install --omit=dev
if (Test-Path lambda.zip) { Remove-Item lambda.zip }
Compress-Archive -Path index.js, node_modules, package.json -DestinationPath lambda.zip
Write-Host "lambda.zip created: $((Get-Item lambda.zip).Length) bytes"
