# MIT License
# 
# Copyright (c) 2024 Geoffrey Gontard
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Based on https://gist.github.com/alimbada/4949168#file-wake-ps1 by Ammaar Limbada



$Global:MacAddress = "00-00-00-00-00-00"
$Global:MacAddressFormatted = $MacAddress.Replace("-", "")

if($MacAddress -eq "00-00-00-00-00-00") {
    "Please edit the script and replace the default MAC address" | Write-Host -ForegroundColor Red
    
    exit
}



function Send-Packet([string]$MacAddressFormatted) {
    <#
    .SYNOPSIS
    Sends a number of magic packets using UDP broadcast.
 
    .DESCRIPTION
    Send-Packet sends a specified number of magic packets to a MAC address in order to wake up the machine.  
 
    .PARAMETER MacAddressFormatted
    The MAC address of the machine to wake up.
    #>
 
    try {
        $Broadcast = ([System.Net.IPAddress]::Broadcast)
 
        ## Create UDP client instance
        $UdpClient = New-Object Net.Sockets.UdpClient
 
        ## Create IP endpoints for each port
        $IPEndPoint = New-Object Net.IPEndPoint $Broadcast, 9
 
        ## Construct physical address instance for the MAC address of the machine (string to byte array)
        $MAC = [Net.NetworkInformation.PhysicalAddress]::Parse($MacAddressFormatted.ToUpper())
 
        ## Construct the Magic Packet frame
        $Packet =  [Byte[]](,0xFF*6)+($MAC.GetAddressBytes()*16)
 
        ## Broadcast UDP packets to the IP endpoint of the machine
        $UdpClient.Send($Packet, $Packet.Length, $IPEndPoint) | Out-Null
        $UdpClient.Close()

    } catch {
        $UdpClient.Dispose()
        $Error | Write-Error;
    }
}



# Sometimes the remote machine doesn't start, so we just send the magic packet multiple times
function Be-Sure-To-Start() {
    Send-Packet $MacAddressFormatted
    Send-Packet $MacAddressFormatted
    Send-Packet $MacAddressFormatted

    $DateTime = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
    "$DateTime | Magic packet sent" | Write-Host
}



# Send magic packets a first time
Be-Sure-To-Start



# Initialize variables for while below
[int]$DateTimeSecCurrent = Get-Date -Format "ss"
[int]$DateTimeSecPrevious = $DateTimeSecCurrent
[int]$DateTimeSecDifference = 5



# Continuously ping the IP address associated to the given MAC address to know when the remote machine will be up
while($true) {

    $DateTime = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
    $IpAddress = arp -a | Select-String $MacAddress | % { $_.ToString().Trim().Split(" ")[0] }

    # Remote output has the IP address will not be present in the ARP table until the remote machine is up 
    if ($IpAddress -eq $null) {
        "$DateTime | $MacAddress is not reachable yet" | Write-Host

        # Uncomment for debug
        # Write-Host $DateTimeSecCurrent
        # Write-Host $DateTimeSecPrevious

        # Send new magic packets if more than $DateTimeSecDifference seconds passed without being able to reach remote machine
        if($DateTimeSecCurrent - $DateTimeSecPrevious -ge $DateTimeSecDifference) {
            "$DateTime | $DateTimeSecDifference seconds since last magic packets sent, sending new wave" | Write-Host -ForegroundColor Yellow
            Be-Sure-To-Start

            # Set new value for current time for the next cycle
            [int]$DateTimeSecPrevious = Get-Date -Format "ss"
        }

        
    } else {

        "$DateTime | $MacAddress ($IpAddress) found in ARP table" | Write-Host -ForegroundColor Green

        # Making sure the ping works at least 1 time
        Test-Connection $IpAddress -Delay 1 -Count 1 -Quiet | Out-Null

        # Check that the IP discovered from ARP table is reachable, if yes exit the script
        if (Test-Connection $IpAddress -Delay 1 -Count 1 -Quiet) {
            "$DateTime | $MacAddress ($IpAddress) reachable" | Write-Host -ForegroundColor Green
            
            break
        }
    }


    # Getting current second to be able to calculate when need to send new magic packets
    [int]$DateTimeSecCurrent = Get-Date -Format "ss"


    Start-Sleep -Seconds 2
}



$Seconds = [int]10
Write-Host "Exiting in $Seconds seconds."
Start-Sleep -Seconds $Seconds

exit
