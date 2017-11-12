<#
	Sean K. Anderson / seananderson.us / 2016
	
	I wrote this script to help with PCI compliance.  There were a bunch of log files with credit card 
	numbers (PANS) in them that we needed to mask.  This script scans through every file in the path 
	and replaces the middle six digits with X, leaving the first six (well known bank ID number)
	and the last four of the card number.	
	
	You could add functionality to open office documents and scan/report those as well. There are 
	commercial tools that can do this but they cost a lot of money.  
	
#>



param
(      
    [Parameter(Mandatory = $true)]
    [string]$path,
    [Parameter(Mandatory = $false)]
    [string]$bin = "410489|422797"
    
)


$excludeList = @("*.bat", "*.cmd", "*.dll", "*.exe", "*.mdf", ".ini", "*.scr", "*.s*", "*.as*", "*.resx", "*.c*", "*.bmp", "*.jpg", "*.png", "*.ico", "*.pgp" );

$files = Get-ChildItem $path -Exclude $excludeList;
 
 ForEach($file in $files) {
    
    try
    {
        <# Use regular expression to identify credit card numbers #>
		$data = (Get-Content $file ) -replace "($bin)(\d{6})(\d{4})", "`$1xxxxxx`$3";
    }
    catch
    {
        $data = $null;
        Write-Host "Error replacing data in $file, exited without altering file.";
        exit;
    }
    if ($data)
    {
        Set-content -Path $file -Value $data -force;
    }
    $data = $NULL;
 }

