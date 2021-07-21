




$sessions = get-childitem -Path "output\" -recurse -Include "session.xml" | Import-CliXML
$FWX = New-Object -TypeName psobject -Property @{
        clientIPs=$null
        serverIPs=$null
        hostedPorts=$null
        remotePorts=$null
        numSessions=$sessions.length
        duration=0
}

$clients = New-Object -TypeName "System.Collections.ArrayList"
$servers = New-Object -TypeName "System.Collections.ArrayList"
$hostedPorts = New-Object -TypeName "System.Collections.ArrayList"
$remotePorts = New-Object -TypeName "System.Collections.ArrayList"

ForEach($session in $sessions){
    ForEach($port in $session.keys){

        if($session[$port].serverIPs){
            $a = $servers.AddRange($session[$port].ServerIPs)
            $a = $remotePorts.Add($port)
        } 
        if($session[$port].clientIPs){
            $a = $clients.AddRange($session[$port].clientIPs)
            $a = $hostedPorts.Add($port)
        }
        if($port -eq "session"){
            $FWX.duration = ($FWX.duration + $session[$port].duration)
        }
    }
}

$FWX.clientIPs = ($clients | Select -Unique)
$FWX.serverIPs = ($servers | Select -Unique)
$FWX.hostedPorts = ($hostedPorts | Select -Unique)
$FWX.remotePorts = ($remotePorts | Select -Unique)

$FWX