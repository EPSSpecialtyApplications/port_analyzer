
# Port Analyzer 

Port Analyzer automatically documents the network I/O if a system given a network adapter and an interval of time.  

## How to use the script

- You can run the script with the following parameters

```
> ./port_analyzer -CaptureTime <seconds to run> -IPInterface <Network Adapter Name>
```
For example, if I want to run the script on my Wi-Fi traffic for 20 seconds, I would type:

```
> .\port_analyzer.ps1 -CaptureTime 20 -IPInterface "Wi-Fi"
``` 


- If you're unsure of your network adapter names, you can get a list by running the **Get-NetAdapter** cmdlet 

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

The results of the capture session will be recorded in the **output/** directory in a folder named according to the date/time the script was started
```bash
└───output
    ├───2021.07.21.02.34.25
    ├───2021.07.21.03.00.06
    ├───2021.07.21.03.12.27
    ├───2021.07.21.03.34.42
    ├───2021.07.21.03.35.19
    ├───2021.07.21.03.36.00
    ├───2021.07.21.03.36.31
    ...
```

## Sample Output


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