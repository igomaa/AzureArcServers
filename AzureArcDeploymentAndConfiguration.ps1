# variables
$KeytoCheck = "HKLM\SOFTWARE\Microsoft\Azure Connected Machine Agent"
$LocalPath = "c:\temp"
$FileName = "\\DC-01.contoso.lcl\Software\AzureConnectedMachineAgent.msi"
$OutFile = "$FileName"
$LogFile = "$LocalPath\installationlog.txt"
$ScriptLog = "$LocalPath\scriptlog.txt"
$ConfigurationFilePath = "\\DC-01.contoso.lcl\Software\ArcConfig.json"

################################################################

# Check if folder exists, if not, create it
 if (!(Test-Path $LocalPath)){
 
 New-Item $LocalPath -type Directory | Out-Null

 }

 # start logging
Start-Transcript -Path $ScriptLog
 
 # Check if the agent has been deployed and configured previously
 # We do this by checking for the registry key and value

 $keyexists = Test-Path $KeytoCheck
if ($keyexists -eq $True){
Write-Output "Installation skipped, it is possible that the Azure Arc for Servers agent is already installed"
}
else
{
Write-Output "Installation can proceed"

# Install the package
$exitCode = (Start-Process -FilePath msiexec.exe -ArgumentList @("/i", $FileName ,"/l*v", "installationlog.txt", "/qn") -Wait -Passthru).ExitCode
if($exitCode -ne 0) {
    $message=(net helpmsg $exitCode)
    throw "Installation failed: $message See installationlog.txt for additional details."
}
Start-Sleep -Seconds 60
# Run connect command
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect --config $ConfigurationFilePath


}

  Stop-Transcript