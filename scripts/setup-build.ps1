# Download archive/<ref>.zip -> build net48 base -> vendor to
# OpenTouryoAssemblies\Build_net48. Idempotent; re-run to refresh a ref.
# Target sample: WebForms_Sample (net48 only, no RichClient, no base2 overlay).
$ErrorActionPreference = 'Stop'
$repo    = Split-Path -Parent $PSScriptRoot   # scripts\ の親 = repo root
$ref     = 'develop'                          # branch (latest); test1-setup case 3
# Base build runs from a SHORT root (C:\otr), not <repo>\Temp: the legacy
# net48 Business build writes a very long generated .resources filename;
# under a deep repo path the fully-qualified path exceeds MAX_PATH (MSB3553).
$work    = 'C:\otr'
$zip     = Join-Path $work "OpenTouryo-$ref.zip"
$extract = Join-Path $work "OpenTouryo-$ref"
$cs      = Join-Path $extract 'root\programs\CS'
$vendor  = Join-Path $repo 'OpenTouryoAssemblies\Build_net48'
$overlay = Join-Path $repo 'base2-overlay'    # present only when customizing base class 2

# --- 1. ZIP acquisition (not git clone) ---
New-Item -ItemType Directory -Force -Path $work | Out-Null
if (-not (Test-Path $extract)) {
    if (-not (Test-Path $zip)) {
        # WebClient.DownloadFile() defaults to an old TLS and gets 404 from GitHub
        # codeload (a HEAD returns 200 -> misleading). Force TLS 1.2 + Invoke-WebRequest.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://github.com/OpenTouryoProject/OpenTouryo/archive/$ref.zip" -OutFile $zip
    }
    Expand-Archive -Path $zip -DestinationPath $work -Force
}
if (-not (Test-Path $cs)) { throw "extract layout unexpected: $cs not found" }

# --- 1b. (optional) apply base2 overlay BEFORE building ---
# Not used here (no base2-overlay in this repo); kept for parity with the skill.
if (Test-Path $overlay) {
    Copy-Item -Path (Join-Path $overlay '*') -Destination $cs -Recurse -Force
}

# --- 2. Base build (net48 only: the two bats the skill specifies) ---
# pause at bat end -> feed NUL; run from CS so relative paths resolve.
Push-Location $cs
try {
    cmd /c ".\2_Build_NuGet_net48.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "2_Build_NuGet_net48 failed ($LASTEXITCODE)" }
    cmd /c ".\3_Build_Business_net48.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "3_Build_Business_net48 failed ($LASTEXITCODE)" }
} finally { Pop-Location }

# --- 2b. Business.RichClient: NOT needed for WebForms_Sample (2CS / WSClient only) ---

# --- 3. Vendor -> OpenTouryoAssemblies\Build_net48 ---
$src = Join-Path $cs 'Frameworks\Infrastructure\Build_net48'
if (-not (Test-Path $src)) { throw "Build output not found: $src" }
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $vendor -Recurse -Force
# The .bat wrappers end with `pause` and swallow msbuild's exit code, so confirm
# the build actually produced the Business DLL (most prone to fail: MSB3553).
if (-not (Test-Path (Join-Path $vendor 'OpenTouryo.Business.dll'))) {
    throw "Base build did not produce OpenTouryo.Business.dll (check the build output above)."
}
Get-ChildItem $vendor -Filter 'OpenTouryo.*.dll' | Select-Object -ExpandProperty Name
