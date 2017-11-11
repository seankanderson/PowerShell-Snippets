<# 
    Access Microsoft Exchange / Office365 / Outlook.com folders in PowerShell

    This script utilizes the EWS module from Powershell Gallery.
    
    https://www.powershellgallery.com/profiles/bartekb/

    This example was written by Sean Anderson (http://seananderson.us)

#>


<# You need admin rights on your computer to install this module #> 
Install-Module -Name EWS

<# 
    Reference assemblies directly
    
    You can access any .NET assembly from Powershell.  Custom modules typically wrap spcific .NET assemblies to simplify scripting.
    The module used in this example (EWS) wraps Microsoft.Exchange.WebServices.Data with each cmdlet wrapping a certain class.
    Referencing a class directly is referred to as the "old way" when a particular .NET library already has a powershell module wrapper available.  
    Sometimes you have to use "the old way" if a cmdlet is not feature-complete or you need more control.
   

    $service = [Microsoft.Exchange.WebServices.Data.ExchangeService]::new()
    $service.Url = 'https://outlook.office365.com/EWS/Exchange.asmx'
    $service.Credentials = [System.Net.NetworkCredential]::new('sean.anderson@datavirtue.com', 'mypassword')

#>

<# 
    Connect-EWSService wraps [Microsoft.Exchange.WebServices.Data.ExchangeService]
    Visit https://testconnectivity.microsoft.com/ to get your ServiceUrl from the Autodiscover connectivity test.
    When I tried to use autodiscover it completed successfully but comdlets generated exceptions becasue the 
    service URL that it returned was not fully qualified.
#>
$service = $(Connect-EWSService -Mailbox sean.anderson@datavirtue.com `
                                -ServiceUrl https://outlook.office365.com/EWS/Exchange.asmx `
                                -Credential sean.anderson@datavirtue.com)

#$service.Url 


<#
    List 10 emails from the Inbox with the word "amazon" in the subject.
    Filter uses AQL syntax - https://msdn.microsoft.com/en-us/library/office/dn579420(v=exchg.150).aspx
#>
Get-EwsItem -Name Inbox -Filter subject:Amazon -Limit 10 | Format-Table


<#
    List all calendar entries with the words "interview with" in the subject.
#>
Get-EwsItem -Name Calendar -Filter subject:"interview way" | Format-Table


<#
    Add an appointment.
#>
New-EWSAppointment -Subject Test -Body 'A test meeting' -Location 'Home' -Start (Get-Date).AddDays(1) -Duration 0:30:0

<#
    More examples at https://github.com/bielawb/EWS/tree/master/docs
#>