param (
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$spnAuthority,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azureLocation,
    [string]$stagingStorageAccountName,
    [string]$workspaceName,
    [string]$aksProdClusterName,
    [string]$aksDevClusterName,
    [string]$iotHubHostName,
    [string]$acrNameProd,
    [string]$acrNameDev,
    [string]$githubUser,
    [string]$templateBaseUrl
)

# Inject ARM template parameters as environment variables
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminPassword', $adminPassword, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_ID', $spnClientId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_SECRET', $spnClientSecret, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_TENANT_ID', $spnTenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_AUTHORITY', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksProdClusterName', $aksProdClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksDevClusterName', $aksDevClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('iotHubHostName', $iotHubHostName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('acrNameProd', $acrNameProd, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('acrNameDev', $acrNameDev, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('AgDir', "C:\Ag", [System.EnvironmentVariableTarget]::Machine)

# Download configuration data file
$ConfigurationDataFile = "C:\Temp\HCIBox-Config.psd1"
Invoke-WebRequest ($templateBaseUrl + "artifacts/AgConfig.psd1") -OutFile $ConfigurationDataFile
$AgConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Creating Ag paths
Write-Output "Creating Ag paths and set"
foreach ($path in $AgConfig.AgDirectories) {
    New-Item -ItemType Directory $AgConfig.AgDirectories[$path] -Force
}

Start-Transcript -Path $AgConfig.AgDirectories.AgLogsDir\Bootstrap.log

$ErrorActionPreference = 'Stop'

# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + "artifacts/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
.$PsHome\Profile.ps1

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing tools
Write-Header "Installing Chocolatey Apps"
$chocolateyAppList = 'azure-cli,az.powershell,kubernetes-cli,vcredist140,microsoft-edge,azcopy10,vscode,git,7zip,kubectx,terraform,putty.install,kubernetes-helm,ssms,dotnetcore-3.1-sdk,setdefaultbrowser,zoomit,openssl.light,mqtt-explorer'

try {
    choco config get cacheLocation
}
catch {
    Write-Output "Chocolatey not detected, trying to install now"
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Write-Host "Chocolatey Apps Specified"

$appsToInstall = $chocolateyAppList -split "," | ForEach-Object { "$($_.Trim())" }
foreach ($app in $appsToInstall) {
    Write-Host "Installing $app"
    & choco install $app /y -Force | Write-Output
}

# Download artifacts
Write-Header "Downloading Azure Stack HCI configuration scripts"
#Invoke-WebRequest "https://raw.githubusercontent.com/main/azure_arc/main/img/hcibox_wallpaper.png" -OutFile $Env:HCIBoxDir\wallpaper.png
Invoke-WebRequest ($templateBaseUrl + "artifacts/AgConfig.psd1") -OutFile $AgConfig.AgDirectories.AgDir\HCIBox-Config.psd1
Invoke-WebRequest ($templateBaseUrl + "artifacts/agLogonScript.ps1") -OutFile $AgConfig.AgDirectories.AgDir\agLogonScript.ps1

New-Item -path alias:kubectl -value 'C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe'

# Disable Microsoft Edge sidebar
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name         = 'HubsSidebarEnabled'
$Value        = '00000000'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name         = 'HideFirstRunExperience'
$Value        = '00000001'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Installing Posh-SSH PowerShell Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Posh-SSH -Force

$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $AgConfig.AgDirectories.AgDir\agLogonScript.ps1
Register-ScheduledTask -TaskName "AgLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force


# Installing DHCP service
#Write-Output "Installing DHCP service"
#Install-WindowsFeature -Name "DHCP" -IncludeManagementTools

<#Write-Header "Install Az Powershell module"
Install-Module -Name PowerShellGet -Force
Install-Module -Name Az -Scope AllUsers -Repository PSGallery -Force
#>

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

Stop-Transcript

# Clean up Bootstrap.log
Write-Host "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content $AgConfig.AgDirectories.AgLogsDir\Bootstrap.log | Where-Object { $_ -notmatch "Host Application: powershell.exe" } 
$logSuppress | Set-Content $AgConfig.AgDirectories.AgLogsDir\Bootstrap.log -Force
