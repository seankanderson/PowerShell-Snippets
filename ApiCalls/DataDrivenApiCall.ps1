
<#
    Script to query SQL Server and make web calls using the data from the query results.  
    This could be re-worked to bulk-load data into SQL Server from an API response.

#>


[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null

Function parseJson($theJson){
    
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.DeserializeObject($theJson)
}


Function RestRequest([string]$URL, [string]$Body, $token=$null){


    <# The PowerShell 2.0 .NET way #>
    [byte[]]$BodyBytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Body)
    $URI = [System.Uri]$([string]$URL)
    $WebRequest = [System.Net.HttpWebRequest]::Create([string]$URI)
    $WebRequest.UserAgent = $("{0} (PowerShell {1}; .NET CLR {2}; {3})" -f "PowerShell", $(if($Host.Version){$Host.Version}else{"1.0"}), [Environment]::Version, [Environment]::OSVersion.ToString().Replace("Microsoft Windows ", "Win"));
    $WebRequest.Method = 'POST'
    $WebRequest.ContentType = "application/json"
    if ($token){
        $WebRequest.Headers["Authorization"] = "Bearer $token";
    }
    $WebRequest.ContentLength = $BodyBytes.Length
    $WebRequest.Timeout = 20000;
    $stream = $WebRequest.GetRequestStream()
    $stream.Write($BodyBytes, 0, $BodyBytes.Length)
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
        
    }
    finally {
        
        if ($reader){
            $reader.Close()
        }
    }
}
   

   $dbServer = "PROD_DB";
   $database = "Adhoc";
   $sqlCommand = "SELECT id FROM Adhoc.dbo.AccountsToOpen ORDER BY id";  

   $connectionString = "Data Source=$dbServer; " +
            "Integrated Security=SSPI; " +
            "Initial Catalog=$database"

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $cmd = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
    $connection.Open()
    
    $reader = $cmd.ExecuteReader()

    $results = @()
    while ($reader.Read())
    {
        
        $AccountId = $reader.getValue(0);
        $json = '{ "accountStatus": 10 "changeReason": 10 }';

        $uri = 'https://api.contoso.com/bank/accounts/' + $AccountId + '/ChangeAccountStatus'

        Write-Host $uri

        
        <#
            For serious use this needs to handle errors from the API call and log responses for each call associated with the data being acted upon.
            I originally used this code during an emergency.  :)
        #>
        RestRequest $uri $json


        #Write-Host $json

    }

    $connection.Close()


