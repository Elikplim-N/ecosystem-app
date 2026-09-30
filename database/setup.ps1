<#
    Ecosystem — local database setup

    Creates the `ecosystem` database, applies schema.sql and seed.sql, then
    runs verify.sql. Safe to re-run: seed.sql is idempotent, and -Recreate
    starts from an empty schema.

    Usage:
        .\setup.ps1
        .\setup.ps1 -Version 13
        .\setup.ps1 -Recreate

    Note: this machine has two clusters and the port does NOT follow the
    version number, so the port is read from postmaster.pid rather than
    guessed.
#>

[CmdletBinding()]
param(
    [int]    $Version = 18,
    [int]    $Port    = 0,          # 0 = auto-detect
    [string] $User    = 'postgres',
    [string] $DbName  = 'ecosystem',
    [switch] $Recreate
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

function Fail($msg) {
    Write-Host "`nFAILED: $msg" -ForegroundColor Red
    exit 1
}

$root = "$env:ProgramFiles\PostgreSQL\$Version"
if (-not (Test-Path $root)) { Fail "PostgreSQL $Version is not installed at $root" }

$psql = Join-Path $root 'bin\psql.exe'
if (-not (Test-Path $psql)) { Fail "psql.exe not found at $psql" }

# --- work out the real port -----------------------------------------

if ($Port -le 0) {
    $pidFile = Join-Path $root 'data\postmaster.pid'
    if (Test-Path $pidFile) {
        $line = (Get-Content $pidFile)[3]
        if ($line -match '^\s*\d+\s*$') { $Port = [int]$line.Trim() }
    }
    if ($Port -le 0) {
        $conf  = Join-Path $root 'data\postgresql.conf'
        $match = Get-Content $conf -ErrorAction SilentlyContinue |
                 Select-String '^\s*port\s*=\s*(\d+)' | Select-Object -First 1
        if ($match) { $Port = [int]$match.Matches[0].Groups[1].Value }
    }
    if ($Port -le 0) { $Port = 5432 }
}

Write-Host "PostgreSQL $Version on port $Port" -ForegroundColor Cyan

# --- password --------------------------------------------------------

$secure = Read-Host "Password for PostgreSQL user '$User' on port $Port" -AsSecureString
$bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

function Invoke-Sql {
    param([string[]] $Arguments, [string] $Label)

    Write-Host "`n=== $Label ===" -ForegroundColor Cyan
    & $psql @Arguments
    if ($LASTEXITCODE -ne 0) { Fail "$Label (psql exit $LASTEXITCODE)" }
}

$common = @('-h', 'localhost', '-p', "$Port", '-U', $User, '--no-password')

# --- connectivity ----------------------------------------------------

Write-Host "`nChecking connection..." -ForegroundColor Cyan
& $psql @common -d 'postgres' -tAc 'select 1;' | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail @"
Cannot connect on port $Port as '$User'.
Either the password is wrong, or it has never been set. If you do not
know it, run .\reset-password.ps1 first.
"@
}

# --- create database -------------------------------------------------

$exists = & $psql @common -d 'postgres' -tAc "select 1 from pg_database where datname = '$DbName';"

if ($Recreate) {
    Write-Host "`nDropping database '$DbName'..." -ForegroundColor Yellow
    Invoke-Sql ($common + @('-d', 'postgres', '-c',
        "drop database if exists `"$DbName`" with (force);")) 'Drop database'
    $exists = $null
}

if (-not $exists) {
    # UTF8 is not optional: users.avatar_icon holds emoji, and an emoji in a
    # SQL_ASCII database is either rejected or stored as mojibake.
    Invoke-Sql ($common + @('-d', 'postgres', '-c',
        "create database `"$DbName`" with encoding 'UTF8';")) 'Create database'
} else {
    Write-Host "Database '$DbName' already exists."
}

# --- apply ------------------------------------------------------------

if ($Recreate) {
    Invoke-Sql ($common + @('-d', $DbName, '-c',
        'drop schema public cascade; create schema public;')) 'Reset schema'
}

# ON_ERROR_STOP=1 makes a bad statement halt instead of silently continuing.
# A half-applied schema is worse than none.
Invoke-Sql ($common + @('-d', $DbName, '-v', 'ON_ERROR_STOP=1', '-f', 'schema.sql')) 'Apply schema.sql'
Invoke-Sql ($common + @('-d', $DbName, '-v', 'ON_ERROR_STOP=1', '-f', 'seed.sql'))   'Apply seed.sql'

# --- verify ----------------------------------------------------------

Invoke-Sql ($common + @('-d', $DbName, '-f', 'verify.sql')) 'Run verify.sql'

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Database '$DbName' is ready on localhost:$Port."
Write-Host "Set DATABASE_URL in your .env to match."
Write-Host "No seed account can log in yet (password_hash is NULL by design)."
