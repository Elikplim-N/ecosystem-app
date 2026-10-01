<#
    Ecosystem — reset the PostgreSQL superuser password

    Needed because PostgreSQL stores only a SCRAM hash: the password cannot
    be read back, only replaced. There is no command that prints it.

    How this works:
      1. Stop the Postgres service.
      2. Back up pg_hba.conf and temporarily allow passwordless local
         connections ('trust').
      3. Start the service and set a new password with ALTER USER.
      4. Restore pg_hba.conf and restart -- in a finally block, so the
         database is never left passwordless even if step 3 throws.

    LOCAL development clusters only. On the team's cloud server, ask an
    administrator instead of running this.

    Usage:
        .\reset-password.ps1
        .\reset-password.ps1 -Version 13
#>

[CmdletBinding()]
param(
    [int]    $Version = 18,
    [int]    $Port    = 0,          # 0 = auto-detect
    [string] $User    = 'postgres'
)

$ErrorActionPreference = 'Stop'

function Fail($msg) {
    Write-Host "`nFAILED: $msg" -ForegroundColor Red
    exit 1
}

$root = "$env:ProgramFiles\PostgreSQL\$Version"
if (-not (Test-Path $root)) { Fail "PostgreSQL $Version is not installed at $root" }

$psql    = Join-Path $root 'bin\psql.exe'
$hba     = Join-Path $root 'data\pg_hba.conf'
$hbaBak  = "$hba.ecosystem-backup"
$service = "postgresql-x64-$Version"

if (-not (Test-Path $psql)) { Fail "psql.exe not found at $psql" }
if (-not (Test-Path $hba))  { Fail "pg_hba.conf not found at $hba" }

# --- work out the real port -----------------------------------------

if ($Port -le 0) {
    $pidFile = Join-Path $root 'data\postmaster.pid'
    if (Test-Path $pidFile) {
        $line = (Get-Content $pidFile)[3]
        if ($line -match '^\s*\d+\s*$') { $Port = [int]$line.Trim() }
    }
    if ($Port -le 0) {
        $match = Get-Content (Join-Path $root 'data\postgresql.conf') `
                 -ErrorAction SilentlyContinue |
                 Select-String '^\s*port\s*=\s*(\d+)' | Select-Object -First 1
        if ($match) { $Port = [int]$match.Matches[0].Groups[1].Value }
    }
    if ($Port -le 0) { $Port = 5432 }
}

# --- get the new password --------------------------------------------

$NewPassword = ''
while (-not $NewPassword) {
    $sec = Read-Host 'New superuser password' -AsSecureString
    $b   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    $NewPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b)

    if ($NewPassword.Length -lt 8) {
        Write-Host 'Too short. Use at least 8 characters.' -ForegroundColor Yellow
        $NewPassword = ''
    } elseif ($NewPassword -match "['\\]") {
        Write-Host "Avoid single quotes and backslashes; they need SQL escaping." -ForegroundColor Yellow
        $NewPassword = ''
    }
}

$serviceObj = Get-Service -Name $service -ErrorAction SilentlyContinue
if (-not $serviceObj) { Fail "Service $service not found" }
if ($serviceObj.Status -ne 'Running') { Fail "Service $service is not running. Start it and re-run." }

Write-Host "`nPostgreSQL $Version, port $Port" -ForegroundColor Cyan
Write-Host "This changes the password for '$User'." -ForegroundColor Yellow
Write-Host 'Anyone using the old password will stop working.' -ForegroundColor Yellow

$confirm = Read-Host 'Type YES to continue'
if ($confirm -ne 'YES') { Write-Host 'Aborted.'; exit 0 }

# --- back up pg_hba.conf ---------------------------------------------

Copy-Item -LiteralPath $hba -Destination $hbaBak -Force
Write-Host "Backed up pg_hba.conf -> $hbaBak"

$restored = $false

try {
    Write-Host "`nStopping $service..." -ForegroundColor Cyan
    Stop-Service -Name $service -Force
    Start-Sleep -Seconds 4

    # Only the 'all all' rules become trust. Replication rules are left
    # untouched so this does not weaken anything else.
    Write-Host 'Temporarily switching to trust auth...' -ForegroundColor Cyan
    (Get-Content -LiteralPath $hba) | ForEach-Object {
        if ($_ -match '^(\s*(local|host)\s+all\s+all\s+)') { "$($matches[1])trust" }
        else { $_ }
    } | Set-Content -LiteralPath $hba -Encoding UTF8

    Start-Service -Name $service
    Start-Sleep -Seconds 5
    Write-Host 'Service started.' -ForegroundColor Green

    Write-Host "`nSetting the new password..." -ForegroundColor Cyan
    & $psql -h localhost -p $Port -U $User -d postgres -w -v ON_ERROR_STOP=1 `
            -c "alter user `"$User`" with password '$NewPassword';"

    if ($LASTEXITCODE -ne 0) { Fail "ALTER USER failed (psql exit $LASTEXITCODE)" }
    Write-Host 'Password set.' -ForegroundColor Green
}
finally {
    # Always put password auth back, even if ALTER USER threw.
    if (Test-Path -LiteralPath $hbaBak) {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Copy-Item -LiteralPath $hbaBak -Destination $hba -Force
        Start-Service -Name $service
        Start-Sleep -Seconds 4
        $restored = $true
        Write-Host "`npg_hba.conf restored -- password auth is back on." -ForegroundColor Green
    }
}

# --- verify -----------------------------------------------------------

if ($restored) {
    $env:PGPASSWORD = $NewPassword
    Write-Host 'Verifying the new password...' -ForegroundColor Cyan
    & $psql -h localhost -p $Port -U $User -d postgres -w -tAc 'select current_user;'
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=== Success ===" -ForegroundColor Green
        Write-Host 'Next:  .\setup.ps1'
    } else {
        Write-Host "`nStill failing. Check $hbaBak against $hba." -ForegroundColor Red
    }
}
