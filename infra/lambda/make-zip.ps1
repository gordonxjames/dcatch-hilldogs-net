# make-zip.ps1 — builds lambda.zip for deployment
# Run from infra/lambda/: pwsh make-zip.ps1

Set-Location $PSScriptRoot
$out = Join-Path $PSScriptRoot 'lambda.zip'

# Install production dependencies (no-op when there are none)
Write-Host "Installing production dependencies..."
npm install --omit=dev

if (Test-Path $out) { Remove-Item $out }

# Files to exclude from the zip (build scripts are not needed in Lambda)
$exclude = @('lambda.zip', 'make-zip.ps1')

$files = Get-ChildItem -Path $PSScriptRoot -Recurse -File | Where-Object {
    $_.Name -notin $exclude
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($out, 'Create')

foreach ($file in $files) {
    $entryName = $file.FullName.Substring($PSScriptRoot.Length + 1).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, $file.FullName, $entryName, 'Optimal') | Out-Null
    Write-Host "  + $entryName"
}

$zip.Dispose()
Write-Host "`nlambda.zip: $((Get-Item $out).Length) bytes, $($files.Count) files"
