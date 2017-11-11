
<#
	Sean K. Anderson / seananderson.us / 2014
	
	This script is currently set up to run directly on a server hosting Microsoft MSMQ queues.  
	When it runs it gets the queue depth, and if it exceeds the threshhold number of messages waiting in the queue,
	it then measures the response time of an API that services the queues.  The response time of the API and the number 
	of messages waiting in the queues are reported in an email to a support group.
	
	I wrote this to warn the team of impending problems related to message queues getting backlogged.  
	When a backlog would occur we would need to know which queue was backlogged and the reponse time of the API that was 
	being used to service the queue so that we could start out looking in the right direction.  Before implementing
	this script there would usually be an hour or two of chaos before we could identify the root cause--and the 
	queue had already filled the disk.  This got us out in front of the issue while it was still manageable.
	
#>

# Set up command line parameters with defaults
param([int]$messageThreshold=100000, [int]$responseThreshold=2000, [string]$alertEmail="applicationsupport@rushcard.com")

$PSEmailServer = "deliver.contoso.com"

$EtClientId = "ymbq8axy6ngd6e5"
$EtClientSecret = "ZYGJ8VeQzDTGrx"

$fromEmail = "MSMQ_monitor@contoso.com"
$toEmail = "prod_support@contoso.com"  #$alertEmail

$emailSubject = "Internal SMS Alerts from $env:computername"

#load this assembly to access json parser in .net if you are stuck with Powershell 2.0 
[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null

Function parseJson($theJson){

    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.DeserializeObject($theJson)
}

Function getMSMQMessageCount($queueName) {
    $query = "SELECT MessagesinQueue FROM Win32_PerfRawData_MSMQ_MSMQQueue WHERE Name = '$queueName'"
    $wmiObject = Get-WmiObject -Query $query
    $wmiObject.MessagesinQueue
}


Function RestRequest([string]$URL, [string]$Body){

    <# Powershell 3.0+ only #>
    #$res = Invoke-WebRequest -Uri "https://auth.exacttargetapis.com/v1/requestToken" -Method Post -Body $json -ContentType "application/json"
    #$obj = parseJson($res)
    #$obj.accessToken

    <# The PowerShell 2.0 .NET way #>
    # Convert the message body to a byte array
    [byte[]]$BodyBytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Body)
    Write-Host $BodyBytes
    #Write-Host $BodyBytes.Length
    $URI = [System.Uri]$([string]$URL)
    $WebRequest = [System.Net.HttpWebRequest]::CreateHttp([string]$URI)
    $WebRequest.UserAgent = $("{0} (PowerShell {1}; .NET CLR {2}; {3})" -f "PowerShell", $(if($Host.Version){$Host.Version}else{"1.0"}), [Environment]::Version, [Environment]::OSVersion.ToString().Replace("Microsoft Windows ", "Win"));
    $WebRequest.Method = 'POST'
    $WebRequest.ContentType = "application/json"
    $WebRequest.ContentLength = $BodyBytes.Length
    $WebRequest.Timeout = 20000;
    $stream = $WebRequest.GetRequestStream()
    $stream.Write($Body)
    $stream.flush();
    $Stream.Close();
    
    try{

        $reader = New-Object System.IO.Streamreader($WebRequest.GetResponse().GetResponseStream())
        $reader.ReadToEnd()
        $reader.Close()
        $WebRequest = $null
    }
    catch {
        
        Write-Host "Error..."$_.Exception.InnerException -ForegroundColor Yellow
        Send-MailMessage -to $toEmail -from $fromEmail -Subject $emailSubject -body "ERROR getting response from Exact Target Auth API" -BodyAsHtml
        exit;
       
    }
    finally {
        
        if ($reader){
            $reader.Close()
        }
    }
}

$messaging = getMSMQMessageCount("cb-nsb\\private$\\contoso.messaging.application");
$messaging_pri = getMSMQMessageCount("cb-nsb\\private$\\contoso.messaging.application.priority");
$exactTarget = getMSMQMessageCount("cb-nsb\\private$\\contoso.messaging.sms.exacttarget");
$exactTarget_pri = getMSMQMessageCount("cb-nsb\\private$\\contoso.messaging.sms.exacttarget.priority");

If ($messaging -gt $messageThreshold -or $messaging_pri -gt $messageThreshold -or $exactTarget -gt $messageThreshold -or $exactTarget_pri -gt $messageThreshold)
{   
    $json = '{ "clientId" : "'+$EtClientId+'", "clientSecret" : "'+$EtClientSecret+'" }';
    $authtime = Measure-Command {$res = RestRequest 'https://auth.exacttargetapis.com/v1/requestToken' $json}
    try{
    
        $obj = parseJson($res)
        $authtoken = $obj.accessToken

    }catch{
    
        Send-MailMessage -to $toEmail -from $fromEmail -Subject $emailSubject -body "ERROR processing Exact Target Auth API reponse" -BodyAsHtml
        exit;
    }

    $sendtime = Measure-Command {$res = RestRequest 'https://auth.exacttargetapis.com/v1/requestToken' $json}
    try{
    
        $obj = parseJson($res)
        # access a property of some json object parseJson($something)

    }catch{
    
        Send-MailMessage -to $toEmail -from $fromEmail -Subject $emailSubject -body "ERROR processing Exact Target API reponse" -BodyAsHtml
        exit;
    }

    if ($sendtime -gt $responseThreshold){

        $body = "
        <html> 
        <h2>The MSMQ queues on $env:computername appear backlogged</h2> 
        <h3>Exact Target Auth API response time: $authTime milliseconds</h3>
        <h3>Exact Target SMS API response time: $sendtime milliseconds</h3>
    
        <code>
        <ul>
        <li>contoso.Messaging Queue Count                         : $messaging </li>
        <li>contoso.Messaging.Priority Queue Count                : $messaging_pri</li>
        <li>contoso.Messaging.SMS.ExactTarget Queue Count         : $exactTarget</li>
        <li>contoso.Messaging.SMS.ExactTarget.Priority Queue Count: $exactTarget_pri</li>
        </ul>
        </code>
    
        </html>
        " 
        
        Send-MailMessage -to $toEmail -from $fromEmail -Subject $emailSubject -body $body -BodyAsHtml

    }else {
        Write-host "MSMQ Queue(s) are backlogged but the ET API reponse is less than the threshold of $responseThreshold milliseconds."
        Write-Host "Exact Target Auth API response time in milliseconds   : $authtime"
        Write-Host "contoso.Messaging Queue Count                         : $messaging"
        Write-Host "contoso.Messaging.Priority Queue Count                : $messaging_pri"
        Write-Hoat "contoso.Messaging.SMS.ExactTarget Queue Count         : $exactTarget"
        Write-Host "contoso.Messaging.SMS.ExactTarget.Priority Queue Count: $exactTarget__pri"
    }
}else {
    Write-host "No MSMQ Backlog"
} 

<#

    <add key="ExactTarget_Auth_Url" value="https://auth.exacttargetapis.com/v1" xdt:Transform="Replace(value)" xdt:Locator="Match(key)" />
    <add key="ExactTarget_Sms_Url" value="https://www.exacttargetapis.com/sms/v1" xdt:Transform="Replace(value)" xdt:Locator="Match(key)" />
   
    <add key="ExactTarget_ClientId" value="ymbq8ty9gd6e5" xdt:Transform="Replace(value)" xdt:Locator="Match(key)" />
    <add key="ExactTarget_ClientSecret" value="ZYGJ8VQzDTGrx" xdt:Transform="Replace(value)" xdt:Locator="Match(key)" />

#>
