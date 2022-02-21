#Script to add printers from me-print
#Written 27/04/2021 by Gareth Pullen (grp43)

$PrintServer = "\\FQDN-of-print-server\"
$PrinterList = @(
"PrinterName1"
"PrinterName2"
)

#Note the FQDN again below,.
If(!(Test-Connection "me-print.medschl.cam.ac.uk" -Quiet)){
    Throw "Error contacting print server"
    Exit
}
try {
    foreach ($Printer in $PrinterList){
    Add-Printer -ConnectionName "$PrintServer$Printer"
    }
}
Catch {
    Throw "Error adding printer"
}