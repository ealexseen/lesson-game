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
	[switch]$SkipFirewall,      # skip the firewall check (port rule + block rules)
	[string]$Godot = 'C:\Program Files\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $root

$skillDir = $PSScriptRoot                       # firewall-allow.ps1 lives next to this file
$userDir = Join-Path $root '.dsh_user'          # logs live here: the folder is git-ignored
$presetPath = Join-Path $root 'export_presets.cfg'
$rarBin = 'C:\Program Files\WinRAR\Rar.exe'
$templates = @('version.txt', 'windows_release_x86_64.exe', 'windows_release_x86_64_console.exe')
$expectedExeMb = 99.7
$allowedError = 'root certificate store'        # harmless Windows message, not ours
$portRuleName = 'LessonGame UDP 8910-8911'

function Write-Step([string]$text) {
	Write-Host ''
	Write-Host "== $text" -ForegroundColor Cyan
}

## Runs a native command and returns its exit code.
## Needed because PowerShell 5.1 turns native stderr into a terminating error while
## $ErrorActionPreference is 'Stop'. Godot always writes one harmless line to stderr
## ("Failed to read the root certificate store"), which killed the script at the load
## gate before this helper existed. The exit code stays the source of truth.
## $LogFile collects stdout and stderr of the command, as the old inline redirection did.
function Invoke-Native {
	param([string]$File, [string[]]$Arguments, [string]$LogFile)
	
	$previous = $ErrorActionPreference
	$ErrorActionPreference = 'Continue'
	try {
		if ($LogFile) {
			& $File @Arguments *> $LogFile
		} else {
			# Discard stdout and stderr: otherwise the command's own output merges into
			# this function's return value and the exit code comes back as text.
			& $File @Arguments 2>&1 | Out-Null
		}
		$code = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $previous
	}
	return $code
}

function Get-FirewallRuleStore {
	$key = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules'
	return @((Get-ItemProperty $key -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' })
}

function Test-Admin {
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	return (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

## What is wrong with the firewall for this project. Reads the rule store from the
## registry, so it works without administrator rights.
function Get-FirewallState([string]$projectRoot) {
	$buildRoot = Join-Path $projectRoot 'build'
	$rules = Get-FirewallRuleStore
	$portRules = @($rules | Where-Object { $_.Value -match 'Action=Allow' -and $_.Value -match 'Protocol=17' -and $_.Value -match 'LPort=8910' })
	$programRules = @($rules | Where-Object { $_.Value -match [regex]::Escape($buildRoot) -and $_.Value -match 'Action=Allow' })
	$blockRules = @($rules | Where-Object { $_.Value -match [regex]::Escape($buildRoot) -and $_.Value -match 'Action=Block' })
	
	$reasons = @()
	if ($blockRules.Count) { $reasons += "block rules in the build folder: $($blockRules.Count)" }
	# A per-program allow only covers the build it was answered for: the next version
	# has a new exe path, so Windows asks again (or blocks silently).
	if (-not $portRules.Count) { $reasons += 'no port rule covering every build (UDP 8910/8911)' }
	
	return @{
		NeedsFix = [bool]$reasons.Count
		Reason = ($reasons -join '; ')
		ProgramAllows = $programRules.Count
	}
}

## Applies the fix: runs the helper directly when already elevated, otherwise asks
## for elevation once (UAC). Returns $false when the helper could not run.
function Repair-Firewall([string]$projectRoot) {
	$helper = Join-Path $skillDir 'firewall-allow.ps1'
	$buildRoot = Join-Path $projectRoot 'build'
	
	if (-not (Test-Path $helper)) {
		Write-Warning "helper not found: $helper"
		return $false
	}
	
	try {
		if (Test-Admin) {
			& $helper -BuildRoot $buildRoot | Out-Null
			return $true
		}
		
		$process = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList @(
			'-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $helper, '-BuildRoot', $buildRoot
		)
		
		if ($process.ExitCode -ne 0) {
			Write-Warning "helper exit=$($process.ExitCode)"
			return $false
		}
		
		return $true
	} catch {
		Write-Warning "elevation declined or failed: $($_.Exception.Message)"
		return $false
	}
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
	$gateCode = Invoke-Native $Godot @('--headless', '--path', '.', '--quit') -LogFile $gateLog
	if ($gateCode -ne 0) { throw "gate failed: exit=$gateCode, see $gateLog" }
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
	Write-Host '   [dry-run] would copy: tools\server\run_server.bat'
	Write-Host '   [dry-run] would write: server.cfg (template from the game code)'
} else {
	New-Item -ItemType Directory -Force $buildDir | Out-Null
	$env:APPDATA = $userDir
	$exportCode = Invoke-Native $Godot @('--headless', '--path', '.', '--export-release', 'Windows Desktop', $exePath) -LogFile $exportLog
	
	if ($exportCode -ne 0) { throw "export failed: exit=$exportCode, see $exportLog" }
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
	
	# --- 6. Server launcher and config: a double click starts a dedicated server,
	# and server.cfg next to the game shows what can be tuned.
	Write-Step 'server launcher and config'
	$launcher = Join-Path $root 'tools\server\run_server.bat'
	if (-not (Test-Path $launcher)) { throw "server launcher not found: $launcher" }
	Copy-Item $launcher (Join-Path $buildDir 'run_server.bat') -Force
	Write-Host '   run_server.bat'
	
	# Шаблон берём из кода (ServerConfig.TEMPLATE), чтобы не держать вторую копию
	$configPath = Join-Path $buildDir 'server.cfg'
	$configLog = Join-Path $userDir 'build-server-config.log'
	$configCode = Invoke-Native $Godot @('--headless', '--path', '.', '--script', 'res://core/dev_checks/write_server_config.gd', '--', $configPath) -LogFile $configLog
	
	if ($configCode -ne 0) { throw "server.cfg generation failed: exit=$configCode, see $configLog" }
	if (-not (Test-Path $configPath)) { throw "server.cfg was not created in $buildDir" }
	Write-Host '   server.cfg (template from the game code)'
	
	# --- 7. Archive
	if (-not $NoRar) {
		Write-Step 'archive'
		if (-not (Test-Path $rarBin)) { throw "WinRAR not found: $rarBin" }
		
		Push-Location $buildDir
		try {
			$rarCode = Invoke-Native $rarBin @('a', '-ep1', '-m5', "$versionName.rar", 'LessonGame.exe', 'LessonGame.console.exe', 'LessonGame.pck', 'run_server.bat', 'server.cfg')
			if ($rarCode -ne 0) { throw "Rar.exe returned exit=$rarCode" }
		} finally {
			Pop-Location
		}
		
		$rarFile = Get-Item (Join-Path $buildDir "$versionName.rar")
		Write-Host ("   {0}: {1} MB" -f $rarFile.Name, [math]::Round($rarFile.Length / 1MB, 2))
	}
	
	# --- 8. Smoke run of the exported game
	if (-not $SkipSmoke) {
		Write-Step 'smoke run'
		$runLog = Join-Path $userDir 'build-run.log'
		$runCode = Invoke-Native (Join-Path $buildDir 'LessonGame.console.exe') @('--headless', '--quit') -LogFile $runLog
		# Godot writes its harmless cert-store line to stderr, and PowerShell 5.1 turns
		# native stderr into an ErrorRecord whose formatted text lands in the log:
		# source location lines, 'CategoryInfo' and 'FullyQualifiedErrorId'. Those carry
		# the word ERROR and used to be reported as real ones, so they are filtered out.
		# Engine errors are unaffected: in a log they look like 'SCRIPT ERROR: ...'.
		$errorNoise = '^\s*(?:[+-]\s|At\s+line|At\s+[A-Za-z]:|CategoryInfo\s|FullyQualifiedErrorId\s)'
		$realErrors = @(
			Select-String -Path $runLog -Pattern 'ERROR|SCRIPT ERROR' -ErrorAction SilentlyContinue |
				Where-Object { $_.Line -notmatch $allowedError -and $_.Line -notmatch $errorNoise }
		)
		
		if ($runCode -ne 0) { throw "exported game did not start: exit=$runCode, see $runLog" }
		if ($realErrors.Count) {
			Write-Warning "errors in the run log, see $runLog"
		} else {
			Write-Host '   exit=0, no errors'
		}
	}
	
}

# --- 8. Windows Firewall: a blocked build looks exactly like "cannot connect".
# The check only reads the registry, so it runs in dry-run too; the fix does not.
if (-not $SkipFirewall) {
	Write-Step 'firewall'
	$firewall = Get-FirewallState $root
	
	if ($firewall.ProgramAllows) {
		Write-Host "   note: some builds already have their own allow rules: $($firewall.ProgramAllows) (a new version gets a new path and asks again)"
	}
	
	if (-not $firewall.NeedsFix) {
		Write-Host '   ok: port rule present, no block rules for the build folder'
	} elseif ($DryRun) {
		Write-Host "   [dry-run] would fix: $($firewall.Reason)"
	} else {
		Write-Host "   needs fix: $($firewall.Reason)"
		
		if (Repair-Firewall $root) {
			$firewall = Get-FirewallState $root
			
			if ($firewall.NeedsFix) {
				Write-Warning "still not clean: $($firewall.Reason)"
			} else {
				Write-Host '   fixed'
			}
		} else {
			Write-Warning 'could not fix automatically, run this from an elevated PowerShell:'
			Write-Host "   powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillDir\firewall-allow.ps1`""
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
