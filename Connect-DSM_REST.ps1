﻿param (
    [Parameter(Mandatory=$false)]   [string]$Server = "app.deepsecurity.trendmicro.com",
    [Parameter(Mandatory=$false)]   [string]$Port = "443",
    [Parameter(Mandatory=$true)]    [string]$UserName,
    [Parameter(Mandatory=$true)]    [SecureString]$Password,
    [Parameter(Mandatory=$false)]   [string]$tenant
)

Clear-Host
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$DSM_PASS = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$DSM_URI="https://" + $Server + ":" + $port + "/rest/"

$creds = @{
    dsCredentials = @{
        userName = $UserName
        password = $DSM_PASS
        }
}

if (!$tenant) {
    $AUTH_URI = $DSM_URI + "authentication/login/primary"
}
else {
    $AUTH_URI = $DSM_URI + "authentication/login"
    $creds.dsCredentials.Add("tenantName", $tenant)
}

$AuthData = ConvertTo-Json -InputObject $creds
$headers = @{'Content-Type'='application/json'}

try{
    $sID = Invoke-RestMethod -Uri $AUTH_URI -Method Post -Body $AuthData -Headers $headers
    Remove-Variable UserName
    Remove-Variable	DSM_PASS
    Remove-Variable Password
    Write-Host "[INFO]	Connection to $DSM_URI was SUCCESSFUL"
}
catch{
    Write-Host "[ERROR]	Failed to logon to $DSM_URI.	$_"
    Remove-Variable UserName
    Remove-Variable	DSM_PASS
    Remove-Variable Password
    Exit 
}

$sID
$sIDString = "?sID=$sID"


####### Return Scan Configurations
$ScanConfigsURI =  $DSM_URI + "policies/antimalware/scanConfigs" + $sIDString
$ScanConfigs = Invoke-RestMethod -Uri $ScanConfigsURI -Method Get
$ScanConfigs.antiMalwareScanConfigListing.scanConfigs


####### Generate a cookie session to be used for autherization
$cookie = new-object System.Net.Cookie
$cookie.name = "sID"
$cookie.value =  $sID
$cookie.domain = $Server
$WebSession=new-object Microsoft.PowerShell.Commands.WebRequestSession
$WebSession.cookies.add($cookie)


####### Return Global AC Rulesets
$GlobalRulesURI = $DSM_URI + "rulesets/global"
$GlobalRules = Invoke-RestMethod -Uri $GlobalRulesURI -Method Get -WebSession $WebSession
$GlobalRules.DescribeGlobalRulesetResponse.ruleset


####### Return administrators
$AdministratorsURI = $DSM_URI + "administrators"
$Administrators = Invoke-RestMethod -Uri $AdministratorsURI -Method Get -WebSession $WebSession
$Administrators.ListAdministratorsResponse.administrators

