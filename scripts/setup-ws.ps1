# Finish setup of the WS 3-tier tree under repo\WS_sample\ (already copied):
#  - repoint OpenTouryo.* / MySql / Oracle HintPaths to vendored Build_net48
#  - convert WSServer_sample / WSIFType_sample DLL references to ProjectReference
#  - rewrite C:\root\files\resource\ config paths to %OT_RESOURCE_ROOT%
#  - disable ClickOnce manifest signing on WSClientWinCone (MSB3482 avoidance)
# ASCII-only comments (WinPS 5.1 encoding).
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$wsRoot = Join-Path $repo 'WS_sample'
$vendor = Join-Path $repo 'OpenTouryoAssemblies\Build_net48'
$rxDll = '<HintPath>[^<]*\\((?:OpenTouryo\.[A-Za-z0-9.]+|MySql\.Data|Oracle\.ManagedDataAccess|Newtonsoft\.Json)\.(?:dll|xml|pdb))</HintPath>'

function Convert-WSRef([string]$text, [string]$name) {
    # <Reference Include="NAME"> ... <HintPath>..\..\Build\NAME.dll</HintPath> ... </Reference>
    $pat = '<Reference Include="' + [regex]::Escape($name) + '">\s*<HintPath>[^<]*</HintPath>\s*</Reference>'
    $rep = '<ProjectReference Include="..\..\' + $name + '\' + $name + '.csproj"><Name>' + $name + '</Name></ProjectReference>'
    return [regex]::Replace($text, $pat, $rep)
}

$csprojs = Get-ChildItem -Path $wsRoot -Recurse -Filter *.csproj
foreach ($p in $csprojs) {
    $projDir = Split-Path -Parent $p.FullName
    Push-Location $projDir; try { $rel = (Resolve-Path -Relative $vendor) } finally { Pop-Location }
    $rel = $rel -replace '^\.\\',''
    $t = [IO.File]::ReadAllText($p.FullName)
    $orig = $t
    # 1. OpenTouryo/MySql/Oracle -> vendor (relative)
    $t = [regex]::Replace($t, $rxDll, { param($m) "<HintPath>$rel\" + $m.Groups[1].Value + "</HintPath>" })
    # 2. WS DLL refs -> ProjectReference (only where present)
    $t = Convert-WSRef $t 'WSIFType_sample'
    $t = Convert-WSRef $t 'WSServer_sample'
    if ($t -ne $orig) { [IO.File]::WriteAllText($p.FullName, $t); Write-Output ("rewrote refs: " + $p.Name) }
}

# 3. config resource paths
$cfgs = Get-ChildItem -Path $wsRoot -Recurse -Include *.config -File
foreach ($c in $cfgs) {
    $t = [IO.File]::ReadAllText($c.FullName)
    if ($t.Contains('C:\root\files\resource\')) {
        [IO.File]::WriteAllText($c.FullName, $t.Replace('C:\root\files\resource\', '%OT_RESOURCE_ROOT%\'))
        Write-Output ("config paths: " + $c.Directory.Name + "\" + $c.Name)
    }
}

# 4. ClickOnce: disable manifest signing on WinCone
$cone = Join-Path $wsRoot 'WSClient_sample\WSClientWinCone_sample\WSClientWinCone_sample.csproj'
if (Test-Path $cone) {
    $t = [IO.File]::ReadAllText($cone)
    $t = $t.Replace('<SignManifests>true</SignManifests>', '<SignManifests>false</SignManifests>')
    [IO.File]::WriteAllText($cone, $t)
    Write-Output "WinCone SignManifests=false"
}

# report leftover WS_sample\Build DLL refs (should be none)
Write-Output "--- leftover WS_sample\Build refs ---"
$left = @()
foreach ($p in $csprojs) {
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($p.FullName), '<HintPath>([^<]*(?:WS_sample\\Build|Frameworks\\Infrastructure)[^<]*)</HintPath>')) {
        $left += ($p.Name + ' -> ' + $m.Groups[1].Value)
    }
}
if ($left.Count -eq 0) { Write-Output "(none)" } else { $left | Sort-Object -Unique }
