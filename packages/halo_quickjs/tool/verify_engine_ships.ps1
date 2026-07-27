# Asserts that a BUILT Windows app actually contains the JS engine.
#
# PowerShell sibling of verify_engine_ships.sh; see that file's header for why
# this check exists at all. Short version: a build going green does not mean the
# engine is in the product, and this project has shipped three builds where it
# was not. On Windows specifically, a release once compiled ZERO lines of
# quickjs because the plugin never entered the build - app/pubspec.lock had no
# mention of halo_quickjs and nothing complained.
#
# The failure is silent at runtime: the app launches, the extension host cannot
# start, it retries forever, and no crash is reported. Scoring, lookups, export
# and sync are simply absent.
#
# Usage:
#   pwsh -File verify_engine_ships.ps1 -Path <bundle-dir-or-dll> [<more> ...]
#
# -Path takes the remaining arguments, so extra artifacts are listed bare.
# Repeating the flag ("-Path a -Path b") is a parameter-binding ERROR, not a
# second value.
#
# ASCII ONLY in this file. A single em dash in a PowerShell block in this repo
# once broke the entire parse, with errors pointing at unrelated lines, because
# CP1252 turned it into a character PowerShell accepts as a string delimiter.

param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]] $Path
)

$ErrorActionPreference = 'Stop'

# On Windows the engine is its own shared library that Dart opens by name
# (halo_quickjs.dart: DynamicLibrary.open('halo_quickjs.dll')), unlike Apple
# where it is linked into the app binary.
$DLL = 'halo_quickjs.dll'
$SYMBOL = 'halo_qjs_new'

# Native commands must be captured with the error preference RELAXED. This repo
# has been burned by it three times and guards it everywhere else:
# build-windows.ps1's Get-DartOutput and publish-download.ps1's aws calls both
# flip to Continue in try/finally, with comments naming PowerShell 5.1. Under
# $ErrorActionPreference='Stop', PS 5.1 promotes a CAPTURED native command's
# stderr to a terminating NativeCommandError - even with 2>$null - so a single
# diagnostic byte from dumpbin would abort this script before it could print
# why the engine is missing. The operator would get a raw NativeCommandError
# instead of the explanation, which is the failure mode this whole script exists
# to prevent. The call site prefers pwsh but falls back to 5.1, so this is live.
function Invoke-Native {
  param([string] $Exe, [string[]] $Arguments)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { return (& $Exe @Arguments 2>&1 | Out-String) }
  finally { $ErrorActionPreference = $prev }
}

function Find-Dumpbin {
  $onPath = Get-Command dumpbin -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }
  # dumpbin ships inside Visual Studio rather than on PATH; vswhere is the
  # supported way to locate the install (same approach as Find-CMake in
  # codemagic.yaml).
  $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
  if (-not (Test-Path $vswhere)) { return $null }
  $vs = (Invoke-Native $vswhere @('-latest', '-products', '*', '-property', 'installationPath')).Trim()
  if (-not $vs) { return $null }
  $found = Get-ChildItem -Path (Join-Path $vs 'VC\Tools\MSVC') -Filter 'dumpbin.exe' -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($found) { return $found.FullName }
  return $null
}

# Fallback when dumpbin is unavailable. A PE stores export names as
# null-terminated ASCII in the export name table, so the symbol appears
# verbatim in the file's bytes. Crude, but it cannot false-PASS here: nothing
# in this codebase contains "halo_qjs_new" as a string constant, so a match
# means the export table names it.
function Test-SymbolBytes {
  param([string] $File, [string] $Symbol)
  $bytes = [System.IO.File]::ReadAllBytes($File)
  $needle = [System.Text.Encoding]::ASCII.GetBytes($Symbol)
  $limit = $bytes.Length - $needle.Length
  for ($i = 0; $i -le $limit; $i++) {
    if ($bytes[$i] -ne $needle[0]) { continue }
    $hit = $true
    for ($j = 1; $j -lt $needle.Length; $j++) {
      if ($bytes[$i + $j] -ne $needle[$j]) { $hit = $false; break }
    }
    if (-not $hit) { continue }
    # The byte AFTER the name must end the identifier. Export names are stored
    # NUL-terminated, so without this "halo_qjs_newer" would satisfy a search
    # for "halo_qjs_new" - the same unanchored-substring false PASS the bash
    # sibling had.
    $next = $i + $needle.Length
    if ($next -ge $bytes.Length) { return $true }
    $c = $bytes[$next]
    $isIdent = ($c -ge 48 -and $c -le 57) -or ($c -ge 65 -and $c -le 90) -or
               ($c -ge 97 -and $c -le 122) -or ($c -eq 95)
    if (-not $isIdent) { return $true }
  }
  return $false
}

$dumpbin = Find-Dumpbin
if ($dumpbin) {
  Write-Host "using dumpbin: $dumpbin"
} else {
  Write-Host "dumpbin not found; falling back to scanning the export name table bytes"
}

$failed = 0
foreach ($p in $Path) {
  if (-not (Test-Path $p)) {
    Write-Host "FATAL: $p does not exist"
    $failed = 1
    continue
  }

  # Accept either the dll itself or the bundle directory holding it.
  $target = $p
  if (Test-Path $p -PathType Container) {
    # NOT -Recurse. Dart calls DynamicLibrary.open('halo_quickjs.dll'), which
    # searches the executable's own directory - a copy buried in a subfolder
    # would satisfy a recursive search while the app still failed to load it,
    # turning this check into a false PASS.
    $hit = Get-ChildItem -Path $p -Filter $DLL -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $hit) {
      Write-Host "FATAL: no $DLL beside the executable in $p"
      Write-Host "       The build produced no engine at all. Dart opens this by"
      Write-Host "       name at startup, so the extension host would never start."
      Write-Host "       Top-level contents:"
      Get-ChildItem -Path $p | Select-Object -First 15 | ForEach-Object { Write-Host "         $($_.Name)" }
      $failed = 1
      continue
    }
    $target = $hit.FullName
  }

  $ok = $false
  $how = ''
  if ($dumpbin) {
    $exports = Invoke-Native $dumpbin @('/EXPORTS', $target)
    # \b on both sides: a plain substring test also accepts a DLL exporting
    # halo_qjs_newer and not halo_qjs_new. Same bug the bash sibling had.
    $ok = $exports -match ('\b' + [regex]::Escape($SYMBOL) + '\b')
    $how = 'dumpbin /EXPORTS'
  } else {
    $ok = Test-SymbolBytes -File $target -Symbol $SYMBOL
    $how = 'byte scan'
  }

  if ($ok) {
    Write-Host ("  OK   {0,-46} exports {1} ({2})" -f (Split-Path $target -Leaf), $SYMBOL, $how)
  } else {
    Write-Host "FATAL: $target does not export $SYMBOL (checked via $how)"
    Write-Host "       The file exists and the build succeeded, but the engine is"
    Write-Host "       not in it. The app would launch, fail to bring up the"
    Write-Host "       extension host, and retry forever with nothing reported."
    if ($dumpbin) {
      Write-Host "       what it does export (first 20 lines):"
      (Invoke-Native $dumpbin @('/EXPORTS', $target)) -split "`r?`n" |
        Select-Object -First 20 | ForEach-Object { Write-Host "         $_" }
    }
    $failed = 1
  }
}

if ($failed -ne 0) { exit 1 }
Write-Host "engine verified in $($Path.Count) artifact(s)"
