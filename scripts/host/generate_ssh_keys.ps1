param(
    [Parameter(Mandatory=$true)]
    [string]$KeyDir,

    [Parameter(Mandatory=$true)]
    [string]$KeyName,

    # Optional: passphrase; default empty for Vagrant usage
    [string]$Passphrase = ''
)

$ErrorActionPreference = 'Stop'

# Coerce $null to empty string
if ($null -eq $Passphrase) { $Passphrase = [string]::Empty }

# Pin Windows OpenSSH if present, else resolve from PATH
$sshKeyGen = 'C:\Windows\System32\OpenSSH\ssh-keygen.exe'
if (-not [System.IO.File]::Exists($sshKeyGen)) {
    $sshKeyGen = (Get-Command ssh-keygen -ErrorAction Stop).Source
}

# Normalize KeyDir to an absolute path (supports relative like ".vagrant_keys")
if (-not [System.IO.Path]::IsPathRooted($KeyDir)) {
    $KeyDir = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine((Get-Location).Path, $KeyDir))
}

# Ensure dir
[void][System.IO.Directory]::CreateDirectory($KeyDir)

# Paths
$KeyPath = [System.IO.Path]::Combine($KeyDir, $KeyName)
$PubPath = "$KeyPath.pub"

# Idempotency
if ([System.IO.File]::Exists($KeyPath) -and [System.IO.File]::Exists($PubPath)) {
    Write-Host "SSH key already exists at $KeyPath; skipping generation."
    exit 0
}

Write-Host "Using ssh-keygen: $sshKeyGen"
Write-Host "KeyDir: $KeyDir"
Write-Host "KeyName: $KeyName"
Write-Host "KeyPath: $KeyPath"
Write-Host "Requested passphrase length: $($Passphrase.Length)"

if ($Passphrase.Length -eq 0) {
    # Empty passphrase path via CMD with robust quoting
    $inner = ('"{0}" -t ed25519 -a 64 -f "{1}" -C "vagrant@{2}" -N ""' -f $sshKeyGen, $KeyPath, $env:COMPUTERNAME)
    $wrapped = '"' + $inner.Replace('"','""') + '"'
    Write-Host "Generate via cmd.exe (/s /c): $wrapped"

    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/s','/c', $wrapped -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        throw "ssh-keygen failed (generate empty passphrase via cmd.exe) with exit code $($p.ExitCode)"
    }
}
else {
    # Non-empty passphrase path: normal array invocation
    $ArgsList = @(
        '-t','ed25519',
        '-a','64',
        '-f', $KeyPath,
        '-N', $Passphrase,
        '-C', "vagrant@$env:COMPUTERNAME"
    )
    Write-Host "Generate args: $($ArgsList -join ' | ')"
    & $sshKeyGen @ArgsList
    if ($LASTEXITCODE -ne 0) {
        throw "ssh-keygen failed (generate with passphrase) with exit code $LASTEXITCODE"
    }
}

# Best-effort permissions hygiene (explicit ACE for the current user)
try {
    $account = "$env:USERDOMAIN\$env:USERNAME"
    & icacls "$KeyPath" /inheritance:r /grant:r "${account}:(F)" /c | Out-Null
} catch {
    Write-Host "Note: Skipping ACL hardening due to error: $($_.Exception.Message)"
}

Write-Host "SSH key generated: $KeyPath"