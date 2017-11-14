


#$secureCert = [System.Convert]::ToBase64String($rawCertificateData)
#$certString = ([System.Convert]::ToBase64String((Get-Content 'c:\windows\system32\cert.pfx' -Encoding Byte)))
#$secureCert = ConvertTo-SecureString -String $certString -Force -AsPlainText
#([System.Text.Encoding]::UTF.GetBytes($certString))



$password = ConvertTo-SecureString -String "Strong1!" -Force -AsPlainText 


$cert1 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2('c:\windows\system32\cert.pfx', $password)

$cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2('c:\windows\system32\az_cert.pfx', $password)

$cert1
$cert2

[System.Convert]::ToBase64String($cert1.RawData)
[System.Convert]::ToBase64String($cert2.RawData)



