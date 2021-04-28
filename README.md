
# Port Analyzer 

Port Analyzer is a Powershell script that summarizes network traffic on a computer by port given an IP Interface and an interval of time.  

## How to use the script

To start, you'll need to copy the root folder of this repo to the computer you want to run it on. 

Next, choose the interface you want to run the script on. If you're unsure, you can get a list by running the **Get-NetAdapter** cmdlet 

```Powershell
Get-NetAdapter | Select Name, Status
```

```
Name 						  Status 
---- 						  ------  
Bluetooth Network Connection  Disconnected 
Ethernet 2 					  Up 
Wi-Fi 						  Up
```

After you've chosen the name, you can run the script as follows:

```
> ./port_analyzer -CaptureTime <seconds to run> -IPInterface <Network Adapter Name>
```
For example, if I want to run the script for my Wi-Fi traffic for 20 seconds, I would type:

```
> .\port_analyzer.ps1 -CaptureTime 20 -IPInterface "Wi-Fi"
``` 

## Sample Output Summary



## How it works 

