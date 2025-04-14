# Laserfiche Deployment Toolkit

This repository contains a collection of custom PowerShell functions designed to assist with the deployment, installation, and uninstallation of the Laserfiche Repository Desktop Client 12 and its prerequisites.

---

## **Functions Overview**

### **1. Import-LfManifest**
Imports and parses the Laserfiche package manifest file (`package.manifest`) as JSON.

- **Purpose**: Provides a structured way to access deployment configuration data stored in the manifest file.
- **Key Features**:
  - Validates the existence of the manifest file.
  - Parses the file into a JSON object for easy access.
- **Example Usage**:
  ```powershell
  $manifest = Import-LfManifest
  Write-Output $manifest
  ```

---

### **2. Uninstall-LfPreamble**
Uninstalls preamble applications (e.g., dependencies or prerequisites) listed in the Laserfiche package manifest.

- **Purpose**: Automates the removal of applications that must be uninstalled before deploying the Laserfiche client.
- **Key Features**:
  - Searches for applications in the Windows registry using their Product IDs.
  - Executes uninstallation commands via `msiexec`.
  - Logs warnings for missing or inaccessible registry paths.
- **Example Usage**:
  ```powershell
  Uninstall-LfPreamble
  ```

---

### **3. Install-LfPrereqs**
Installs prerequisites listed in the Laserfiche package manifest.

- **Purpose**: Ensures all required dependencies are installed before deploying the Laserfiche client.
- **Key Features**:
  - Checks the Windows registry for the presence and version of prerequisites.
  - Executes installation commands for missing or outdated prerequisites.
  - Logs warnings for failed installations or inaccessible registry keys.
- **Example Usage**:
  ```powershell
  Install-LfPrereqs
  ```

---

### **4. Install-LfWindowsClient**
Installs the Laserfiche Repository Desktop Client.

- **Purpose**: Automates the installation of the Laserfiche client using the installer file specified in the manifest.
- **Key Features**:
  - Executes the installation command via `msiexec` in silent mode.
  - Logs warnings for failed installations.
- **Example Usage**:
  ```powershell
  Install-LfWindowsClient
  ```

---

### **5. Uninstall-LfWindowsClient**
Uninstalls the Laserfiche Repository Desktop Client.

- **Purpose**: Automates the removal of the Laserfiche client using the installer file specified in the manifest.
- **Key Features**:
  - Executes the uninstallation command via `msiexec` in silent mode.
  - Logs warnings for failed uninstallations.
- **Example Usage**:
  ```powershell
  Uninstall-LfWindowsClient
  ```

---

## **Laserfiche Repository Desktop Client Installation Files**
The Laserfiche Repository Desktop Client installation files include:
- Microsoft .NET Framework Installer
- Redistributable for Visual Studio 2022 (x86)
- Redistributable for Visual Studio 2022 (x64)
- Laserfiche Repository Desktop Client Installer
- Manifest File

---

## **Manifest File**
The `package.manifest` file is a JSON configuration file that contains deployment details such as:
- Preambles (applications to uninstall before deployment)
- Prerequisites (dependencies to install before deployment)
- Installer file details for the Laserfiche client

---

## **Error Handling**
All functions include robust error handling to:
- Validate file and registry paths.
- Log warnings for inaccessible resources or failed operations.
- Fail gracefully with descriptive error messages.

---

## **Usage Instructions**
1. Install the Laserfiche Installer.
2. Using the Laserfiche Installer, download the Laserfiche Repository Desktop Client files.
1. Place the `Deploy-Laserfiche.ps1` script and the Laserfiche Repository Desktop Client files in appropriate deployment directories.
2. In `Deploy-Laserfiche.ps1`, modify each instance of the `$fileRoot` value with the path to the Laserfiche Repository Desktop Client files.
3. Import the functions into your PowerShell session:
   ```powershell
   . .\Deploy-Laserfiche.ps1
   ```
4. Call the desired function(s) based on your deployment needs.

---

## **Dependencies**
- **PowerShell 5.1 or later**: Required for compatibility with the script and its functions.

---

## **Contributors**
- **Kevin Wells**: Author of the custom functions and deployment script.

---

## **License**
This script is licensed under the GNU LGPLv3 License.

---

## **Support**
For questions or issues, please contact the script author.
