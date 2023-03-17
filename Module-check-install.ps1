function ModuleCheckInstall {
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true)]  
        [ValidateNotNullOrEmpty()]  
        [string[]]$ModulesRequested
    )
    <#Function to check if modules are installed, and install them if not
    Written 17/03/2023 by Gareth Pullen
    takes either a single-item or an array of modules as input
    #>
    Begin {
        #We need to check PSGallery is Trusted
        If (!(get-psrepository -Name 'PSGallery').Trusted) {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            $ResetTrust = $true
        }
        else { $ResetTrust = $false }
    }
    Process {
        Foreach ($Module in $ModulesRequested) {
            try {
                Write-Verbose "Checking if $Module is installed"
                get-installedmodule -name $Module -ErrorAction Stop | out-null
                Write-Verbose "$Module already installed"
            }
            catch {
                Write-Verbose "$Module not found, attempting install"
                #Error means not found - Try installing it
                try {
                    install-module -name $Module -ErrorAction Stop
                }
                Catch {
                    Write-Verbose "$Module returned an error trying to install!"
                    #Caught an error - we want to stop here, but should reset the Trust first.
                    if ($ResetTrust) {
                        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
                    }
                    #Throw the error to halt the module installs.
                    Throw $_
                }
            }
            Try {
                #By this point the module should be installed, so we can Import it.
                Write-Verbose "Attempting to import $Module"
                Import-Module $Module -ErrorAction Stop
            }
            Catch {
                #Catch any errors importing and throw it back.
                Write-Verbose "Error importing module $Module"
                Throw $_
            }
        }
    }
    End {
        #If everything above worked, we should reset the Trust for PSGallery if required
        if ($ResetTrust) {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted
        }
    }

}
