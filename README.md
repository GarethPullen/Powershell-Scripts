# Powershell-Scripts
A collection of useful PowerShell Scripts I've created.

# BulkGroupAdd.ps1
This script asks the user for a CSV file of device names (or Dell Service Tags if they have been pre-uploaded by Dell) and will then add them to the group specified by the "$GroupID" variable (Group Object ID of an AzureAD group). It will handle quotes around the file-path and re-prompt if the file doesn't exist. It will skip over any devices that can't be found in AzureAD, and will post a message to the terminal for any which are already in the group, before moving onto the next item.

# Add-Admin-Groups.ps1
This script adds two AzureAD Groups to the local "Administrators" group on devices. It first checks if the groups exist, to avoid getting into an "Error" state when deployed via the Endpoint Console > Scripts section.

# Deploy-Printers.ps1
This script is quite simple, it checks if it can ping the print-server, and if so will then run through the Array of printers defined at the top of the script to add them to the device. Uses a "Try / Catch" to add each printer, so in the event of a problem adding one it doesn't end the entire script but instead skips it and moves onto the next printer in the list.

# Get-Streams.ps1
This Script is designed to check for Alternate Data Streams (ADS) in NTFS file-systems. If used with the "-file" switch it accepts a path to a file when running the script, and checks that single file for any ADS. Otherwise it prompts the user for a folder to save CSV files to, and a folder to scan. It then scans the folder (and all subfolders) for any "Alternate Data Streams" and outputs the contents of the ADS to a CSV file. It also outputs any errors encountered when scanning the file-system to a different CSV file. Takes the last-folder of the "path to scan" as the output name for the CSV files.

# Get-Events.ps1
This script prompts the user for a computer-name (defaults to Local Host) and a time-range (defaults to "the last 24 hours"), it then asks if the user wants to select which event logs to display, or show all events. Extremely useful for identifying errors when you know the approximate time, as Windows has a lot more Event Logs than the standard "Application", "System" and "Security".

# add-group-to-admin-v2.ps1
V2 of the "Add group to admin" script. Generated scripts don't produce an error if the group is already a member of the Administrators group, when deployed via Intune > Scripts. This script lists all AzureAD groups, the user can then select one or more of them, it prompts for an output folder & file-name, and then produces a PowerShell script to add the group(s) to the local Administrators Group.

# Intune-add-group-to-admin.ps1
*** This has been superseded by the "V2" script above. Left here for posterity.
This script lists all AzureAD groups, the user can then select one or more of them, it prompts for an output folder & file-name, and then produces a simple PowerShell script to add the group(s) to the local Administrators Group. The generated script can be uploaded to the Intune > Scripts section to run on devices automatically. 

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

# Intune-devices-no-user.ps1
This script takes a "Device Configuration ID" (found on the Intune portal) and then queries using the Graph API for all devices with that configuration profile applied. Checks if the user account associated with the property is "System Account" or a "Test account" - if those are the only accounts associated with it, then we assume no user has signed in, as it should be associated with a "normal" Users' UPN.
Can either save it to a CSV file, or display in a window using Powershell's "Out-GridView" function.

# IP-DNS-Lookup.ps1
This script takes a CSV file of IP address as the input, then loops through the list doing a DNS lookup for each one which is then added to a Hashtable for export. If there is no DNS entry it throws and catches an error, and adds "Error - not found" as the hostname. Outputs to a new CSV file with the key-value pairs of "IP" and "Hostname"

# Module-Check-Install.ps1
This script is really just a single function - saved as a script for ease of use. It takes either one string or an array of strings of module-names as input, and then will check if they are already installed - if not it wil try and install them from PSGallery - and then will try to import them.
Call it like:
ModuleCheckInstall "ModuleName"
Or for multiple modules:
ModuleCheckInstall "FirstModule", "SecondModule", "AndSoOn"

# Intune-device-rebuild.ps1
This script is designed to prompt the user to select a device from Intune, and will then delete the Intune Device record, the Autopilot record and the AzureAD Device record - to allow for easier rebuilding of devices (e.g. after a motherboard change).

# Long paths or files.ps1
This script will list all files and/or folders longer than either a default length (100/200) or a user-specified length. It will also list all files where the total "file-path & length" is over 260 characters (which is the normal "Windows maximum path limit"). It will then output them to CSV files (or display to the console if the "-display" switch is used), and notify of which files have been written.

# AAD-Group-member-states.ps1
This script queries AzureAD for a list of all groups, asks the user to choose one, and then gets the members of that group. It then checks the account-status (Enabled / Disabled) of each member, and writes the output to a CSV file.
