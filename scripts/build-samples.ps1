# Build the self-contained sample solutions and report one line per solution.
# net48 -> nuget restore + msbuild ; core -> dotnet build.
$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
$env:OT_RESOURCE_ROOT = Join-Path $repo 'resource'
$nuget = Join-Path $repo 'tools\nuget.exe'
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msb = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
$dotnet = 'C:\Program Files\dotnet\dotnet.exe'

$net48 = @(
  '2CSClientWin_sample\2CSClientWin_sample.sln',
  '2CSClientWPF_sample\2CSClientWPF_sample.sln',
  'SimpleBatch_sample\SimpleBatch_sample.sln',
  'RerunnableBatch_sample\RerunnableBatch_sample.sln',
  'RerunnableBatch_sample2\RerunnableBatch_sample2.sln',
  'RerunnableBatch_sample3\RerunnableBatch_sample3.sln'
)
$core = @(
  'MVC_Sample_Core\MVC_Sample.sln',
  'SimpleBatch_sample_Core\SimpleBatch_sample.sln',
  'RerunnableBatch_sample_Core\RerunnableBatch_sample.sln',
  'RerunnableBatch_sample2_Core\RerunnableBatch_sample2.sln',
  'RerunnableBatch_sample3_Core\RerunnableBatch_sample3.sln',
  'Simple_CLI\Simple_CLI.sln',
  'DAG_Login_CLI\DAG_Login_CLI.sln',
  'LIR_Login_CLI\LIR_Login_CLI.sln',
  '2CSClientWin_sample_Core\2CSClientWin_sample.sln',
  '2CSClientWPF_sample_Core\2CSClientWPF_sample.sln'
)

foreach ($sln in $net48) {
    $full = Join-Path $repo $sln
    if (-not (Test-Path $full)) { Write-Output "MISSING $sln"; continue }
    & $nuget restore $full -Verbosity quiet 2>&1 | Out-Null
    $out = & $msb $full /p:Configuration=Debug /nologo /v:q /clp:ErrorsOnly 2>&1
    $code = $LASTEXITCODE
    $errs = @($out | Select-String -Pattern 'error ' -SimpleMatch)
    if ($code -eq 0) { Write-Output "OK    $sln" }
    else { Write-Output ("FAIL  $sln (err:$($errs.Count)) :: " + (($errs | Select-Object -First 2) -join ' | ')) }
}
foreach ($sln in $core) {
    $full = Join-Path $repo $sln
    if (-not (Test-Path $full)) { Write-Output "MISSING $sln"; continue }
    $out = & $dotnet build $full -c Debug -v q --nologo 2>&1
    $code = $LASTEXITCODE
    $errs = @($out | Select-String -Pattern ': error ' -SimpleMatch)
    if ($code -eq 0) { Write-Output "OK    $sln" }
    else { Write-Output ("FAIL  $sln (err:$($errs.Count)) :: " + (($errs | Select-Object -First 2) -join ' | ')) }
}
