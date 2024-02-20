function ToastNotify {
  param (
      [Parameter(Mandatory = $true,
          ValueFromPipeline = $true)]  
      [ValidateNotNullOrEmpty()]  
      [string[]]$TitleText,
      [Parameter(Mandatory = $true,
          ValueFromPipeline = $true)]  
      [ValidateNotNullOrEmpty()]  
      [string[]]$BodyText,
      [Parameter[]]
      [switch[]]$Transient
  )

  $app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]

  $Template = [Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText01

  [xml]$ToastTemplate = ([Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($Template).GetXml())

  If (!($Transient)){
    #Transient not set, so make it persistent by default
  [xml]$ToastTemplate = @"

<toast scenario='reminder'>
<visual>
  <binding template="ToastGeneric">
    <text>$TitleText</text>
    <text>$BodyText</text>
  </binding>
</visual>
<actions>
<action activationType="system" arguments="snooze" hint-inputId="snoozeTime" content="" />
<action activationType="system" arguments="dismiss" content=""/>
</actions>
</toast>
"@
}
Else {
    [xml]$ToastTemplate = @"
<toast launch="app-defined-string">
<visual>
  <binding template="ToastGeneric">
    <text>$TitleText</text>
    <text>$BodyText</text>
  </binding>
</visual>
</toast>
"@
}
  $ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
  $ToastXml.LoadXml($ToastTemplate.OuterXml)

  $notify = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app)

  $notify.Show($ToastXml)

  #source: https://gist.github.com/Windos/9aa6a684ac583e0d38a8fa68196bc2dc

<#
.SYNOPSIS
Function to post a message via Toast Notifications. Takes "TitleText" and "BodyText" inputs. Must be run as user-context.

.DESCRIPTION
Show Toast notification - must be run as user-context. Takes "Header" and the "Body" inputs, and optional "-Transient" switch to change from a persistent notification
Taken from: https://michael-casey.com/2019/05/12/schedule-windows-notifications-with-powershell/
Hacked about by Gareth Pullen 19/02/2024
Modified 20/02/2024 to have Transient switch


.PARAMETER TitleText
The title of the Toast Popup

.PARAMETER BodyText
The main message to be displayed.

.PARAMETER Transient
An optional Switch parameter (presence is detected) which changes the notification to transient instead of persistent

.EXAMPLE
ToastNotify "Hello!" "World!" | Out-Null

.EXAMPLE
ToastNotify "Reboot Required" "Updates have completed - please reboot to finish installing" | Out-Null

.EXAMPLE
ToastNotify "Script Finished" "Powershell script has now completed" -Transient | Out-Null

#>

}

ToastNotify "Reboot Required" "Updates have completed - please reboot to finish installing" | Out-Null
