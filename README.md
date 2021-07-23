
# Port Analyzer 

Port Analyzer automatically documents the network I/O of a machine by port for a given network adapter.  

## Usage

You can run the script with the following parameters

```
> .\port_analyzer -CaptureTime <seconds to run> -IPInterface <Network Adapter Name>
```
For example, if I want to run the script on my Wi-Fi traffic for 20 seconds, I would type:

```
> .\port_analyzer.ps1 -CaptureTime 20 -IPInterface "Wi-Fi"
``` 

If you're unsure of your network adapter names, you can get a list by running the **Get-NetAdapter** cmdlet.

```Powershell
Get-NetAdapter | Select Name, Status
```

```
Name 						  Status 
---- 						  ------  
Bluetooth					  Disconnected 
Ethernet 2 					  Up 
Wi-Fi 						  Up
```

The results of the capture session will be recorded in the **output/** directory in a folder named according to the date/time the script was started.
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

## Capture session output sample

The program works by running the NetworkTrafficView.exe and summarizing the results output by this program. You can look at the raw results by opening the "\<IPAddress\>\_traffic_raw.csv" file generated after running the script. The capture session results will be written to a file titled **TrafficSummary.txt**.

For each port in the capture summary, the following fields are listed:
- **Port #:** the port # of the hosted service
- **Service:** The name of the service for that port (if one exists)
- **Packet Count:** Total # of packets sent over the port
- **Processes:** A list of executables using the port. The process may be a client to a service listening on that port or the process may be hosting the service itself
- **Servers:** A list of remote IPs the local machine is a client to on a given port
- **Clients:** A list of IPs that are clients to the local machine on a given port

```
############### 443 : https ###############
Port #: 443
Service #: https
Packet Count: 613
Processes:   System, chrome.exe, EXCEL.EXE, svchost.exe

-----SERVERS-----
x.x.x.x
x.x.x.x
x.x.x.x

-----CLIENTS-----
x.x.x.x
x.x.x.x
x.x.x.x

```

## Aggregating results from multiple capture sessions 

You can use the **createFWX.ps1** script to summarize the results for every capture session contained in the **output/** directory. 

Run the script without any parameters

```
> .\createFWX.ps1
```

The FWX Summary will contain these fields:
- **Hosted Ports:** ports the local machine was listening on during any of the capture sessions 
- **Remote Ports:** ports the local machine was a client to during any of the capture sessions
- **Servers:** complete list of servers the local machine was a client to during the capture sessions
- **Client:** complete list of clients to the local machine during the capture sessions

```
############### FWX SUMMARY ###############
Hosted Ports 80, 443, 1900, 5228, 5353
Remote Ports 53, 80, 443, 1900, 5228, 5353, 33304

SERVERS
x.x.x.x
x.x.x.x
x.x.x.x

CLIENTS
x.x.x.x
x.x.x.x
x.x.x.x


```