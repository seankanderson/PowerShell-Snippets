#########################################################################################################
# UniRush Web Application Staging Deploy Script v0.7.5 (for Powershell 2.0)  by Sean Anderson
#
# This script is designed to follow a website naming convention in order to perform deployment steps.
# The user can supply a site name Ex. -site CONTENT or -site API/CallRouting
# The script will grab the physical path information for API/CallRouting and STAGING-API/CallRouting
# and complete the deploy from the build path to the current staging path. 
# If the paths are the same the script will exit, if the site's virtual directory does not match 
# the naming convention the script will exit.
#
# Any errors will stop the script where the error ocurred. Designed for use on the web server.
#########################################################################################################

<#
    --- CHANGE LOG ---
    2014-12-07 - Sean Anderson  
        - Removed VDIR name matching/verification step--the vdir listing was not returning values sometimes and the user needs to verify configuration anyway
        - Added WebAdmin module import
    2014-12-08 - Sean Anderson
        - Added sleep after app pool recycle
    2014-12-08 - Sean Anderson
        - injected site name into the stage.log file name (replacing '/' with '-' in case the site name is a "subsite")
        - added LogCopy parameter to copy the stage.log file to an alternate location
#>


<#
    Useage: staging-deploy.ps1 -site apply -build \\ba-buildbox\f$\staging\build_folder -confirm {yes, no} - testUrl https://staging-www.contoso.com
#>

# Set up command line parameters with defaults
param([string]$Build="\\ba-buildbox\f$\staging", [string]$Site="TEST", [string]$TestUrl = "", [string]$Confirm = "YES", [string]$LogCopy="S:\Documentation\Deployment")

Import-Module WebAdministration

  
# Tell PowerShell that all errors cause termination of script
$ErrorActionPreference = "Stop"

cls  #Clear the screen to keep the UI clean

# function to return a date formatted such that it can be used as a file name
Function GetFileFormattedDate
{
    $d = Get-Date -Format o | foreach {$_ -replace ":", "."}
    return $d
}

######################################
# Gather information about the sites #
######################################

# Obtain path for production site 

$CurrentProdPath    = (Get-Item IIS:\sites\$Site).PhysicalPath
Write-Host 'Production Physical Path (current):' $Site '-->' $CurrentProdPath "`n" -ForegroundColor Cyan

# Obtain path for staging site 
$CurrentStagePath   = (Get-Item "IIS:\sites\STAGING-$Site").PhysicalPath
Write-Host 'Staging Physical Path (current):' "STAGING-$Site -->" $CurrentStagePath "`n" -ForegroundColor Cyan

Write-Host 'Deploying From:' -ForegroundColor Yellow
#List the contents of the build folder so the user can see the files that are being deployed
Get-ChildItem $Build -Force
Write-Host "`n"

# Show the user where we are deploying TO and FROM
Write-Host "Deploying To Site: STAGING-$Site   Physical Path: $CurrentStagePath   From: $Build" "`n" -ForegroundColor Yellow

##################
# Sanity checks  #
##################

# if production and staging paths are the same kill the script
if ($CurrentStagePath.toUpper() -eq $CurrentProdPath)
{
    Write-Host "The production and staging sites both have the same physical path: "$CurrentProdPath -ForegroundColor Red
    Write-Host "-- Deploy Cancelled! -- " "`n" -ForegroundColor Red
    exit
}

Write-Host "`n"


# Make the user confirm that they want to deploy, improper response will cause the script to cancel

if (-Not $Confirm.ToUpper().Equals("NO"))
{
    $confirmation = Read-Host "Type DEPLOY to continue"

    if ($confirmation.toUpper() -ne "DEPLOY")
    {
        Write-Host "-- Deploy Cancelled -- " "`n" -ForegroundColor Red
        exit
    }
}

##################################################
# Create the log file and perform deploy actions #
##################################################

# Clear the staging folder to ensure a clean deploy
Write-Host "Clearing the STAGING folder: "$CurrentStagePath "`n" -ForegroundColor Cyan
Remove-Item -Path $CurrentStagePath'\*' -Recurse -Force #Delete Everything from the staging folder
 
$LogFile = "$CurrentStagePath\$Site-STAGING-DEPLOY $(GetFileFormattedDate).stage.log"
$LogFile = $LogFile.Replace("/", "-")


New-Item $LogFile -type file -force | Out-Null

Add-content $LogFile "######## Staging Deploy Log File ########"  
Add-Content $Logfile "Current Prod Path: $CurrentProdPath"
Add-Content $LogFile "Current Staging Path: $CurrentStagePath"
Add-Content $LogFile "STAGING-$Site", "Start Datetime:$(Get-Date -Format o)", "Deploy FROM:$Build", "Deploy TO:$CurrentStagePath"

Add-Content $LogFile "`n", "Copying build files to $CurrentStagePath"
Write-Host "Copying build files to "$CurrentStagePath "..." -ForegroundColor Cyan

# Copy files from the build folder to the staging physical path 
Copy-Item -Path $Build'\*' $CurrentStagePath'\' -Recurse #Copy the build files to the staging folder
# Create STAGING marker file
New-Item $CurrentStagePath'\'zz_STAGING.txt -type file -force -value "From: $Build" | Out-Null

# TODO: Log deployed files  
Get-ChildItem $CurrentStagePath -Force

Write-host "Deploy Complete!" -ForegroundColor Green

# Document site configuration in the log file 
Add-Content $LogFile $(& c:\windows\system32\inetsrv\appcmd list sites)
Add-Content $LogFile $(Get-Date -Format o)
Add-Content $LogFile "Deploy Complete!"

#################################
# Recycle AppPool and test site # 
#################################

# Recycle the staging app pool
$AppPool = Get-Item "IIS:\Sites\STAGING-$Site" | Select-Object applicationPool 
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
        Write-Host "HTTP Status: 200 OK" -ForegroundColor Green    
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
        Write-Host "HTTP Status: $HTTP_Status" -ForegroundColor Red
    }
    
    Add-Content $LogFile "$TestUrl STATUS: $HTTP_Status"

    # Clean up the http request by closing it
    $HTTP_Response.Close()

}else
{
    Write-Host "Could not discover test URL." -ForegroundColor Red
}

Copy-Item -Path $LogFile -Destination $LogCopy\ #Copy the stage.log folder to an alternate location 




 