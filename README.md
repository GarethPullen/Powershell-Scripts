# Powershell-Scripts
A collection of useful PowerShell Scripts I've created.

# Add-Admin-Groups.ps1
This script adds two AzureAD Groups to the local "Administrators" group on devices. It first checks if the groups exist, to avoid getting into an "Error" state when deployed via the Endpoint Console > Scripts section.

# Deploy-Printers.ps1
This script is quite simple, it checks if it can ping the print-server, and if so will then run through the Array of printers defined at the top of the script to add them to the device. Uses a "Try / Catch" to add each printer, so in the event of a problem adding one it doesn't end the entire script but instead skips it and moves onto the next printer in the list.

# Get-Events.ps1
This script prompts the user for a computer-name (defaults to Local Host) and a time-range (defaults to "the last 24 hours"), it then asks if the user wants to select which event logs to display, or show all events. Extremely useful for identifying errors when you know the approximate time, as Windows has a lot more Event Logs than the standard "Application", "System" and "Security".

# Intune-add-group-to-admin.ps1
This script lists all AzureAD groups, the user can then select one or more of them, it prompts for an output folder & file-name, and then produces a simple PowerShell script to add that user group to the local Administrators Group. The generated script can be uploaded to the Intune > Scripts section to run on devices automatically. 

# Local-Admin-to-Names.ps1
This script reads the Local Administrators group on the machine it is run on, then looks up the SID's against the AzureAD groups, to then convert them into the group names. Useful as the Windows Groups viewer can't properly handle the AzureAD group SID to Name conversion itself (you end up with a bunch of SIDs listed, which are difficult to manually convert!)

# Log-Write.ps1
