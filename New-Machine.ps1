﻿[CmdletBinding()]
param (
    [# Parameter help description
    [Parameter(Mandatory=$true)]
    [string]
    $gitUserName,
    [Parameter(Mandatory=$true)]
    [string]
    $gitUserEmail)

$ErrorActionPreference = 'Stop';

$IsAdmin = (New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    throw "You need to run this script elevated"
}

Write-Progress -Activity "Setting exeuction policy"
Set-ExecutionPolicy RemoteSigned

Write-Progress -Activity "Ensuring PS profile exists"
if (-not (Test-Path $PROFILE)) {
    New-Item $PROFILE -Force
}

Write-Progress -Activity "Ensuring Chocolatey is available"
$null = Get-PackageProvider -Name chocolatey

Write-Progress -Activity "Ensuring Chocolatey is trusted"
if (-not ((Get-PackageSource -Name chocolatey).IsTrusted)) {
    Set-PackageSource -Name chocolatey -Trusted
}

@(
    "google-chrome-x64",
    "notepadplusplus.install",
    "winmerge",
    "p4merge",
    "git.install",
    "SublimeText3",
    "SublimeText3.PackageControl",
    "fiddler4",
    "Jump-Location",
    "slack",
    "snagit",
    "gitextensions",
    "git-credential-manager-for-windows"
) | % {
    Write-Progress -Activity "Installing $_"
    Install-Package -Name $_ -ProviderName chocolatey
}

Write-Progress -Activity "Setting git identity"
$userName = (Get-WmiObject Win32_Process -Filter "Handle = $Pid").GetRelated("Win32_LogonSession").GetRelated("Win32_UserAccount").FullName
Write-Verbose "Setting git user.name to $gitUserName"
git config --global user.name $gitUserName
# This seems to the be MSA that was first used during Windows setup
$userEmail = (Get-WmiObject -Class Win32_ComputerSystem).PrimaryOwnerName
Write-Verbose "Setting git user.email to $gitUserEmail"
git config --global user.email $gitUserEmail

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

Write-Progress -Activity "Setting PS aliases"
if ((Get-Alias -Name st -ErrorAction SilentlyContinue) -eq $null) {
    Add-Content $PROFILE "`r`n`r`nSet-Alias -Name st -Value (Join-Path `$env:ProgramFiles 'Sublime Text 3\sublime_text.exe')"
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

Write-Progress "Hiding desktop icons"
if ((Get-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\).HideIcons -ne 1) {
    Set-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ -Name HideIcons -Value 1
    Get-Process explorer | Stop-Process
}

Write-Progress "Enabling PowerShell on Win+X"
if ((Get-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\).DontUsePowerShellOnWinX -ne 0) {
    Set-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ -Name DontUsePowerShellOnWinX -Value 0
    Get-Process explorer | Stop-Process
}

Write-Progress -Activity "Reloading PS profile"
. $PROFILE
