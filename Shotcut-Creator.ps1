# Script written 24/03/2021 by Gareth Pullen
# Creates shortcut to "Your New Computer" page in users' Start & on Desktop
# Checks for a registry key before running, to avoid re-creating the shortcut if a user deletes it.

param (
	$ShortcutName = "Your New Computer",
	$ShortcutUrl = "",
    $Desktop = [Environment]::GetFolderPath("Desktop")
)

#If the registry key "HKCU\Software\CSCS\YNCShortuct" already exists, we've already run.
If (Get-ItemProperty -Path 'HKCU:\Software\CSCS' -Name YNCShortcut -ErrorAction SilentlyContinue) {
    Exit #Quit the script before re-creating the shortcut for this user.
}

$WScriptShell = New-Object -ComObject WScript.Shell

$Shortcut = $WScriptShell.CreateShortcut("$Desktop\$ShortcutName.lnk")
$Shortcut.TargetPath = $ShortcutUrl
$Shortcut.IconLocation = "%SystemRoot%\System32\SHELL32.dll,23"
$Shortcut.Save()

$Shortcut = $WScriptShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$ShortcutName.lnk")
$Shortcut.TargetPath = $ShortcutUrl
$Shortcut.IconLocation = "%SystemRoot%\System32\SHELL32.dll,23"
$Shortcut.Save()

#Create the registry key so we don't run again, so users can delete this shortcut.
If (!(Get-Item -Path 'HKCU:\Software\CSCS' -ErrorAction SilentlyContinue)) {
    New-Item -Path 'HKCU:\Software\CSCS' | New-ItemProperty -Name YNCShortcut -Value 1 -Force | Out-Null
} Else {
    New-ItemProperty -Path 'HKCU:\Software\CSCS' -Name YNCShortcut -Value 1 -Force | Out-Null
}