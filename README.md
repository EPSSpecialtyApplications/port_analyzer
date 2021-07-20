
# Port Analyzer 

Port Analyzer summarizes network traffic by port given an IP Interface and an interval of time.  

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

```
############### 80 : http ###############
Port #: 80
Service #: http
Packet Count: 613
Processes:   System  



-----SERVERS-----
x.x.x.x
x.x.x.x

-----CLIENTS-----
x.x.x.x
x.x.x.x
x.x.x.x





```
<!-- ## How it works 

Port Analyzer works by running NetworkTrafficView.exe and summarizing the results output by this program. You can look at the raw results by opening **<IPAddress>\_traffic\_raw.csv** file generated after running the script. The port summary will be contained in a file titled TrafficSummary.txt. 

For each connection given in the NetworkTrafficView results Port Analyzer will try to determine whether the **Source Port** or the **Destination Port** is hosting the service. I refer to this as the **service port**. The logic used to figure this out works like this:

```
if getPortClass(sourcePort) == getPortClass(destPort):
	// case where both src and dest are the same--either system, registered or client
	// Find the port referenced the most and assume that's the host 
	port = findPortReferencedMost(sourcePort, destPort)
	return port 
else if sourcePort == destPort:
	// Communication occuring over same port. 
	return sourcePort
else:
	// source and destination are in different port classes.
	// assume port in lowest range is hosting
	return min(sourcePort, destPort)


``` -->