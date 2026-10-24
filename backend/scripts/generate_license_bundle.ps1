# Run after `go mod download all` when backend/go.mod or go.sum changes.
$backendRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $backendRoot '../frontend/assets/legal/backend_licenses.json'

Push-Location $backendRoot
try {
  $moduleLines = go list -m -f '{{.Path}}|{{.Version}}|{{.Dir}}' all |
    Select-Object -Skip 1
  if ($LASTEXITCODE -ne 0) { throw 'go list -m all failed' }

  $entries = foreach ($line in $moduleLines) {
    $parts = $line -split '\|'
    if (-not $parts[2]) { throw "Download missing module: $($parts[0])" }
    $licenseFiles = @(Get-ChildItem -LiteralPath $parts[2] -File |
      Where-Object { $_.Name -match '^(LICENSE|LICENCE|COPYING)(\.|$)' } |
      Sort-Object Name)
    if ($licenseFiles.Count -eq 0) {
      throw "License file not found for $($parts[0])"
    }
    [pscustomobject]@{
      module = $parts[0]
      version = $parts[1]
      license = (($licenseFiles | ForEach-Object {
        Get-Content -LiteralPath $_.FullName -Raw
      }) -join "`n`n")
    }
  }
  $entries | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath $outputPath -Encoding utf8
} finally {
  Pop-Location
}
