# Generic sample extractor + reference/config rewriter for OpenTouryo setup.
# Copies a sample subtree from the extracted OpenTouryo source into the repo,
# repoints OpenTouryo.* / MySql.Data / Oracle.ManagedDataAccess HintPaths to the
# vendored DLL folder, and rewrites C:\root\files\resource\ config paths to the
# %OT_RESOURCE_ROOT% env-var form. ASCII-only comments (WinPS 5.1 encoding).
#
# Params:
#   -Src    absolute path of the sample folder in C:\otr\OpenTouryo-03-20\...
#   -Dst    absolute path of the target folder under the repo
#   -Vendor absolute path of the vendored DLL dir (Build_net48 or
#           Build_netcore100\net10.0 or Build_netcore100\net10.0-windows7.0)
param(
  [Parameter(Mandatory=$true)][string]$Src,
  [Parameter(Mandatory=$true)][string]$Dst,
  [Parameter(Mandatory=$true)][string]$Vendor
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Src)) { throw "Src not found: $Src" }

# --- 1. copy subtree (robocopy /E; tolerate its success exit codes 0-7) ---
if (Test-Path $Dst) { Remove-Item -Recurse -Force $Dst }
New-Item -ItemType Directory -Force -Path $Dst | Out-Null
robocopy $Src $Dst /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
$global:LASTEXITCODE = 0

$rxDll = '<HintPath>[^<]*\\((?:OpenTouryo\.[A-Za-z0-9.]+|MySql\.Data|Oracle\.ManagedDataAccess)\.(?:dll|xml|pdb))</HintPath>'

# --- 2. rewrite csproj OpenTouryo/MySql/Oracle HintPaths -> vendor (relative) ---
$csprojs = Get-ChildItem -Path $Dst -Recurse -Filter *.csproj
foreach ($p in $csprojs) {
    $projDir = Split-Path -Parent $p.FullName
    Push-Location $projDir
    try { $rel = (Resolve-Path -Relative $Vendor) } finally { Pop-Location }
    $rel = $rel -replace '^\.\\',''                     # drop leading .\
    $t = [IO.File]::ReadAllText($p.FullName)
    $t2 = [Text.RegularExpressions.Regex]::Replace($t, $rxDll, {
        param($m) "<HintPath>$rel\" + $m.Groups[1].Value + "</HintPath>"
    })
    if ($t2 -ne $t) { [IO.File]::WriteAllText($p.FullName, $t2); Write-Output ("refs rewritten: " + $p.Name) }
}

# --- 3. rewrite config resource paths -> %OT_RESOURCE_ROOT% ---
$cfgs = Get-ChildItem -Path $Dst -Recurse -Include *.config,appsettings*.json -File
foreach ($c in $cfgs) {
    $t = [IO.File]::ReadAllText($c.FullName)
    if ($t.Contains('C:\root\files\resource\')) {
        $t = $t.Replace('C:\root\files\resource\', '%OT_RESOURCE_ROOT%\')
        [IO.File]::WriteAllText($c.FullName, $t)
        Write-Output ("config paths rewritten: " + $c.Name)
    }
}

# --- 4. report leftover unresolved external refs (WS_sample\Build, other samples) ---
Write-Output "--- leftover non-vendored HintPaths (excluding NuGet packages\) ---"
$leftover = @()
foreach ($p in $csprojs) {
    $t = [IO.File]::ReadAllText($p.FullName)
    foreach ($m in [Text.RegularExpressions.Regex]::Matches($t, '<HintPath>([^<]+)</HintPath>')) {
        $hp = $m.Groups[1].Value
        if ($hp -notlike '*\packages\*' -and $hp -notlike "$rel*" -and $hp -like '*\*') {
            if ($hp -like '*Frameworks\Infrastructure*' -or $hp -like '*WS_sample*' -or $hp -like '*_sample\*') {
                $leftover += ($p.Name + ' -> ' + $hp)
            }
        }
    }
}
if ($leftover.Count -eq 0) { Write-Output "(none)" } else { $leftover | Sort-Object -Unique }
