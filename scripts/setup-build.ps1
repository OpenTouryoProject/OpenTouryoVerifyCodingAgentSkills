# Download archive/<ref>.zip -> build net48 base + RichClient -> vendor to
# OpenTouryoAssemblies\Build_net48. Idempotent; re-run to refresh a tag.
# NOTE: ASCII-only comments on purpose. Windows PowerShell 5.1 reads BOM-less
# .ps1 as Windows-1252; non-ASCII (Japanese) comment bytes can corrupt parsing
# of the following statement (observed: it swallowed `$ref = '03-20'`).
$ErrorActionPreference = 'Stop'
$repo    = Split-Path -Parent $PSScriptRoot   # scripts\ parent = repo root
$ref     = '03-20'                            # fixed tag
$work    = 'C:\otr'                           # short root (avoid MAX_PATH / MSB3553)
$zip     = Join-Path $work ("OpenTouryo-" + $ref + ".zip")
$extract = Join-Path $work ("OpenTouryo-" + $ref)
$cs      = Join-Path $extract 'root\programs\CS'
$vendor  = Join-Path $repo 'OpenTouryoAssemblies\Build_net48'

# --- 1. ZIP acquisition (not git clone) ---
New-Item -ItemType Directory -Force -Path $work | Out-Null
Write-Output "DIAG: ref=$ref extract=$extract csExists=$(Test-Path $cs)"
if (-not (Test-Path $cs)) {
    if (-not (Test-Path $zip)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -OutFile $zip `
            -Uri ("https://github.com/OpenTouryoProject/OpenTouryo/archive/" + $ref + ".zip")
    }
    Expand-Archive -Path $zip -DestinationPath $work -Force
}

# --- 2. Base build (net48: the two bats the skill specifies) ---
Push-Location $cs
try {
    cmd /c ".\2_Build_NuGet_net48.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "2_Build_NuGet_net48 failed ($LASTEXITCODE)" }
    cmd /c ".\3_Build_Business_net48.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "3_Build_Business_net48 failed ($LASTEXITCODE)" }
} finally { Pop-Location }

# --- 2b. Business.RichClient (2CS / rich client dependency; not in 2_/3_ subset) ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msb = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild `
        -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
if (-not $msb) { throw "MSBuild not found" }
$brc = Join-Path $cs 'Frameworks\Infrastructure\BusinessRichClient_net48.sln'
& $msb $brc /t:restore,build /p:Configuration=Release /nologo /v:m
if ($LASTEXITCODE -ne 0) { throw "BusinessRichClient build failed ($LASTEXITCODE)" }

# --- 3. Vendor -> OpenTouryoAssemblies\Build_net48 ---
$src = Join-Path $cs 'Frameworks\Infrastructure\Build_net48'
if (-not (Test-Path $src)) { throw "Build output not found: $src" }
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $vendor -Recurse -Force
if (-not (Test-Path (Join-Path $vendor 'OpenTouryo.Business.dll'))) {
    throw "Base build did not produce OpenTouryo.Business.dll."
}
Write-Host "=== Build_net48 vendored DLLs ===" -ForegroundColor Green
Get-ChildItem $vendor -Filter 'OpenTouryo.*.dll' | Select-Object -ExpandProperty Name
