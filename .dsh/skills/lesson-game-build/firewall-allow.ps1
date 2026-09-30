#Requires -Version 5.1
<#
LessonGame: make sure Windows Firewall lets the game accept incoming connections.

Does two things:
  1. creates the exe-agnostic rule "LessonGame UDP 8910-8911" (UDP, all profiles),
     which covers every current and future build;
  2. removes Block rules that Windows creates for a specific exe path when the
     "Allow access?" prompt is cancelled, missed or never shown - Block wins over
     Allow, so such a rule silently kills hosting for that build.

Needs administrator rights. build.ps1 calls this file only when something is
actually wrong, so a UAC prompt appears at most once.

Keep this file pure ASCII: Windows PowerShell 5.1 reads BOM-less files as ANSI,
and Cyrillic inside a .ps1 breaks parsing.
#>
[CmdletBinding()]
param(
	[string]$BuildRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path 'build')
)

$ErrorActionPreference = 'Stop'
$ruleName = 'LessonGame UDP 8910-8911'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Write-Host 'ERROR: administrator rights are required.' -ForegroundColor Red
	Write-Host 'Run it from an elevated PowerShell:'
	Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
	exit 1
}

Write-Host "build folder: $BuildRoot"

# 1. Port rule: exe-agnostic allow, so every build is covered.
$portRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

if ($portRule) {
	Write-Host 'port rule: already present'
} else {
	New-NetFirewallRule -DisplayName $ruleName `
		-Direction Inbound -Protocol UDP -LocalPort 8910,8911 -Action Allow -Profile Any | Out-Null
	Write-Host 'port rule: created (UDP 8910,8911, all profiles)'
}

# 2. Block rules for any exe inside the build folder.
$removed = 0

Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
	Where-Object { $_.Program -like "$BuildRoot\*" } |
	ForEach-Object {
		$rule = $_ | Get-NetFirewallRule
		
		if ($rule.Action -eq 'Block') {
			Remove-NetFirewallRule -Name $rule.Name
			$removed++
			Write-Host ("block rule removed: {0}" -f $_.Program)
		}
	}

Write-Host "block rules removed: $removed"
Write-Host 'done'
