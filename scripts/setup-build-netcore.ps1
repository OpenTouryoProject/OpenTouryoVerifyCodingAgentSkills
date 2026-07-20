# Build net10.0 base + RichClient -> vendor to OpenTouryoAssemblies\Build_netcore100.
# Reuses the existing C:\otr extract from setup-build.ps1 (no re-download).
# ASCII-only comments on purpose (see setup-build.ps1 note on WinPS 5.1 encoding).
$ErrorActionPreference = 'Stop'
$repo    = Split-Path -Parent $PSScriptRoot
$ref     = '03-20'
$work    = 'C:\otr'
$zip     = Join-Path $work ("OpenTouryo-" + $ref + ".zip")
$extract = Join-Path $work ("OpenTouryo-" + $ref)
$cs      = Join-Path $extract 'root\programs\CS'
$vendor  = Join-Path $repo 'OpenTouryoAssemblies\Build_netcore100'

# --- 1. reuse existing extract (or acquire ZIP) ---
Write-Output "DIAG: ref=$ref csExists=$(Test-Path $cs)"
if (-not (Test-Path $cs)) {
    if (-not (Test-Path $zip)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -OutFile $zip `
            -Uri ("https://github.com/OpenTouryoProject/OpenTouryo/archive/" + $ref + ".zip")
    }
    Expand-Archive -Path $zip -DestinationPath $work -Force
}

# --- 2. base build (netcore100 bats) + 2b RichClient ---
Push-Location $cs
try {
    cmd /c ".\2_Build_NuGet_netcore100.bat    < nul"
    if ($LASTEXITCODE -ne 0) { throw "2_Build_NuGet_netcore100 failed ($LASTEXITCODE)" }
    cmd /c ".\3_Build_Business_netcore100.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "3_Build_Business_netcore100 failed ($LASTEXITCODE)" }
    cmd /c ".\3_Build_BusinessRichClient_netcore100.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "3_Build_BusinessRichClient_netcore100 failed ($LASTEXITCODE)" }
} finally { Pop-Location }

# --- 3. vendor whole Build_netcore100 (both TFM subfolders) ---
$src = Join-Path $cs 'Frameworks\Infrastructure\Build_netcore100'
if (-not (Test-Path $src)) { throw "Build output not found: $src" }
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $vendor -Recurse -Force
if (-not (Test-Path (Join-Path $vendor 'net10.0\OpenTouryo.Business.dll'))) {
    throw "netcore base build did not produce net10.0\OpenTouryo.Business.dll."
}
if (-not (Test-Path (Join-Path $vendor 'net10.0-windows7.0\OpenTouryo.Business.dll'))) {
    throw "net10.0-windows7.0\OpenTouryo.Business.dll missing (RichClient build?)."
}
Write-Host "=== Build_netcore100 vendored (net10.0-windows7.0) ===" -ForegroundColor Green
Get-ChildItem (Join-Path $vendor 'net10.0-windows7.0') -Filter 'OpenTouryo.*.dll' | Select-Object -ExpandProperty Name
