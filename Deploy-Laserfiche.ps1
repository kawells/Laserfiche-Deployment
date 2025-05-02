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
    # Import the FileRoot as an argument, with default.
    param(
        # FileRoot: path containing the extracted Laserfiche Installer package files
        [string]$FileRoot='C:\Path\To\Files'
    )
    $filePath = "$($FileRoot)\package.manifest"

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
    Uninstall-LfPreamble -Fileroot 'C:\Path To\Extracted Package'
    #>
    # Import the FileRoot as an argument, with default.
    param(
        # FileRoot: path containing the extracted Laserfiche Installer package files
        [string]$FileRoot='C:\Path\To\Files'
    )

    # Import the package manifest
    $packageJson = Import-LfManifest -FileRoot $FileRoot

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
            Write-Host "Application to Uninstall found: $($foundApp.DisplayName)"
            $installCommand = "msiexec.exe"
            $installArguments = "/x $($productId) /qn"
            try {
                Start-Process $installCommand -ArgumentList $installArguments -Wait
                Write-Debug "Uninstall command executed for $($foundApp.DisplayName)"
            }
            catch {
                Write-Warning "Failed to uninstall application: $($foundApp.DisplayName)"
            }
        }
        else {
            Write-Debug "Application with Product ID $productId is not installed."
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
    Install-LfPrereqs -FileRoot 'C:\Path To\Extracted Package'
    #>
    param(
        # FileRoot: path containing the extracted Laserfiche Installer package files
        [string]$FileRoot='C:\Path\To\Files'
    )

    # Import the package manifest
    $packageJson = Import-LfManifest -FileRoot $FileRoot

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
                # Construct the installation command
                $installCommand = "$FileRoot\$($prereq.Path)"
                $installArguments = $($prereq.CommandLine)
                Write-Debug "Attempting to install prerequisite with command: Start-Process -FilePath $installCommand -ArgumentList $installArguments -Wait"
                try {
                     Start-Process -FilePath $installCommand -ArgumentList $installArguments -Wait
                }
                catch {
                    Write-Warning "Failed to install prerequisite: $($prereq.CheckKey)"
                }
            }
            else {
                Write-Debug "Prerequisite found: $($prereq.CheckKey)"
            }
        }
        catch {
            Write-Warning "Failed to access registry key: $checkKey"
        }
    }
}

function Install-LfPackage {
    <#
    .SYNOPSIS
    Installs a Laserfiche Package.

    .DESCRIPTION
    This function installs a generic Laserfiche Package using the installer
    file specified in the package manifest.  Compatible with either either LFMsi or LFSetup packages.

    .EXAMPLE
    Install-LfWindowsClient
    Install-LfWindowsClient -FileRoot 'C:\Path To\Extracted Package'
    #>
    # Import the FileRoot as an argument, with default.
    param(
        # FileRoot: path containing the extracted Laserfiche Installer package files
        [string]$FileRoot='C:\Path\To\Files'
    )

    # Import the package manifest, passing imported FileRoot
    $packageJson = Import-LfManifest -FileRoot $FileRoot

    # Determine if the package type is an MSI or a legacy LFSetup
    # Type: MSI - Uses MSI flags
    if($packageJSON.PackageType -eq 'LFMsi'){
        # Construct the installation command
        Write-Debug "Found Package Type: LFMsi"
        $installCommand = "msiexec.exe"
        $installArguments = "/package `"$FileRoot\$($packageJson.InstallerFile)`" REBOOT=ReallySuppress /QN"

        # Execute the installation command
        Write-Debug "Attempting to install package with command:  Start-Process $installCommand -ArgumentList $installArguments -Wait"
        Start-Process $installCommand -ArgumentList $installArguments -Wait
    }
    # Type: Legacy LF Setup - Uses legacy flags based on Unattended Installation
    elseif($packageJSON.PackageType -eq 'LFSetup'){
        # Note: INSTALLLEVEL no longer applies here, as only the base program is included in each package
        # Construct the installation command
        Write-Debug "Found Package Type: LFSetup"
        $installCommand = "`"$FileRoot\$($packageJson.InstallerFile)`""
        $installArguments = " -silent -iacceptlicenseagreement -lang en -log $($env:SystemRoot)\Logs\Software\$($packageJSON.ID)-$($packageJSON.Version).log LANGPACK=en"
        
        # Execute the installation command
        Write-Debug "Attempting to install package with command: Start-Process -FilePath $installCommand -ArgumentList $installArguments -Wait"
        Start-Process -FilePath $installCommand -ArgumentList $installArguments -Wait
    }
    # Unknown package type, throw an exception
    else {
        throw "Cannot Install: Unknown package type '$($packageJSON.PackageType)'.  Known package types are 'LFMsi' and 'LFSetup'."
    }
}


function Uninstall-LfPackage {
    <#
    .SYNOPSIS
    Uninstalls a Laserfiche Package.

    .DESCRIPTION
    This function uninstalls a Laserfiche package using the installer
    file specified in the package manifest.
    Note: Package must by of type LFMsi.

    .EXAMPLE
    Uninstall-LfWindowsClient
    Uninstall-LfWindowsClient -Fileroot 'C:\Path To\Extracted Package'
    #>
    # Import the FileRoot as an argument, with default.
    param(
        # FileRoot: path containing the extracted Laserfiche Installer package files
        [string]$FileRoot='C:\Path\To\Files'
    )

    # Import the package manifest
    $packageJson = Import-LfManifest -FileRoot $FileRoot

    # Determine if the package type is an MSI or a legacy LFSetup
    # Type: MSI - Uses MSI flags
    if($packageJSON.PackageType -eq 'LFMsi'){
        # Construct and execute the uninstallation command
        Write-Debug "Found Package Type: LFMsi"
        $installCommand = "msiexec.exe"
        $installArguments = "/uninstall `"$FileRoot\$($packageJson.InstallerFile)`" REBOOT=ReallySuppress /QB!"
        
        # Execute the uninstall command
        Write-Debug "Attempting to uninstall package with command: Start-Process -FilePath $installCommand -ArgumentList $installArguments -Wait"
        Start-Process -FilePath $installCommand -ArgumentList $installArguments -Wait
    }
    # Unknown package type, throw an exception
    else {
        throw "Cannot Uninstall: Not LFMsi package type '$($packageJSON.PackageType)'.  Known package types are 'LFMsi' and 'LFSetup'."
    }
}

function Repair-LfPackage {
    <#
    .SYNOPSIS
    Repairs a Laserfiche Package.

    .DESCRIPTION
    This function repairs a Laserfiche package using the installer
    file specified in the package manifest.
    Note: Package must by of type LFMsi.

    .EXAMPLE
    Repair-LfWindowsClient
    Repair-LfWindowsClient -Fileroot 'C:\Path To\Extracted Package'
    #>
    # Import the FileRoot as an argument, with default.
    param(
        # FileRoot: path containing the extracted Laserfiche Installer package files
        [string]$FileRoot='C:\Path\To\Files'
    )

    # Import the package manifest
    $packageJson = Import-LfManifest -FileRoot $FileRoot

        # Determine if the package type is an MSI or a legacy LFSetup
    # Type: MSI - Uses MSI flags
    if($packageJSON.PackageType -eq 'LFMsi'){
        # Construct and execute the uninstallation command
        Write-Debug "Found Package Type: LFMsi"
        $installCommand = "msiexec.exe"
        $installArguments = "$ /fa `"$FileRoot\$($packageJson.InstallerFile)`""
        
        # Execute the repair command
        Write-Debug "Attempting to repair package with command: Start-Process -FilePath $installCommand -ArgumentList $installArguments -Wait"
        Start-Process -FilePath $installCommand -ArgumentList $installArguments -Wait
        #Invoke-Expression $installCommand
    }
    # Unknown package type, throw an exception
    else {
        throw "Cannot Repair: Not LFMsi package type '$($packageJSON.PackageType)'.  Known package types are 'LFMsi' and 'LFSetup'."
    }
}


function Install-LfPackageWithPrereqs {
    <#
    .SYNOPSIS
    Installs a Laserfiche package, including preambles and prerequisites.

    .DESCRIPTION
    This function installs a Laserfiche Package using the installer
    file specified in the package manifest.

    .EXAMPLE
    Install-LfWindowsClientWithPrereqs
    Install-LfWindowsClientWithPrereqs -FileRoot 'C:\Path To\Extracted Package'
    #>
    # Import the FileRoot as an argument, with default.
    # Note: Variable named FilePackageRoot due to apparent global conflicts with $FileRoot
    param(
        # FilePackageRoot: path containing the extracted Laserfiche Installer package files
        [Alias("FileRoot")]
        [string]$FilePackageRoot='C:\Path\To\Files'
    )

    # Import the package manifest
    Uninstall-LfPreamble -FileRoot $FilePackageRoot
    Install-LfPrereqs -FileRoot $FilePackageRoot
    Install-LFPackage -FileRoot $FilePackageRoot
}