
# Script Params 
 param (
    [string]$IPInterface = "Primary",
    [string]$NTVConfigTemplate = "NTVConfig.cfg",
    [int]$CaptureTime = 60 
 )

Enum Ports {
    SYSTEM = 1
    REGISTERED = 2
    EPHEMERAL = 3
}

function runNTVCapture{
    param($CAPTURE_TIME, $configFile, $outFileName, $InterfaceAlias)
    Write-Host "NTV Params: $CAPTURE_TIME, $configFile, $outFileName, $InterfaceAlias"
    $interfaceGuid = (Get-NetAdapter | Select InterfaceGuid, Name | Where Name -eq $InterfaceAlias).InterfaceGuid
    Write-Host "Interface GUID: $interfaceGuid"
    $tmpConfig = "new_config.cfg"

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
    Start-Process -FilePath "NetworkTrafficView.exe" -ArgumentList "/LoadConfig $tmpConfig /captureTime $CAPTURE_TIME /scomma $outFileName" -ErrorAction Stop
    # Go to Sleep....
    for ($i = 0; $i -le $CAPTURE_TIME; $i++ )
    {
        $secondsLeft = $CAPTURE_TIME - $i
        $percentComplete = [int]($i/$CAPTURE_TIME * 100)
        Write-Progress -Activity "Reading Traffic..." -Status "$secondsLeft Seconds remaining" -PercentComplete $percentComplete;
        Sleep(1)
    }
    Sleep(1)
    Write-Host "Capture Complete! "
    Remove-Item $tmpConfig

    #Import and return the captured data
    $data = Import-Csv $outFileName
    return $data
}


function getPortType{
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
    param($srcPortType, $destPortType)

    # Corner cases
    if($srcPortType -eq [Ports]::EPHEMERAL -and $destPortType -eq [Ports]::EPHEMERAL){
        #Handle this case....
        #Write-Host "Two client ports... What to do?"
        return $true
    } elseif($srcPortType -eq [Ports]::REGISTERED -and $destPortType -eq [Ports]::REGISTERED){
        #Write-Host "Two registered ports... what do to?"
        return $true
    } elseif($srcPortType -eq [Ports]::SYSTEM -and $destPortType -eq [Ports]::SYSTEM){
        #Write-Host "Two System ports..."
        return $true
    } 
    return $false
}

function getPortReferenceCount{
    param($port)
    #Write-Host "PORT: $port"
    #$data | Select 'Source Port' | Where 'Source Port' -eq $port
    $count = ($data | Select 'Source Port' | Where 'Source Port' -eq $port | Measure).Count
    $count += ($data | Select 'Destination Port' | Where 'Destination Port' -eq $port | Measure).Count
    return $count
}

function getPortByRefenceCount{
    param($src, $dest)
    $srcCount = getPortReferenceCount $src $data
    
    $destCount = getPortReferenceCount $dest $data
    #Write-Host "Comparing...: $src :  $srcCount -- $dest $destCount" 
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

    if(isSpecialCase $srcPortType $destPortType){
        #Write-Host $src $dest
        $port = getPortByRefenceCount $src $dest
        return $port
    } elseif($src -eq $dest){
        return $src -or $dest
    } 

    return ($src, $dest | Measure -Min).Minimum   
}

function isServicePortLocal{
    param($port, $srcPort, $destPort, $outbound)

    if($outbound){
        if($sp -eq $srcPort){
            return $true
        } else {
            return $false
        }

    } else {
        if($sp -eq $srcPort){
            return $false
        } else {
            return $true
        }
    }

}

function initializePortSummary {
    param($sp, $packetCount, $description, $proc, $address, $local)
    #Write-Host "Creating Port Summary $sp"
    $processList = New-Object -TypeName "System.Collections.ArrayList"
    $clientList = New-Object -TypeName "System.Collections.ArrayList"
    $serverList = New-Object -TypeName "System.Collections.ArrayList"
    if($local){
        $add = $clientList.Add($address)
    } else {
        $add = $serverList.Add($address)
    }
    
    if($proc){
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

    #Write-Host "-------Port Summary -------"
    #$summary
    #Write-Host "____________________________"
    #$summary.ClientIPs.Add($address)
    if($local){
        if(-not $summary.ClientIPs.Contains($address)){
            $add = $summary.ClientIPs.Add($address)
        }
    } else {
        if(-not $summary.ServerIPs.Contains($address)){
            $add = $summary.ServerIPs.Add($address)
        }
    }

    if(-not $summary.Processes.Contains($proc)){
        $add = $summary.Processes.Add($proc)
    }
    $summary.PacketCount += $packetCount

    return $summary
}



################# MAIN ####################

$server = (get-netipaddress | Where InterfaceAlias -eq $IPInterface).IPAddress
$rawOutputFile = ($server + "_traffic_raw.csv")
Write-host $server
$data = runNTVCapture $CaptureTime $NTVConfigTemplate $rawOutputFile $IPInterface
#$data = Import-Csv $rawOutputFile

$portTable = @{}

ForEach($row in $data){

    $srcPort = [int]$row.'Source Port'
    $destPort = [int]$row.'Destination Port'
    $packetCt = [int]$row.'Packet Count'
    $serviceName = $row.'Service Name'
    $sp = [int](getServicePort $srcPort $destPort)
    $owningProc = $row.'Process Filename'
    $outbound = ($row.'Source Address' -eq $server)
    if($outbound){
        $address = $row.'Destination Address'
    }  else {
        $address = $row.'Source Address'
    }
    #Write-Host "ADDRESS: "$address
    $local = isServicePortLocal $sp $srcPort $destPort $outbound

    if($sp){
        if($portTable.ContainsKey($sp)){
            $summary = $portTable[$sp]
             $summary = updatePortSummary $packetCt $owningProc $address $local $summary
        } else {
            $summary = initializePortSummary $sp $packetCt $serviceName $owningProc $address $local
            $portTable.Add($sp, $summary)
            Write-Host "Added summary for port $sp"
        }

    } else {
        Write-host "Cannot determine service port for $srcPort - $destPort"
    }

}

$outputFile = ".\TrafficSummary.txt"
Clear-Content $outputFile
$pt = $portTable.GetEnumerator() | Sort Key
$portTable
ForEach($port in $pt){
    $port = $port.Name
    Add-Content -Path $outputFile -Value ("############### " + $portTable[$port].Port + " : " + $portTable[$port].Description + " ###############")
    Add-Content -Path $outputFile -Value ("Port #: " + $portTable[$port].Port)
    Add-Content -Path $outputFile -Value ("Service #: " + $portTable[$port].Description)
    Add-Content -Path $outputFile -Value ("Packet Count: " + $portTable[$port].PacketCount)
    Add-Content -Path $outputFile -Value ("Processes: ") -NoNewLine
    ForEach($proc in $portTable[$port].Processes){
        Add-Content -Path $outputFile -Value ($proc + "  ") -NoNewLine
    }
    Add-Content -Path $outputFile -Value "`n"
    Add-Content -Path $outputFile -Value ("`n`n-----SERVERS-----")
    Add-Content -Path $outputFile -Value $portTable[$port].ServerIPs
    Add-Content -Path $outputFile -Value ("`n-----CLIENTS-----")
    Add-Content -Path $outputFile -Value $portTable[$port].ClientIPs
    Add-Content -Path $outputFile -Value ("`n")
}

