
[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null

Function parseJson($theJson){

    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.DeserializeObject($theJson)
}


Function RestRequest($URL){

    <# POST
    $BodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body);
    $URI = [System.Uri]$([string]$URL);
    $WebRequest = [System.Net.HttpWebRequest]::Create($URI);
    $WebRequest.Method = 'POST';
    $WebRequest.ContentType = 'application/json';
    $WebRequest.GetRequestStream().Write($BodyBytes, 0, $BodyBytes.Length);
    #>
    
    <# GET #>
    $URI = [System.Uri]$([string]$URL);
    $WebRequest = [System.Net.HttpWebRequest]::Create($URI);
    $WebRequest.Method = 'GET';
    $WebRequest.ContentType = 'application/text';
    
    
    $resp = $WebRequest.GetResponse();
    $reqstream = $resp.GetResponseStream()
    $sr = new-object System.IO.StreamReader $reqstream
    $sr.ReadToEnd()
}

$authResponse = RestRequest('http://services.groupkt.com/country/get/iso2code/US')


$obj = parseJson($authResponse);
$obj.RestResponse.result.name
  
