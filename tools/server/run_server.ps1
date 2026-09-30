#Requires -Version 5.1
<#
LessonGame server journal in this window.

run_server.bat starts the game attached to this console (so closing the window or
Ctrl+C stops it too) and runs this script in the foreground. The script prints the
server journal line by line: joins, leaves, the game start, the minute summary,
admin commands and failures.

The game writes logs\server-YYYY-MM-DD.log and flushes every line. That file is
appended for the whole day, so the window shows this session only: lines stamped
before this window opened are skipped.

Keep this file pure ASCII: Windows PowerShell 5.1 reads BOM-less files as ANSI,
so Cyrillic here breaks parsing. Russian text arrives from the journal (UTF-8).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
Set-Location $root

$logFolder = Join-Path $root 'logs'
$started = Get-Date
$startedStamp = $started.AddSeconds(-2)

## The server processes started from this folder.
## Get-NetUDPEndpoint does not see the ENet socket, so the process is the signal:
## LessonGame.console.exe is only ever started here by the launcher, while a client
## game is LessonGame.exe and must not keep the window alive.
function Get-OurServers {
	$found = @()
	
	foreach ($process in (Get-Process -Name 'LessonGame.console*' -ErrorAction SilentlyContinue)) {
		try {
			if ($process.Path -like "$root*") {
				$found += $process
			}
		} catch {
			# a process we cannot inspect is not ours to manage
		}
	}
	
	return $found
}

## Started game processes anywhere: printed to explain a busy port.
function Show-OtherGames {
	$others = Get-Process -Name 'LessonGame*','Godot*' -ErrorAction SilentlyContinue
	
	if ($null -eq $others) {
		return
	}
	
	Write-Host ''
	Write-Host 'Other game processes are running, one of them may hold the port:'
	
	foreach ($process in $others) {
		$path = ''
		try { $path = $process.Path } catch { $path = '(path unavailable)' }
		Write-Host "   $($process.ProcessName) pid $($process.Id) - $path"
	}
	
	Write-Host 'Stop the ones you do not need (taskkill /PID <pid> /T /F) and start again.'
}

## Prints new journal lines and returns how many were printed.
## While $SkipOlder is set, lines stamped before this window opened are dropped:
## the journal covers a whole day, the window shows the current session.
function Read-JournalLines {
	param(
		[System.IO.StreamReader]$Reader,
		[bool]$SkipOlder,
		[datetime]$Before
	)
	
	$printed = 0
	
	while ($null -ne ($line = $Reader.ReadLine())) {
		if ($SkipOlder -and $line.Length -ge 9 -and $line[0] -eq '[') {
			$stamp = [datetime]::MinValue
			$parsed = [datetime]::TryParseExact(
				$line.Substring(1, 8), 'HH:mm:ss', $null,
				[System.Globalization.DateTimeStyles]::None, [ref]$stamp
			)
			
			if ($parsed -and $stamp.TimeOfDay -lt $Before.TimeOfDay) {
				continue
			}
		}
		
		# colours are chosen by ASCII markers only: this file must stay ASCII
		if ($line -match 'SERVER: \+') {
			Write-Host $line -ForegroundColor Green
		} elseif ($line -match 'SERVER: -') {
			Write-Host $line -ForegroundColor Red
		} elseif ($line -match 'SERVER STOPPED|ADMIN:|SERVER FAILED') {
			Write-Host $line -ForegroundColor Yellow
		} else {
			Write-Host $line
		}
		
		$printed++
	}
	
	return $printed
}

Write-Host ''
Write-Host 'LessonGame live journal. Ctrl+C in this window stops the server.'
Write-Host ''

$current = ''
$reader = $null
$shown = 0
$sawServer = $false
$quiet = 0
$skipOlder = $true

try {
	while ($true) {
		$alive = (Get-OurServers).Count -gt 0
		
		if ($alive) {
			$sawServer = $true
			$quiet = 0
		}
		
		$newest = $null
		
		if (Test-Path $logFolder) {
			$newest = Get-ChildItem (Join-Path $logFolder 'server-*.log') -ErrorAction SilentlyContinue |
				Sort-Object LastWriteTime | Select-Object -Last 1
		}
		
		# a new day starts a new journal file: switch over without losing the window
		if ($null -ne $newest -and $newest.FullName -ne $current) {
			if ($null -ne $reader) { $reader.Close() }
			$current = $newest.FullName
			# ReadWrite sharing: the server keeps the file open for writing
			$stream = New-Object System.IO.FileStream($current, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
			$reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
			Write-Host "=== $($newest.Name) ==="
		}
		
		$printed = 0
		
		if ($null -ne $reader) {
			$printed = Read-JournalLines $reader $skipOlder $startedStamp
			$skipOlder = $false
		}
		
		if ($printed -gt 0) {
			$shown += $printed
			$quiet = 0
		}
		
		if (-not $alive) {
			# the server we watched has stopped: drain the tail and finish
			if ($sawServer) {
				Start-Sleep -Milliseconds 1000
				
				if ($null -ne $reader) {
					$shown += Read-JournalLines $reader $false $startedStamp
				}
				
				break
			}
			
			# we never saw it: a failed start writes its reason and goes quiet
			$quiet++
			
			if ($quiet -gt 30) {
				break
			}
		}
		
		Start-Sleep -Milliseconds 300
	}
} finally {
	if ($null -ne $reader) { $reader.Close() }
	
	# Ctrl+C: the game runs in the background of this console, so stop it as well,
	# otherwise it keeps the port and later looks like a phantom server
	foreach ($process in (Get-OurServers)) {
		Write-Host ''
		Write-Host "Stopping the server (pid $($process.Id))..."
		& taskkill /PID $process.Id /T /F 2>&1 | Out-Null
	}
}

if ($shown -eq 0) {
	Write-Host ''
	Write-Host "Nothing was written to the journal in $logFolder."
	Show-OtherGames
} elseif (Test-Path $current) {
	# the usual reason a server does not start: somebody already holds the port
	if (@(Get-Content -LiteralPath $current -Encoding UTF8 -ErrorAction SilentlyContinue |
		Select-String -Pattern 'SERVER FAILED').Count -gt 0) {
		Show-OtherGames
	}
}

Write-Host ''
Write-Host "Window done. Journal: $current"
