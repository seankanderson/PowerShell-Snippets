$uri = "https://api-4.contoso.com/api/account"
$username = 'username'
$password = 'password'

$xml = [xml]@"
<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
    <Body>
        <getAccount xmlns="http://api.contoso.com/account/type">
            <accountId xmlns="http://api.contoso.com/account">140377215</accountId>
        </getAccount>
    </Body>
</Envelope>
"@

$header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password))}

While ($true)
{
    $m = Measure-Command {$data = Invoke-WebRequest -Uri $uri -Headers $header -Method Post -Body $xml -ContentType "application/xml"}
    Write-host $m.Milliseconds "Milliseconds"
}

