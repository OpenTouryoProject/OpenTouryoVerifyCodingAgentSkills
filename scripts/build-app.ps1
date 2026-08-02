# Build the WebForms sample (3-layer, WS in-process) against the vendored
# OpenTouryo base DLLs. Reproducible from a fresh clone:
#   1. nuget restore + build the WebForms solution (WSIFType_sample / WSServer_sample
#      are ProjectReferences in the .sln -> built in-solution)
#   2. (optional) build the dev tools taken out under OT_Tools\
# Prereq: run scripts\setup-build.ps1 once first (populates OpenTouryoAssemblies\).
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

# --- resolve msbuild (VS 2019/2022/18) via vswhere ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msb = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild `
        -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
if (-not $msb) { throw "MSBuild not found (install VS Build Tools / Community)" }

$nuget = Join-Path $repo 'tools\nuget.exe'

# --- 1. restore + build the WebForms solution ---
$wfSln = Join-Path $repo 'WebForms_Sample\WebForms_Sample.sln'
& $nuget restore $wfSln    # msbuild /t:restore won't restore packages.config
if ($LASTEXITCODE -ne 0) { throw "nuget restore failed ($LASTEXITCODE)" }
& $msb $wfSln /p:Configuration=Debug /nologo /v:m
if ($LASTEXITCODE -ne 0) { throw "WebForms build failed ($LASTEXITCODE)" }

# --- 2. (optional) dev tools: HintPath + PackageReference mixed -> restore needed on net48 too ---
foreach ($tool in 'DaoGen_Tool','DPQuery_Tool') {
    $toolSln = Join-Path $repo "OT_Tools\$tool\$tool.sln"
    if (-not (Test-Path $toolSln)) { continue }
    & $msb $toolSln /t:restore,build /p:Configuration=Debug /nologo /v:m
    if ($LASTEXITCODE -ne 0) { throw "$tool build failed ($LASTEXITCODE)" }
}
Write-Host "Build OK." -ForegroundColor Green
