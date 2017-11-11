<#
	Sean K. Anderson / seananderson.us / 2014
	
	Point this script at an IIS log file and it will count the number of requests that exceed a certain response time in milliseconds.
	
	I used a variation of this script as a poor man's application monitoring script to warn the team when certain critical APIs were not 
	responding to requests fast enough.  In this example I have 3875 (milliseconds, or 3.875 seconds) hard coded.  
	
	You could re-work this to accept parameters and run on intervals to send an email or text message if an API/website is running slow.  
	
#>


$total = 0
$long = 0

select-string -path "\\cb-prodweb04\e$\IIS LOGS\W3SVC7\u_ex150204.log" -pattern "/api/CashLoadService.svc" -allmatches –simplematch `
|`
  ForEach-Object {
        
    $parts = $_.Line -split ' '

    $info = @{}
    $info.Date=$parts[0] 
    $info.Time =$parts[1]
    $info.Method = $parts[3]
    $info.Uri = $parts[4]
    $info.UriQ = $parts[5]
    $info.Port = $parts[6]
    $info.ClientIp = $parts[8]
    $info.Status = $parts[10]
    $info.TimeTaken = $parts[13]
    $object = New-Object -TypeName PSObject –Prop $info
    
    $total++
    
	<# Count or report the row if the reponse time exceeded 3.875 seconds #>
	if ([convert]::ToInt32($info.TimeTaken, 10) -gt 3875) 
    {
        Write-Output $object
        $long++
    }

  } 
"Total: $total"
"Long: $long"

