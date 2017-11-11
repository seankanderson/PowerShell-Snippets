
<#
	Sean K. Anderson / seananderson.us / 2014
	
	Script deals with safely deploying console application binaries that are run from Window Task Scheduler
	- Checks the state of a scheuled job in Windows Task Scheduler
	- Possibly kills the job if it is running or waits for it to end based on user preference
	- Deploys binaries from one file share to another 
	- Re-enables the scheuled task or ignores state based on user preference
	
	Status is written to the host console.  Pipe output to a file to document deploys for change control.
	
#>


# command line parameters
param
(      
    [Parameter(Mandatory = $false)] #used to manipulate task state (empty means state is ignored)
    [string]$TaskName = "",
    
	[Parameter(Mandatory = $true)] #deploying to
    [string]$TargetFolder,
    
	[Parameter(Mandatory = $true)] #deploying from
    [string]$SourceFolder,
    
	[Parameter(Mandatory = $false)] #kill task immediately
    [switch]$Force,
    
	[Parameter(Mandatory = $false)] #backup location (empty means do not back up)
    [string]$BackupFolder="c:\@@Backups",
    
	[Parameter(Mandatory = $false)] #unattended deploy (I'm feeling lucky)
    [switch]$SkipConfirmation,
    
	[Parameter(Mandatory = $false)] #I know what I'm doing...or I'm just feeling lucky
    [switch]$IgnoreState
    
)

# Tell PowerShell that all errors cause termination of script
$ErrorActionPreference = "Stop"

cls

Add-Type -TypeDefinition @"
   public enum JobState
   {
      UnKnown,
      Disabled,
      Queued,
      Ready,
      Running
   }
"@


<# 
	Feedback animation to show the script is waiting for a scheduled task to end. 
#>
$Global:spinner = '\'
Function WaitAnimation($str="")
{
    $spinner = if ($spinner -eq '\') {'|'} 
    Write-Host -NoNewLine $str $spinner
    Write-Host -NoNewLine "`r"
    Start-Sleep -m 100
    
    $spinner = if ($spinner -eq '|') {'/'}  
    Write-Host -NoNewLine $str $spinner
    Write-Host -NoNewLine "`r"
    Start-Sleep -m 100
    
    $spinner = if ($spinner -eq '/') {'-'}
    Write-Host -NoNewLine $str $spinner
    Write-Host -NoNewLine "`r"
    Start-Sleep -m 100

    $spinner = if ($spinner -eq '-') {'\'}
    Write-Host -NoNewLine $str $spinner
    Write-Host -NoNewLine "`r"
    Start-Sleep -m 100
}


#$BackupFolder = "$BackupFolder\$(Split-Path $TargetFolder -Leaf)"


$BackupFolder = "$BackupFolder\$(Get-Date -UFormat %Y-%m-%d)\$(Split-Path $TargetFolder -Leaf)"
Write-Host "Backup $TargetFolder to $BackupFolder" -Foreground Cyan

# Get TaskScheduler COM object (for some reason there is no native powershell commandlet although you can find reference to them all over the catweb)
($TaskScheduler = New-Object -ComObject Schedule.Service).Connect("localhost")
    
# Get the task from the Scheduler object
$Task = $TaskScheduler.GetFolder('\').GetTask($TaskName)

Write-Host "Deploying from:" -ForegroundColor Cyan

Get-ChildItem -Path $SourceFolder -Force

Write-Host "`n"

Write-Host "Deploying to: $TargetFolder `n" -ForegroundColor Cyan

if($([JobState]$Task.state) -match "Running" -OR $([JobState]$Task.state) -match "Ready"){[console]::ForegroundColor="red"}

Write-Host "$TaskName is $([JobState]$Task.state) `n" 

[console]::ForegroundColor="cyan"

if (-Not $Force -AND -Not $IgnoreState) { Write-Host "Script will wait for the job to end and disable the job before deployment." }
if ($Force -AND -Not $IgnoreState) { Write-Host "Script will KILL and disable the job before deployment." }
if ($IgnoreState) { Write-Host "Script will NOT wait, end, or disable the job before deployment." } 
"`n"
[console]::ForegroundColor="white"

    $confirmation = Read-Host "Type DEPLOY to initiate deployment"

    if ($confirmation.toUpper() -ne "DEPLOY")
    {
        Write-Host "-- Deploy Cancelled -- " "`n" -ForegroundColor Red
        exit
    }


if (-Not $TaskName.Equals("") -OR -Not $IgnoreState)  #Force switch is not used if task name is empty and state is ignored
{
           
    $Task.enabled = $false

    while([JobState]$Task.state -eq [JobState]::Running)
    {
        if ($Force) 
        {
            $Task.stop(0)
            Write-Host "$TaskName was FORCE ended!"
        }
        else 
        {        
            WaitAnimation("Waiting for $TaskName to end...")                      
        }       
    }
}
 
Write-Host "`n$TaskName is $([JobState]$Task.state)" 

Write-Host "Creating backup of $TargetFolder to $BackupFolder `n" -ForegroundColor Cyan 

if ((Test-Path $TargetFolder -pathType Container))
{
    Copy-Item $TargetFolder -Destination $BackupFolder -Force -Container -Recurse | Out-Null
    if (Test-Path $BackupFolder)
    {
        Remove-Item $TargetFolder -Recurse -Force | Out-Null
    }
    
    #Move-Item -Path $TargetFolder -Destination $BackupFolder -Force | Out-Null
}
else
{
    Write-Host "Folder $TargetFolder does not exist `n" -ForegroundColor Magenta  
}

Write-Host "Copying files from $SourceFolder to $TargetFolder... `n"

Copy-Item -Path $SourceFolder -Destination $TargetFolder -Force -Recurse -Container | Out-Null

if (-Not $IgnoreState)
{
    $Task.enabled = $true
}

Write-Host "$TaskName is $([JobState]$Task.state)" -ForegroundColor Green







