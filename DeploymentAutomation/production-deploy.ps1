#########################################################################################################
# UniRush Web Application Staging Promotion Script v0.7 (for Powershell 2.0) by Sean Anderson
#
# This script is designed to follow a website naming convention in order to perform deployment steps.
# The user can supply a site name Ex. production-deploy -productionsite API/CallRouting
# The script will get the physical path information for API/CallRouting and STAGING-API/CallRouting
# and swap the two physical paths--placing the appropriate marker file in both locations to denote 
# deployment status. 
# If the paths are the same the script will exit, if the site's virtual directory does not match 
# the naming convention the script will exit.
#
# Any errors will stop the script where the error ocurred.  Designed for use on the web server.
# The script will promote staging to prod so it can also be used for rollback.
#########################################################################################################

<#
    --- CHANGE LOG ---
    2014-12-07 - Sean Anderson  
        - Removed VDIR name matching/verification step--the vdir listing was not returning values sometimes and the user needs to verify configuration anyway
        - Added WebAdmin module import
    2014-12-08 - Sean Anderson
        - Added sleep after app pool recycle
#>

<#
    Useage: production-deploy.ps1 -productionsite api/CallRouting -confirm {yes, no} -TestUrl http://www.rushcard.com
#>

# Set up command line parameters with defaults
param
(      
    [Parameter(Mandatory = $true)]
    [string]$Site,
    [Parameter(Mandatory = $false)]
    [string]$Confirm = "YES",
    [Parameter(Mandatory = $false)]
    [string]$TestUrl = ""
)

Import-Module WebAdministration


# Tell PowerShell that all errors cause termination of script
$ErrorActionPreference = "Stop"

$LogVar = "-- Deploying $Site from staging -- `r`n"


cls  #Clear the screen to keep the UI clean

######################################
# Gather information about the sites #
######################################

# List current site configurations
Write-Host "Current Production Site Configuration:" -ForegroundColor Cyan
($prod = Get-Item IIS:\sites\$Site) | Out-Host 
$prod = $prod.physicalpath 

$LogVar += "Prod Physical Path: $prod `r`n"

Write-Host "Current Staging Site Configuration:" -ForegroundColor Cyan
($staging = Get-Item IIS:\sites\STAGING-$Site) | Out-Host 
$staging = $staging.physicalpath

$LogVar += "Staging Physical Path: $staging `r`n"

Write-Host "`n"

##################
# Sanity checks  #
##################

if ($prod.equals($staging))
{
    Write-Host "The production and staging sites both have the same physical path." -ForegroundColor Red
    Write-Host "-- Deploy Cancelled! -- " "`n" -ForegroundColor Red
    exit
}


# Make the user confirm that they want to deploy, improper response will cause the script to cancel
if (-Not $Confirm.ToUpper().Equals("NO")) # Bypass confirmation at command line -confirm no
{
    Write-Host "The following action will reconfigure the production website!" -BackgroundColor Red -ForegroundColor White
    $confirmation = Read-Host "Type SWAP to swap the physical paths"

    if ($confirmation.toUpper() -ne "SWAP")
    {
        Write-Host "-- Deploy Cancelled -- " "`n" -ForegroundColor Red
        exit
    }
}

###############################
# Swap paths and log actions  #
###############################

$LogVar += "User $env:USERNAME confirmed deploy `r`n"

Set-ItemProperty -path IIS:\sites\STAGING-$Site -Name physicalpath -Value $prod | Out-Null
$LogVar += "Set STAGING path to: $prod `r`n"

Set-ItemProperty -path IIS:\sites\$Site -Name physicalpath -Value $staging | Out-Null
$LogVar += "Set PRODUCTION path to: $staging `r`n"

<# 
    Create marker files in the new staging and prod paths
    These marker files will be populated with logging info    
#>
if (Test-Path $prod'\'zz_PRODUCTION.txt) { Remove-Item $prod'\'zz_PRODUCTION.txt -force | Out-Null }
New-Item $prod'\'zz_STAGING.txt -type file -force -value "Was Prod" | Out-Null
if (Test-Path $staging'\'zz_STAGING.txt) { Remove-Item $staging'\'zz_STAGING.txt -force | Out-Null }
New-Item $staging'\'zz_PRODUCTION.txt -type file -force -value $LogVar | Out-Null

Write-Host "`n"

# Show new/updated site configurations
Write-Host "New Production Site Configuration:" -ForegroundColor Green
(Get-Item IIS:\sites\$Site) | Out-Host 

Write-Host "`n"

Write-Host "New Staging Site Configuration:" -ForegroundColor Green
(Get-Item IIS:\sites\STAGING-$Site) | Out-Host 

Write-Host "`n"

###############################################################
# Recycle AppPool, delete staging log file, and test web site # 
###############################################################

Write-Host "Deleting STAGING log file(s) from the new PROD path..." -ForegroundColor Cyan
Remove-Item -Path $staging\*.stage.log -Force 

# Recycle the prod app pool
$AppPool = Get-Item IIS:\Sites\$Site | Select-Object applicationPool 
Write-Host "Recycling AppPool: "$AppPool.applicationPool -ForegroundColor Cyan
Restart-WebAppPool $AppPool.applicationPool
Start-Sleep -s 5

if (-Not $TestUrl.ToLower().StartsWith("http"))
{
    $TestUrl = (Get-WebUrl IIS:\Sites\$Site).ResponseUri.AbsoluteUri
}

if ($TestUrl -match "http")
{

    Write-Host "Testing website: "$TestUrl -ForegroundColor Gray
    
    $HTTP_Request = [System.Net.WebRequest]::Create($TestUrl)

    $HTTP_Response = $HTTP_Request.GetResponse()

    $HTTP_Status = [int]$HTTP_Response.StatusCode

    If ($HTTP_Status -eq 200) { 
        Write-Host "HTTP Status: 200 OK" -ForegroundColor Green | Out-File $staging'\'zz_PRODUCTION.txt -InputObject "$_ `r`n" -Append
        Write-Host -ForegroundColor DarkGray 
        '
	                  )" .
                 /    \      (\-./
                /     |    _/ o. \
               |      | .-"      y)-
               |      |/       _/ \
               \     /j   _".\(*) 
                \   ( |    `.''  )         
                 \  _`-     |   /
                   "  `-._  <_ (
                          `-.,),)
        '
    }
    Else {
        Write-Host "HTTP Status: $HTTP_Status" -ForegroundColor Red | Out-File $staging'\'zz_PRODUCTION.txt -InputObject "$_ `r`n" -Append
    }
    
    # Clean up the http request by closing it
    $HTTP_Response.Close()

}else
{
    Write-Host "Could not discover test URL." -ForegroundColor Red
}

#send in email??


