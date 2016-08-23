[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $GitUserName,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $GitUserEmail)

$ErrorActionPreference = 'Stop';

$IsAdmin = (New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    throw "You need to run this script elevated"
}

Write-Progress -Activity "Setting execuction policy"
Set-ExecutionPolicy RemoteSigned

Write-Progress -Activity "Ensuring PS profile exists"
if (-not (Test-Path $PROFILE)) {
    New-Item $PROFILE -Force
}

Write-Progress -Activity "Ensuring Chocolatey is available"
$null = Get-PackageProvider -Name chocolatey -ForceBootstrap

Write-Progress -Activity "Ensuring Chocolatey is trusted"
if (-not ((Get-PackageSource -Name chocolatey).IsTrusted)) {
    Set-PackageSource -Name chocolatey -Trusted -Force
}

@(
    "google-chrome-x64",
    "notepadplusplus.install",
    "winmerge",
    "p4merge",
    "git.install",
    "fiddler4",
    "Jump-Location",
    "gitextensions",
    "git-credential-manager-for-windows",
    "7zip",
    "keepass",
    "foxitreader",
    "visualstudiocode"
) | % {
    Write-Progress -Activity "Installing $_"
    Install-Package -Name $_ -ProviderName chocolatey -Force
}

Write-Progress -Activity "Setting git identity"
Write-Verbose "Setting git user.name to $GitUserName"
git config --global user.name $GitUserName
Write-Verbose "Setting git user.email to $GitUserEmail"
git config --global user.email $GitUserEmail

Write-Progress -Activity "Setting git push behaviour to squelch the 2.0 upgrade message"
if ((& git config push.default) -eq $null) {
    git config --global push.default simple
}

Write-Progress -Activity "Setting git aliases"
git config --global alias.st "status"
git config --global alias.co "checkout"
git config --global alias.df "diff"
git config --global alias.lg "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative"

Write-Progress -Activity "Checking for Git Credential Manager"
if ((& git config credential.helper) -ne "manager") {
    Write-Warning "Git Credential Manager for Windows is missing. Install it manually from https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases"
}

Write-Progress -Activity "Enabling Office smileys"
if (Test-Path HKCU:\Software\Microsoft\Office\16.0) {
    if (-not (Test-Path HKCU:\Software\Microsoft\Office\16.0\Common\Feedback)) {
        New-Item HKCU:\Software\Microsoft\Office\16.0\Common\Feedback -ItemType Directory
    }
    Set-ItemProperty -Path HKCU:\Software\Microsoft\Office\16.0\Common\Feedback -Name Enabled -Value 1
}
else {
    Write-Warning "Couldn't find a compatible install of Office"
}

Write-Progress "Enabling PowerShell on Win+X"
if ((Get-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\).DontUsePowerShellOnWinX -ne 0) {
    Set-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ -Name DontUsePowerShellOnWinX -Value 0
    Get-Process explorer | Stop-Process
}

Write-Progress "Setting Power Option to High performance"
$preferredPowerPlan = "High performance"
$planList = powercfg.exe -l
$planRegEx = "(?<PlanGUID>[A-Fa-f0-9]{8}-(?:[A-Fa-f0-9]{4}\-){3}[A-Fa-f0-9]{12})" + ("(?:\s+\({0}\))" -f $preferredPowerPlan)

if ( ($planList | Out-String) -match $planRegEx ) {
    $result = powercfg -s $matches["PlanGUID"] 2>&1
    
    if ( $LASTEXITCODE -ne 0) {
        $result
    }
}
else {
    Write-Error ("The requested power scheme '{0}' does not exist on this machine" -f $preferredPowerPlan)
}

Write-Progress -Activity "Reloading PS profile"
. $PROFILE

Write-Verbose "Done"
