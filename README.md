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
Function to write to a log-file. First foray into including the "Description", "Synopsis" etc.
Intended to be re-used within other scripts to allow easy logging. Has optional variables for file-name and folder path, with defaults set if nothing is specified.

# Network-Config.ps1
Checks the network interfaces to see:
1) If the IP matches one of our range (array at the top of the sciprt)
2) If it is a "Fortinet" connection - VPN, sets this as Private too to ensure correct profile for it.
3) If it is listed as Public or Private
If it is on our range, not the VPN and Public, marks it as Private.
This was developed as when onboarding a department to Intune we found Windows marked the network as Public by default, blocking various remote-tools.

# Shortcut-Creator.ps1
This script creates a shortcut on the Desktop and Start Menu, sets the icon to be a blue "Question mark" icon, and creates a registry key to confirm it has been set. Allows us to create a shortcut to usefuld documentation for users. The registry key means if they delete the file we don't just re-create it.

# Updates-Reporting.ps1
This script queries Azure Update Compliance and writes to a CSV file: Device Name, Assigned User, UPN, OS Version, and update status - allows for better mapping of users to device names than the built-in Update Compliance page, which just lists device names & not users. 
