# Refresh the temporary AWS credentials in .env (they expire after 1 hour).
# Run:  powershell -ExecutionPolicy Bypass -File .\refresh_env.ps1
# Paste the three "export ..." lines, then press Enter on an empty line.
# Other lines in .env (AWS_REGION, MCP_URL, ...) are kept. Secrets are never printed back.

$envPath = Join-Path $PSScriptRoot '.env'
$wanted = 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN'
$pattern = '^\s*(?:export\s+|\$env:|set\s+)?(AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN)\s*=\s*(.+?)\s*$'

Write-Host 'Paste the 3 export lines (access key, secret key, session token), then press Enter on an empty line:'
$vals = @{}
while ($vals.Count -lt 3) {
    $line = Read-Host
    if ([string]::IsNullOrWhiteSpace($line)) { break }
    if ($line -match $pattern) {
        $v = $Matches[2].Trim()
        if ($v.Length -ge 2 -and (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'")))) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        $vals[$Matches[1]] = $v
    }
}

$missing = $wanted | Where-Object { -not $vals.ContainsKey($_) }
if ($missing) {
    Write-Host ('Missing: ' + ($missing -join ', ') + '. .env was NOT changed.') -ForegroundColor Red
    exit 1
}

# Keep every existing line except the three credential keys, then append the new ones.
$keep = @()
if (Test-Path $envPath) {
    $keep = Get-Content $envPath | Where-Object { $_ -and ($_ -notmatch '^\s*(AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN)\s*=') }
}
if (-not ($keep | Where-Object { $_ -match '^AWS_REGION=' })) { $keep += 'AWS_REGION=us-east-1' }

$lines = @()
foreach ($k in $wanted) { $lines += "$k=$($vals[$k])" }
$lines += $keep

# UTF-8 without BOM, LF endings, plain KEY=VALUE.
[System.IO.File]::WriteAllText($envPath, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding $false))
Write-Host ".env updated ($($wanted.Count) credential keys). The backend re-reads it on every Bedrock call." -ForegroundColor Green
