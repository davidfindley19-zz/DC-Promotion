<#
    .SYNOPSIS
        Scripted promotion of a new Domain Controller.
    .DESCRIPTION
        A script written to promote a new domain controller on an existing domain. This is not a script to create a 
        new domain. 
    .NOTES
        Author:     David Findley (Excerpts from Uzii3 on Technet.)
        Date:       6/7/2019
        Version:    1.0   
        Change Log: 
                    1.0 (6/7) Initial version of the script. 
#>


[CmdletBinding()]
param(
[Parameter(Mandatory=$false)]
[string]$ComputerName
)

if([string]::IsNullOrEmpty($ComputerName))
    {
        $ComputerName = $env:COMPUTERNAME
    }

Clear-Host
Write-Host "Promote a new Domain Controller" `n -ForegroundColor Blue
Write-Host "Please wait while server information is being collected..." -ForegroundColor DarkGreen `n

$OperatingSystem = Get-CimInstance Win32_OperatingSystem -ComputerName $ComputerName | Select-Object *
$HardwareInformation = Get-CimInstance Win32_ComputerSystem -ComputerName $ComputerName | Select-Object *
$MemoryInformation = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName).TotalPhysicalMemory/1GB)
$ProcessorInformation = Get-CimInstance Win32_Processor -ComputerName $ComputerName | Select-Object *

Write-Host "System Name:"$ComputerName -ForegroundColor White
Write-Host "Manufactured by:"$HardwareInformation.Manufacturer -ForegroundColor White
Write-Host "Hardware Model:"$HardwareInformation.Model -ForegroundColor White
Write-Host "Processor:"$ProcessorInformation.Name -ForegroundColor White
Write-Host "Installed RAM:"$MemoryInformation "GB" -ForegroundColor White
Write-Host "Domain:"$HardwareInformation.Domain -ForegroundColor White
Write-Host "OS Version:"$OperatingSystem.Caption -ForegroundColor White
Write-Host "OS Architecture:"$OperatingSystem.OSArchitecture -ForegroundColor White

Do {
    Write-Host `n"Based on the hardware configuration above, would you like to continue with the DC Promotion?" -ForegroundColor Yellow
    $Input = Read-Host "(Y/N)?" 
}
Until (($Input -eq "Y") -or ($Input -eq "N"))
    If ($Input -eq "Y"){
        Out-Null
    }
    elseif ($Input -eq "N") {
        Write-Host `n"User has selected to cancel the DC Promotion." -ForegroundColor Red
        Start-Sleep -Seconds 2
        Exit
    }
Write-Host `n"Will this server need the DHCP role installed?" -ForegroundColor Yellow
$DHCPResponse = Read-Host "(Y/N)?"

Write-Host `n"Checking ADDS installation state..." -ForegroundColor DarkGreen `n
$InstalledState = (Get-WindowsFeature -Name ad-domain-services).installstate

if ($InstalledState -ne "Installed") {
    Write-Host `n"Installing ADDS roles... Please wait..." -ForegroundColor Blue
    Install-WindowsFeature -Name ad-domain-services
    Start-Sleep -Seconds 3

    $InstalledStateCheck = (Get-WindowsFeature -Name ad-domain-services).installstate

    if ($InstalledStateCheck -ne "Installed") {
        Write-Warning "ADDS role installation failed. Please check the logs or install manually."
    }
    elseif ($InstalledStateCheck -eq "Installed") {
        Write-Host "ADDS role installation completed. Proceeding with DNS check." -ForegroundColor Blue
    }
}
else {
    Write-Host `n"ADDS role is already installed. Proceeding with DNS check." -ForegroundColor Blue
}

Write-Host `n"Checking DNS role installation state..." -ForegroundColor DarkGreen
$InstalledState = (Get-WindowsFeature -Name DNS).installstate

if ($InstalledState -ne "Installed") {
    Write-Host `n"Installing DNS roles... Please wait..." -ForegroundColor Blue
    Install-WindowsFeature -Name DNS
    Start-Sleep -Seconds 3

    $InstalledStateCheck = (Get-WindowsFeature -Name DNS).installstate

    if ($InstalledStateCheck -ne "Installed") {
        Write-Warning "DNS role installation failed. Please check logs or install manually."
    }
    elseif ($InstalledStateCheck -eq "Installed") {
        Write-Host `n"DNS role installation completed. Proceeding with DC Promotion." -ForegroundColor Blue
    }
}
else {
    Write-Host `n"DNS role already installed. Proceeding with DC Promotion." -ForegroundColor Blue
}

if ($DHCPResponse -eq "Y"){
    Write-Host `n"Checking DHCP installation state..." -ForegroundColor DarkGreen
    $InstalledState = (Get-WindowsFeature -Name DHCP).installstate
    if ($InstalledState -ne "Installed"){
        Write-Host `n"Installing DHCP role... Please wait..." -ForegroundColor Blue
        Install-WindowsFeature -Name DHCP 
        Start-Sleep -Seconds 3

        $InstalledStateCheck = (Get-WindowsFeature -Name DHCP).installstate

        if ($InstalledStateCheck -ne "Installed"){
            Write-Warning "DHCP role installation failed. Please check logs or install manually."
        }
        elseif ($InstalledStateCheck -eq "Installed") {
            Write-Host `n"DHCP role installation completed. Proceeding with DC Promotion."
    
    }
    elseif ($InstalledState -eq "Installed") {
        Write-Host "DHCP role already installed. Proceeding with DC Promotion."
        }
    }
}
elseif ($DHCPResponse -eq "N"){
    Out-Null
}

Import-Module ADDSDeployment
Import-Module ActiveDirectory

