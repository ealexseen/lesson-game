#Requires -Version 5.1
<#
LessonGame release build (Godot 4.6).
Manual steps and the reasoning behind them: SKILL.md next to this file.

Run (executing .ps1 is disabled by policy on this machine, hence Bypass):
	Set-ExecutionPolicy -Scope Process Bypass -Force
	& .dsh\skills\lesson-game-build\build.ps1 -DryRun     # show the plan only
	& .dsh\skills\lesson-game-build\build.ps1             # build the next version
	& .dsh\skills\lesson-game-build\build.ps1 -Version 16

Keep this file pure ASCII: Windows PowerShell 5.1 reads BOM-less files as ANSI,
so Cyrillic here breaks parsing. Comments and messages are English on purpose.
#>
[CmdletBinding()]
param(
	[int]$Version = 0,          # 0 = next after the highest version in build/
	[switch]$DryRun,            # print what would happen, change nothing
	[switch]$NoRar,             # skip the archive
	[switch]$SkipSmoke,         # skip running the exported game
	[string]$Godot = 'C:\Program Files\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $root

$userDir = Join-Path $root '.dsh_user'          # logs live here: the folder is git-ignored
$presetPath = Join-Path $root 'export_presets.cfg'
$rarBin = 'C:\Program Files\WinRAR\Rar.exe'
$templates = @('version.txt', 'windows_release_x86_64.exe', 'windows_release_x86_64_console.exe')
$expectedExeMb = 99.7
$allowedError = 'root certificate store'        # harmless Windows message, not ours

function Write-Step([string]$text) {
	Write-Host ''
	Write-Host "== $text" -ForegroundColor Cyan
}

Write-Host "LessonGame build - $root"
if ($DryRun) { Write-Host 'dry-run: nothing will be changed' -ForegroundColor Yellow }

# --- 0. Load gate: keeps the import cache fresh before exporting
Write-Step 'load gate'
$gateLog = Join-Path $userDir 'build-gate.log'
if ($DryRun) {
	Write-Host "   [dry-run] & `"$Godot`" --headless --path . --quit"
} else {
	$env:APPDATA = $userDir
	& $Godot --headless --path . --quit *> $gateLog
	if ($LASTEXITCODE -ne 0) { throw "gate failed: exit=$LASTEXITCODE, see $gateLog" }
	Write-Host '   exit=0'
}

# --- 1. Export templates: with APPDATA redirected Godot looks for them inside the project
Write-Step 'export templates'
$templateDst = Join-Path $userDir 'Godot\export_templates\4.6.stable'
$templateSrc = Join-Path $env:USERPROFILE 'AppData\Roaming\Godot\export_templates\4.6.stable'

foreach ($file in $templates) {
	$target = Join-Path $templateDst $file
	
	if (Test-Path $target) {
		Write-Host "   present: $file"
		continue
	}
	if ($DryRun) {
		Write-Host "   [dry-run] would copy: $file"
		continue
	}
	
	New-Item -ItemType Directory -Force $templateDst | Out-Null
	Copy-Item (Join-Path $templateSrc $file) $target -Force
	Write-Host "   copied: $file"
}

# --- 2. Version: next after the highest one in build/
Write-Step 'version'
$existing = @(
	Get-ChildItem (Join-Path $root 'build') -Directory -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -match '^v\.0\.0\.(\d+)$' } |
		ForEach-Object { [int]($_.Name -replace '^v\.0\.0\.', '') }
)
$last = if ($existing.Count) { ($existing | Measure-Object -Maximum).Maximum } else { 0 }

if ($Version -le 0) { $Version = $last + 1 }

$versionName = "v.0.0.$Version"
$buildDir = Join-Path $root "build\$versionName"
$exePath = Join-Path $buildDir 'LessonGame.exe'
Write-Host "   last built: v.0.0.$last, building $versionName"

if ($Version -le $last) { Write-Warning "$versionName is not newer than v.0.0.$last" }

# --- 3. The version number lives in export_presets.cfg
Write-Step 'export_presets.cfg'
$preset = [System.IO.File]::ReadAllText($presetPath)
$patched = $preset -replace 'export_path="build/v\.0\.0\.\d+/LessonGame\.exe"', "export_path=`"build/$versionName/LessonGame.exe`""

if ($patched -eq $preset) {
	Write-Host "   export_path already points at $versionName"
} elseif ($DryRun) {
	Write-Host "   [dry-run] export_path -> build/$versionName/LessonGame.exe"
} else {
	[System.IO.File]::WriteAllText($presetPath, $patched)
	Write-Host "   export_path -> build/$versionName/LessonGame.exe"
}

# --- 4. Export
Write-Step 'export'
$exportLog = Join-Path $userDir 'build-export.log'

if ($DryRun) {
	Write-Host "   [dry-run] & `"$Godot`" --headless --path . --export-release `"Windows Desktop`" `"$exePath`""
} else {
	New-Item -ItemType Directory -Force $buildDir | Out-Null
	$env:APPDATA = $userDir
	& $Godot --headless --path . --export-release 'Windows Desktop' $exePath *> $exportLog
	
	if ($LASTEXITCODE -ne 0) { throw "export failed: exit=$LASTEXITCODE, see $exportLog" }
	Write-Host '   exit=0'
	
	# --- 5. Sizes: a quick signal that the export produced the right thing
	$exe = Get-Item $exePath
	$pck = Get-Item (Join-Path $buildDir 'LessonGame.pck') -ErrorAction SilentlyContinue
	$exeMb = [math]::Round($exe.Length / 1MB, 2)
	Write-Host "   LessonGame.exe: $exeMb MB"
	
	if ($null -eq $pck) { throw "LessonGame.pck is missing - the export produced the wrong thing (usually a missing template)" }
	if ([math]::Abs($exeMb - $expectedExeMb) -gt 5.0) {
		Write-Warning "exe size is not the usual ~$expectedExeMb MB"
	}
	
	$previousExe = Join-Path $root "build\v.0.0.$last\LessonGame.exe"
	if (Test-Path $previousExe) {
		$diff = $exe.Length - (Get-Item $previousExe).Length
		Write-Host "   vs v.0.0.$last, exe diff: $diff bytes"
	}
	
	# --- 6. Archive
	if (-not $NoRar) {
		Write-Step 'archive'
		if (-not (Test-Path $rarBin)) { throw "WinRAR not found: $rarBin" }
		
		Push-Location $buildDir
		try {
			& $rarBin a -ep1 -m5 "$versionName.rar" 'LessonGame.exe' 'LessonGame.console.exe' 'LessonGame.pck' | Out-Null
			if ($LASTEXITCODE -ne 0) { throw "Rar.exe returned exit=$LASTEXITCODE" }
		} finally {
			Pop-Location
		}
		
		$rarFile = Get-Item (Join-Path $buildDir "$versionName.rar")
		Write-Host ("   {0}: {1} MB" -f $rarFile.Name, [math]::Round($rarFile.Length / 1MB, 2))
	}
	
	# --- 7. Smoke run of the exported game
	if (-not $SkipSmoke) {
		Write-Step 'smoke run'
		$runLog = Join-Path $userDir 'build-run.log'
		& (Join-Path $buildDir 'LessonGame.console.exe') --headless --quit *> $runLog
		$runCode = $LASTEXITCODE
		$realErrors = @(
			Select-String -Path $runLog -Pattern 'ERROR|SCRIPT ERROR' -ErrorAction SilentlyContinue |
				Where-Object { $_.Line -notmatch $allowedError }
		)
		
		if ($runCode -ne 0) { throw "exported game did not start: exit=$runCode, see $runLog" }
		if ($realErrors.Count) {
			Write-Warning "errors in the run log, see $runLog"
		} else {
			Write-Host '   exit=0, no errors'
		}
	}
}

# --- Result
Write-Step 'done'
if ($DryRun) {
	Write-Host "   would build $versionName into $buildDir"
} else {
	Get-ChildItem $buildDir | ForEach-Object {
		Write-Host ("   {0} - {1} MB" -f $_.Name, [math]::Round($_.Length / 1MB, 2))
	}
}
