
# Script Params 
 param (
    [string]$IPInterface = "Public",
    [string]$NTVConfigTemplate = "config/NTVConfig.cfg",
    [int]$CaptureTime = 60 
 )

Enum Ports {
    SYSTEM = 1
    REGISTERED = 2
    EPHEMERAL = 3
}


function runNTVCapture{
    param($CAPTURE_TIME, $configFile, $outFileName, $InterfaceAlias)
    $interfaceGuid = (Get-NetAdapter | Select InterfaceGuid, Name | Where Name -eq $InterfaceAlias).InterfaceGuid

    if(-not $interfaceGuid){
        Write-Host "Could not find Network Adapter: $IPInterface . Specify the name of the interface you want to listen on with the -IPInterface script parameter. You can get a full list by running the Get-NetAdapter cmdlet" -BackgroundColor Black -ForeGroundColor Red
        exit
    }

    $tmpConfig = "new_config.cfg"

    # Create temporary config file with correct Interface UID
    Get-Content -Path ".\$configFile" | ForEach-Object {
        if($_ -match "(PCapAdapterName=\\Device\\NPF_)(?:.*)"){
            $PCapAdapter = ($Matches[1] + $interfaceGuid)
            Add-Content -Path $tmpConfig -Value $PCapAdapter
        } else {
            Add-Content -Path $tmpConfig -Value $_
        }
    }

    $tmpConfig = Get-Item $tmpConfig
    Write-Host "Running traffic capture for $CAPTURE_TIME seconds..."

    #Start Network Traffic View and wait until the capture is complete 
    Start-Process -FilePath "NTV/NetworkTrafficView.exe" -ArgumentList "/LoadConfig $tmpConfig /captureTime $CAPTURE_TIME /scomma $outFileName" -ErrorAction Stop
    
    # Go to Sleep....
    for ($i = 0; $i -le $CAPTURE_TIME; $i++ )
    {
        $secondsLeft = $CAPTURE_TIME - $i
        $percentComplete = [int]($i/$CAPTURE_TIME * 100)
        Write-Progress -Activity "Reading Traffic..." -Status "$secondsLeft Seconds remaining" -PercentComplete $percentComplete;
        Sleep(1)
    }
    Sleep(1) # Sleep an extra second
    Write-Host "Capture Complete! "

    # Remove temporary config file
    Remove-Item $tmpConfig

    #Import and return the captured data
    $data = Import-Csv $outFileName
    return $data
}


function getPortType{
    <#
        Returns the port type Enum given a port #
    #>
    param($port)
    $SYSTEM_PORT_MAX = 1024
    $REGISTERED_PORT_MAX = 49151 
    $PORT_MAX= 65535

    if($port -le $SYSTEM_PORT_MAX){
        return [Ports]::SYSTEM
    } elseif($port -le $REGISTERED_PORT_MAX){
        return [Ports]::REGISTERED
    } elseif($port -le $MAX_PORT){
        return [Ports]::EPHEMERAL
    } else {
        return $null
    }
}


function isSpecialCase{
    <#
        Checks the port types and returns true for "special" cases that need handled for 
        port analysis
    #>
    param($srcPortType, $destPortType)

    if($srcPortType -eq [Ports]::EPHEMERAL -and $destPortType -eq [Ports]::EPHEMERAL){
        #Case: Two client ports talking 
        return $true
    } elseif($srcPortType -eq [Ports]::REGISTERED -and $destPortType -eq [Ports]::REGISTERED){
        #Case: two registered ports talking 
        return $true
    } elseif($srcPortType -eq [Ports]::SYSTEM -and $destPortType -eq [Ports]::SYSTEM){
        #Case: two system ports talking 
        return $true
    } 
    return $false
}

function getPortReferenceCount{
    <# Counts how many times a port was referenced the capture as both a source & destination port #>
    param($port)

    $count = ($data | Select 'Source Port' | Where 'Source Port' -eq $port | Measure).Count
    $count += ($data | Select 'Destination Port' | Where 'Destination Port' -eq $port | Measure).Count
    return $count
}

function getPortByRefenceCount{
    <#
        For special cases, the service port is determined by counting how many times 
        the port is referenced. The logic 
    #>
    param($src, $dest)
    $srcCount = getPortReferenceCount $src $data
    $destCount = getPortReferenceCount $dest $data
    if($srcCount -gt $destCount){
        return $src
    } elseif($srcCount -lt $destCount){
        return $dest
    } else {
        return $null
    }
}   

function getServicePort {
    param($src, $dest)
    $srcPortType = getPortType $src
    $destPortType = getPortType $dest

    if($src -eq $dest){
        return $src  
    }elseif($srcPortType -eq $destPortType){
        $port = getPortByRefenceCount $src $dest
        return $port
    } 

    return ($src, $dest | Measure -Min).Minimum   
}

function isServicePortLocal{
    param($port, $srcPort, $destPort, $outbound)

    if($outbound){
        if($port -eq $srcPort){
            return $true
        } else {
            return $false
        }

    } else {
        if($port -eq $srcPort){
            return $false
        } else {
            return $true
        }
    }

}

function initializePortSummary {
    param($sp, $packetCount, $description, $proc, $address, $local)
    $processList = New-Object -TypeName "System.Collections.ArrayList"
    $clientList = New-Object -TypeName "System.Collections.ArrayList"
    $serverList = New-Object -TypeName "System.Collections.ArrayList"
    if($local){
        $add = $clientList.Add($address)
    } else {
        $add = $serverList.Add($address)
    }
    
    if($proc.trim()){
        $add = $processList.Add($proc)
    }

    New-Object -TypeName psobject -Property @{
            Port=$sp
            PacketCount=$packetCount
            Description=$description
            Processes=$processList
            ClientIPs=$clientList
            ServerIPs=$serverList
    }
    return
}

function updatePortSummary{
    param($packetCount, $proc, $address, $local, $summary)

    if($local){
        if(-not $summary.ClientIPs.Contains($address)){
            $add = $summary.ClientIPs.Add($address)
        }
    } else {
        if(-not $summary.ServerIPs.Contains($address)){
            $add = $summary.ServerIPs.Add($address)
        }
    }

    if(-not $summary.Processes.Contains($proc) -and $proc.trim().length -gt 0){
        $add = $summary.Processes.Add($proc)
    }
    $summary.PacketCount += $packetCount

    return $summary
}



################# MAIN ####################

$sesh = New-Object -TypeName psobject -Property @{
        StartTime=Get-Date
        EndTime=$null
        portList=$null
        duration=$CaptureTime
}

$server = ((get-netipaddress | Where InterfaceAlias -eq $IPInterface).IPAddress |  Select-String -Pattern "\d{1,3}(\.\d{1,3}){3}" -AllMatches).Matches.Value
$outputDir = $sesh.StartTime.tostring("yyyy.MM.dd.hh.mm.ss")
#$rawOutputFile = ('output/' + $server + "_traffic_raw.csv")

#Create new output directory 
$newdir = New-Item -ItemType directory -Path ("output/{0}" -f $outputDir)



$rawOutputFile = ("output/{0}/{1}_traffic_raw.csv" -f $outputDir, $server)
Write-host "Checking ports on: $server"

$data = runNTVCapture $CaptureTime $NTVConfigTemplate $rawOutputFile $IPInterface

#Record endtime of capture
$sesh.EndTime = Get-Date
$portTable = @{}


ForEach($row in $data){

    $srcPort = [int]$row.'Source Port'
    $destPort = [int]$row.'Destination Port'
    $packetCt = [int]$row.'Packets Count'
    $serviceName = $row.'Service Name'
    $sp = [int](getServicePort $srcPort $destPort)
    $owningProc = $row.'Process Filename'
    $outbound = ($row.'Source Address' -eq $server)
    if($outbound){
        $address = $row.'Destination Address'
    }  else {
        $address = $row.'Source Address'
    }

    $local = isServicePortLocal $sp $srcPort $destPort $outbound

    if($sp){
        if($portTable.ContainsKey($sp)){
            $summary = $portTable[$sp]
            $summary = updatePortSummary $packetCt $owningProc $address $local $summary
        } else {
            $summary = initializePortSummary $sp $packetCt $serviceName $owningProc $address $local
            $portTable.Add($sp, $summary)

        }

    } else {
        Write-host "Cannot determine service port for Source Port: $srcPort | Destination Port $destPort" -BackgroundColor DarkCyan -ForeGroundColor Black
    }

}

$outputFile = ("output/{0}/TrafficSummary.txt" -f $outputDir)
Clear-Content $outputFile -ErrorAction SilentlyContinue
$pt = $portTable.GetEnumerator() | Sort Key
$sesh.portList = $portTable.Keys

Write-Host ("Creating port summary for {0}" -f ($sesh.portList -join ", "))


Add-Content -Path $outputFile -Value "############### SESSION SUMMARY ###############"
Add-Content -Path $outputFile -Value ("Start Time:       {0}" -f $sesh.StartTime)
Add-Content -Path $outputFile -Value ("End Time:         {0}" -f $sesh.EndTime)
Add-Content -Path $outputFile -Value ("Capture Duration: {0}" -f $sesh.duration)
Add-Content -Path $outputFile -Value ("Port List:        {0}`n" -f ($sesh.portList -join ", "))

ForEach($port in $pt){
    $port = $port.Name
    Add-Content -Path $outputFile -Value ("############### " + $portTable[$port].Port + " : " + $portTable[$port].Description + " ###############")
    Add-Content -Path $outputFile -Value ("Port #: " + $portTable[$port].Port)
    Add-Content -Path $outputFile -Value ("Service #: " + $portTable[$port].Description)
    Add-Content -Path $outputFile -Value ("Packet Count: " + $portTable[$port].PacketCount)
    Add-Content -Path $outputFile -Value ("Processes: {0}`n" -f ($portTable[$port].Processes -join ", "))
    Add-Content -Path $outputFile -Value ("-----SERVERS-----")
    Add-Content -Path $outputFile -Value $portTable[$port].ServerIPs
    Add-Content -Path $outputFile -Value ("-----CLIENTS-----")
    Add-Content -Path $outputFile -Value $portTable[$port].ClientIPs
    Add-Content -Path $outputFile -Value ("`n")
}


Start $outputFile

################# END SCRIPT ####################

