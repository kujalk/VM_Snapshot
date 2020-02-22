<#
Purpose - To get details of snapshots created on VMs sitting across standalone ESXI hosts
Developer - K.Janarthanan
Date - 14/2/2020

Assumptions - 
1. 1 User name and password is connected across all ESXI servers
2. Password is stored in encrypted format
3. Change the following global variables according to the requirement

Global variables
----------------------------------------------------------------------------
$global:user_name -> User name for ESXI hosts
$global:password -> Password of the user to connect to ESXI host (Encrypted)
$global:esxi_servers -> array of ESXI servers
$global:html_path -> HTML file to be stroed

Creating encrypted password [Please follow these steps before script execution]
---------------------------------------------------------------------------------
1. $credential = Get-Credential
2. $credential.Password | ConvertFrom-SecureString | Set-Content password.txt

P.S - Decryption is only possible in the same machine where the encryption is done, because it utilized  Windows Data Protection API
#>

#Global variables
$global:user_name="dcskug"
$global:password="E:\Snapshots\password.txt"
$global:esxi_servers=@("193.168.3.201","193.168.3.202","193.168.3.203")
$global:html_path="E:\Snapshots\vm_snapshots_encrypt.html"
$global:outItems = New-Object System.Collections.Generic.List[System.Object] #List to store all details

#Function to collect data from individual ESXI servers
function collect_snapshot($esxi)
{

$encrypted = Get-Content $global:password | ConvertTo-SecureString
$credential = New-Object System.Management.Automation.PsCredential($global:user_name,$encrypted)

#Connect to server
Connect-VIServer -Server $esxi -Credential $credential

$vms=Get-VM | select Name -ExpandProperty Name

foreach($vm in $vms)
{
        $original_vm_name=$vm
        $list=($vm | Select-String "\[" -AllMatches).Matches.Index

        #There are VM names with [], to replace [ with * -> VMware does not aupport [] in VM names
        foreach ($i in $list)
        {
        $vm=$vm.Replace("[","*")
        }

        $snaps=Get-Snapshot -VM $vm

        #Skipping VMs without snapshots
        if ($snaps.Name.Count -eq 0)
        {
            continue
        }

        #VM with 1 snaphot
        elseif ($snaps.Name.Count -eq 1)
        {
                #Custom object to store relevant details
                $Result = "" | Select ESXI_Server,VM_Name,Snapshot_Name,Description
                $Result.ESXI_Server=$esxi
                $Result.VM_Name=$original_vm_name
                $Result.Snapshot_Name=$snaps.Name
                $Result.Description=$snaps.Description

                #Adding all details in the list
                $global:outItems.Add($Result)
        }

        #VMs with multiple snapshots, therefore need a looping
        else
        {
            
            for ($i=0; $i -lt $snaps.Name.Count; $i++)
            {
                #Custom object to store relevant details
                $Result = "" | Select ESXI_Server,VM_Name,Snapshot_Name,Description
                $Result.ESXI_Server=$esxi
                $Result.VM_Name=$original_vm_name
                $Result.Snapshot_Name=$snaps.Name[$i]
                $Result.Description=$snaps.Description[$i]
                
                #Adding all details in the list
                $global:outItems.Add($Result)

            }
        }  
}

#Disconnecting from server
Disconnect-VIServer -Server $esxi -Confirm:$false

}

#Start of the script

#Checking whether old HTML file exists, if so delete it
if (Test-Path "$global:html_path" -PathType Leaf)
{
    Remove-Item -path "$global:html_path" -Recurse
}

#Calling function on each ESXI server
foreach ($server in $global:esxi_servers)
{
    collect_snapshot($server)
}

#CSS for HTML table
$Header = @"
<style>
TABLE {border-width: 2px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 2px; padding: 5px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 2px; padding: 5px; border-style: solid; border-color: black;}
</style>
"@

#Storing details in HTML table
$html_data= $outItems | ConvertTo-Html -AS Table -Fragment -Property *
$today=Get-Date
ConvertTo-Html -Body "<p>Date and Time : $today<p> $html_data" -Head $Header | Out-File $global:html_path
