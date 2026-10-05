[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Host 'Administrator permission is required. Opening the UAC prompt...' -ForegroundColor Yellow
    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $PSCommandPath)
    )
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments
    exit
}

$workDir = Join-Path $env:TEMP 'MicrosoftGameRuntimes'
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$logFile = Join-Path $workDir 'install.log'
Start-Transcript -Path $logFile -Append | Out-Null

function Get-MicrosoftInstaller {
    param(
        [Parameter(Mandatory)] [string]$Url,
        [Parameter(Mandatory)] [string]$Destination
    )

    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    $signature = Get-AuthenticodeSignature -FilePath $Destination
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') {
        throw "Signature validation failed for $Destination. Status: $($signature.Status)"
    }
}

function Install-Exe {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Arguments
    )

    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru
    if ($process.ExitCode -notin @(0, 1641, 3010)) {
        throw "Installer failed with exit code $($process.ExitCode): $Path"
    }
    if ($process.ExitCode -in @(1641, 3010)) {
        $script:RestartRequired = $true
    }
}

$failures = New-Object System.Collections.Generic.List[string]
$script:RestartRequired = $false

$installers = @(
    @{
        Name = 'Microsoft Visual C++ 2015-2022 Redistributable (x64)'
        Url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
        File = 'vc_redist.x64.exe'
        Args = '/install /quiet /norestart'
    },
    @{
        Name = 'Microsoft Visual C++ 2015-2022 Redistributable (x86)'
        Url = 'https://aka.ms/vs/17/release/vc_redist.x86.exe'
        File = 'vc_redist.x86.exe'
        Args = '/install /quiet /norestart'
    },
    @{
        Name = 'Microsoft DirectX End-User Runtime Web Installer'
        Url = 'https://download.microsoft.com/download/1/7/1/1718ccc4-6315-4d8e-9543-8e28a4e18c4c/dxwebsetup.exe'
        File = 'dxwebsetup.exe'
        Args = '/Q'
    }
)

foreach ($installer in $installers) {
    try {
        Write-Step "Installing $($installer.Name)"
        $destination = Join-Path $workDir $installer.File
        Get-MicrosoftInstaller -Url $installer.Url -Destination $destination
        Install-Exe -Path $destination -Arguments $installer.Args
        Write-Host 'Installed successfully.' -ForegroundColor Green
    }
    catch {
        $failures.Add("$($installer.Name): $($_.Exception.Message)")
        Write-Warning $_.Exception.Message
    }
}

$features = @(
    @{ Name = '.NET Framework 3.5'; Feature = 'NetFx3' },
    @{ Name = 'Legacy DirectPlay'; Feature = 'DirectPlay' }
)

foreach ($feature in $features) {
    try {
        Write-Step "Enabling $($feature.Name)"
        $process = Start-Process -FilePath 'dism.exe' -ArgumentList @(
            '/Online', '/Enable-Feature', "/FeatureName:$($feature.Feature)", '/All', '/NoRestart'
        ) -Wait -PassThru
        if ($process.ExitCode -notin @(0, 3010)) {
            throw "DISM failed with exit code $($process.ExitCode)"
        }
        if ($process.ExitCode -eq 3010) {
            $script:RestartRequired = $true
        }
        Write-Host 'Enabled successfully.' -ForegroundColor Green
    }
    catch {
        $failures.Add("$($feature.Name): $($_.Exception.Message)")
        Write-Warning $_.Exception.Message
    }
}

Write-Step 'Finished'
if ($failures.Count -eq 0) {
    Write-Host 'All selected Microsoft game runtimes were installed successfully.' -ForegroundColor Green
}
else {
    Write-Host 'Some items could not be installed:' -ForegroundColor Yellow
    $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
}

if ($script:RestartRequired) {
    Write-Host 'Windows reports that a restart is required.' -ForegroundColor Yellow
}
else {
    Write-Host 'A restart is recommended before launching games.' -ForegroundColor Yellow
}

Write-Host "Log: $logFile"
Stop-Transcript | Out-Null
Read-Host 'Press Enter to close'

