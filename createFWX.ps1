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

# Loop over each session and collect IPs and port
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

# Filter out duplicates 
$FWX.clientIPs = ($clients | Select -Unique | sort)
$FWX.serverIPs = ($servers | Select -Unique | sort)
$FWX.hostedPorts = ($hostedPorts | Select -Unique | sort)
$FWX.remotePorts = ($remotePorts | Select -Unique | sort)

$outputFile = "output/FWXSummary.txt"

# Write out the sumamry
Clear-Content $outputFile -ErrorAction SilentlyContinue
Add-Content -Path $outputFile -Value "############### FWX SUMMARY ###############"
Add-Content -Path $outputFile -Value ("Hosted Ports {0}" -f ($FWX.hostedPorts -join ", "))
Add-Content -Path $outputFile -Value ("Remote Ports {0}" -f ($FWX.remotePorts -join ", "))
Add-Content -Path $outputFile -Value ("`n-----SERVERS-----")
Add-Content -Path $outputFile -Value $FWX.serverIPs
Add-Content -Path $outputFile -Value ("`n-----CLIENTS-----")
Add-Content -Path $outputFile -Value $FWX.clientIPs


$FWX