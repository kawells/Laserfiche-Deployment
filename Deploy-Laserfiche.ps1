function Import-LfManifest {
    <#
    .SYNOPSIS
    Imports and parses the Laserfiche package manifest file as JSON.

    .DESCRIPTION
    This function reads the `package.manifest` file located in the specified directory,
    parses its contents as JSON, and returns the resulting object.

    .OUTPUTS
    [PSCustomObject] The parsed JSON object representing the package manifest.

    .EXAMPLE
    $manifest = Import-LfManifest
    Write-Output $manifest
    #>

    # Define the root directory for the manifest file
    $fileRoot = 'C:\Path\To\Files'
    $filePath = "$fileRoot\package.manifest"

    # Ensure the manifest file exists
    if (-not (Test-Path -Path $filePath)) {
        throw "The manifest file '$filePath' does not exist."
    }

    # Read and parse the manifest file as JSON
    try {
        $packageJson = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse the manifest file '$filePath' as JSON. Ensure the file contains valid JSON."
    }

    # Return the parsed JSON object
    return $packageJson
}

function Uninstall-LfPreamble {
    <#
    .SYNOPSIS
    Uninstalls preamble applications listed in the Laserfiche package manifest.

    .DESCRIPTION
    This function reads the package manifest to identify preamble applications
    (e.g., dependencies or prerequisites) and uninstalls them by locating their
    registry entries and invoking the appropriate uninstall commands.

    .EXAMPLE
    Uninstall-LfPreamble
    #>

    # Import the package manifest
    $packageJson = Import-LfManifest

    # Define registry paths to search for installed applications
    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    # Iterate through each preamble listed in the manifest
    foreach ($uninstallPackage in $packageJson.Preambles) {
        $foundApp = $null

        # Check if the preamble type is 'UninstallPackage'
        if ($uninstallPackage.PreambleType -eq 'UninstallPackage') {
            $productId = $uninstallPackage.Data

            # Search for the application in the registry
            foreach ($path in $registryPaths) {
                try {
                    $app = Get-ItemProperty $path | Where-Object { $_.IdentifyingNumber -eq $productId }
                    if ($app) {
                        $foundApp = $app
                        break
                    }
                }
                catch {
                    Write-Warning "Failed to access registry path: $path"
                }
            }
        }

        # If the application is found, uninstall it
        if ($foundApp) {
            Write-Host "Application found: $($foundApp.DisplayName)"
            $uninstallCommand = "msiexec.exe /x $productId /qn"
            try {
                Invoke-Expression $uninstallCommand
                Write-Host "Uninstall command executed for $($foundApp.DisplayName)"
            }
            catch {
                Write-Warning "Failed to uninstall application: $($foundApp.DisplayName)"
            }
        }
        else {
            Write-Host "Application with Product ID $productId is not installed."
        }
    }
}

function Install-LfPrereqs {
    <#
    .SYNOPSIS
    Installs prerequisites listed in the Laserfiche package manifest.

    .DESCRIPTION
    This function checks for the presence of prerequisites specified in the
    package manifest. If a prerequisite is missing or outdated, it installs
    the prerequisite using the provided command.

    .EXAMPLE
    Install-LfPrereqs
    #>
    $fileRoot = 'C:\Path\To\Files'

    # Import the package manifest
    $packageJson = Import-LfManifest

    # Define the root registry path for checking prerequisites
    $checkRoot = 'HKLM:\'

    # Iterate through each prerequisite listed in the manifest
    foreach ($prereq in $packageJson.Prereqs) {
        $checkKey = $checkRoot + $prereq.CheckKey

        try {
            # Check if the prerequisite is installed or meets the required version
            $keyResult = Get-ItemProperty $checkKey
            if (($null -eq $keyResult) -or ($prereq.CheckValueTarget -gt $keyResult.$($prereq.CheckValue))) {
                Write-Host "Prerequisite not found: $($prereq.CheckKey)"
                $installCommand = "$fileRoot\$($prereq.Path) $($prereq.CommandLine)"
                try {
                    Invoke-Expression $installCommand
                }
                catch {
                    Write-Warning "Failed to install prerequisite: $($prereq.CheckKey)"
                }
            }
            else {
                Write-Host "Prerequisite found: $($prereq.CheckKey)"
            }
        }
        catch {
            Write-Warning "Failed to access registry key: $checkKey"
        }
    }
}

function Install-LfWindowsClient {
    <#
    .SYNOPSIS
    Installs the Laserfiche Windows Client.

    .DESCRIPTION
    This function installs the Laserfiche Windows Client using the installer
    file specified in the package manifest.

    .EXAMPLE
    Install-LfWindowsClient
    #>
    $fileRoot = 'C:\Path\To\Files'

    # Import the package manifest
    $packageJson = Import-LfManifest

    # Construct and execute the installation command
    $installCommand = "msiexec /package `"$fileRoot\$($packageJson.InstallerFile)`" REBOOT=ReallySuppress /QN"
    Invoke-Expression $installCommand
}

function Uninstall-LfWindowsClient {
    <#
    .SYNOPSIS
    Uninstalls the Laserfiche Windows Client.

    .DESCRIPTION
    This function uninstalls the Laserfiche Windows Client using the installer
    file specified in the package manifest.

    .EXAMPLE
    Uninstall-LfWindowsClient
    #>
    $fileRoot = 'C:\Path\To\Files'

    # Import the package manifest
    $packageJson = Import-LfManifest

    # Construct and execute the uninstallation command
    $installCommand = "msiexec /uninstall `"$fileRoot\$($packageJson.InstallerFile)`" REBOOT=ReallySuppress /QB!"
    Invoke-Expression $installCommand
}

function Repair-LfWindowsClient {
    <#
    .SYNOPSIS
    Repairs the Laserfiche Windows Client.

    .DESCRIPTION
    This function repairs the Laserfiche Windows Client using the installer
    file specified in the package manifest.

    .EXAMPLE
    Repair-LfWindowsClient
    #>
    $fileRoot = 'C:\Path\To\Files'

    # Import the package manifest
    $packageJson = Import-LfManifest

    # Construct and execute the uninstallation command
    $installCommand = "msiexec /fa `"$fileRoot\$($packageJson.InstallerFile)`""
    Invoke-Expression $installCommand
}
