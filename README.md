# <center>  Deploy and Configure  Azure Arc-enabled Servers Using Group Policy </center>

You can onboard your domain-joined Windows machines to Azure Arc-enabled servers at scale by using a Group Policy Object (GPO). This method requires that you have domain administrator privileges and access to group policy editor. You will also need a remote share to host the latest Azure Arc-enabled servers agent, configuration file, and the installation script.

# Prerequisites

### Set up a Remote File Share

Prepare a remote share to host the Azure Connected Machine agent package for windows and the configuration file. You need at least read only access to the distributed location.

### Download the Connected Machine Agent

Download [Windows agent Windows Installer package](https://aka.ms/AzureConnectedMachineAgent) from the Microsoft Download Center and save it to the remote share.

### Define a Configuration File

The Azure Connected Machine agent uses a json configuration file to provide a consistence configuration experience and ease of at scale deployment. Copy the configuration below into a file, edit with your Azure details, and save in the remote share as "ArcConfig.json". 

```
    {
        "tenant-id": "INSERT AZURE TENANTID",
        "subscription-id": "INSERT AZURE SUBSCRIPTION ID",
        "resource-group": "INSERT RESOURCE GROUP NAME",
        "location": "INSERT REGION",
        "service-principal-id":"INSERT SPN ID",
        "service-principal-secret": "INSERT SPN Secret"
    }
```

# Create a Group Policy Object

- Open the Group Policy managment console (GPMC). 
- Navigate to the location in your AD forest that contains the machines which you would like to join to Azure Arc-enabled servers. Then, right-click and select "Create a GPO in this domain, and Link it here." When prompted, assign a descriptive name to this GPO.
- Edit the GPO, navigate to the following location:
  ***Computer Configuration -> Preferences -> Control Panel Settings -> Scheduled Tasks***, right-click in the blank area, ***select New -> Scheduled Task (At least Windows 7)***

### Define the Scheduled Task

Open up the Scheduled Task wizard and configure the tabs as follows:

##### General tab 
    Action: Create
    Security options:
    - When running the task use the following  User account:  "NT AUTHORITY\System"
    - Select Run whether user is logged on or not.
    - Check Run with highest priviledges
    Configure for : Choose Windows Vista or Window 2008.
<p  align = "center">
    <img src = "Pictures\ST-General.jpg">
</p>
  
#### Triggers Tab
    Click on the new button, in the new Trigger.
    Begin the task : select "On a schedule"
    Settings:
         - One time: choose the desired date and time.
         - Make sure to schedule the date and time after after the GPO refresh interval for computers. By default, the computer Group Policy is updated in the background every 90 minutes, with a random offset of 0 to 30 minutes.
    Advanced Settings:
         - Check Enabled 
<p align = "center"> 
  <img src= "Pictures\ST-Trigger.jpg">
</p>

#### Actions Tab
    Click on the new button , in the new Action window.
    - Action: select Start program
    - Settings 
        - Program/script: 
            - enter "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        - Add Arguments(optional): -ExecutionPolicy Bypass -command "& UNC path for the deployment powershell script "
        - The following is a simple example of how to install and onboard the server to Azure Arc, using the configuration file you created in the previous step.
<br>

```
[string] $remotePath = "\\dc-01.contoso.lcl\Software\Arc"
[string] $localPath = "$env:HOMEDRIVE\ArcDeployment"

[string] $RegKey = "HKLM\SOFTWARE\Microsoft\Azure Connected Machine Agent"
[string] $logFile = "installationlog.txt"
[string] $InstallationFolder = "ArcDeployment"
[string] $configFilename = "ArcConfig.json"

if (!(Test-Path $localPath) ) {
    $BitsDirectory = new-item -path C:\ -Name $InstallationFolder -ItemType Directory 
    $logpath = new-item -path $BitsDirectory -Name $logFile -ItemType File
}
else{
    $BitsDirectory = "C:\ArcDeployment"
 }

function Deploy-Agent {
    [bool] $isDeployed = Test-Path $RegKey
    if ($isDeployed) {
        $logMessage = "Azure Arc Serverenabled agent is deployed , exit process"
        $logMessage >> $logpath
        exit
    }
    else { 
        Copy-Item -Path "$remotePath\*" -Destination $BitsDirectory -Recurse -Verbose
        $exitCode = (Start-Process -FilePath msiexec.exe -ArgumentList @("/i", "$BitsDirectory\AzureConnectedMachineAgent.msi" , "/l*v", "$BitsDirectory\$logFile", "/qn") -Wait -Passthru).ExitCode
        
        if($exitCode -eq 0){
            Start-Sleep -Seconds 120
            $x=   & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect --config "$BitsDirectory\$configFilename"
            $msg >> $logpath 
            }
        else {
             $message = (net helpmsg $exitCode)
             $message >> $logpath 
            }
        }
}

Deploy-Agent
```

</br>
        - Start in(optional): C:\
<p align = "center"> 
     <img src= "Pictures\ST-Actions.jpg">
</p>

# Apply the Group Policy Object 
    
On the Group Policy Management Console, you need to right-click on the desired Organizational Unit and select the option to link an existent GPO. Choose the Group Policy Object defined in the Scheduled Task. After 10 or 20 minutes, the Group Policy Object will be replicated to the respective domain controllers. 
    
After you have successfully installed the agent and configure it to connect to Azure Arc-enabled servers, go to the Azure portal to verify that the servers in your Organizational Unit have successfully connected. View your machines in <a href = "https://aka.ms/hybridmachineportal">the Azure portal</a>.
    
