@echo off
cd /d "%~dp0"

:: Check for admin rights
openfiles >nul 2>&1 || (
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c %~s0' -Verb RunAs"
    exit
)

:setup
setlocal enableDelayedExpansion
color 70

:: Create directory for storing the hotspot script if not present
IF NOT EXIST "%appdata%\5kblHotspotFix" (
    mkdir "%appdata%\5kblHotspotFix"
    echo.
)

cd /d "%appdata%\5kblHotspotFix"

:: Create the PowerShell script to start the hotspot if it doesn't exist
IF NOT EXIST "hotspotstart.ps1" (
    (
        ECHO $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile(^)
        ECHO $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile^)
        ECHO $tetheringManager.StartTetheringAsync(^)
    ) > hotspotstart.ps1
)

:: Create the PowerShell script to stop the hotspot if it doesn't exist
IF NOT EXIST "hotspotstop.ps1" (
    (
        ECHO $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile(^)
        ECHO $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile^)
        ECHO $tetheringManager.StopTetheringAsync(^)
        ECHO.
        ECHO $interface = Get-NetAdapter ^| Where-Object { $_.Status -eq "Up" -and $_.NdisPhysicalMedium -eq "802.11" }
        ECHO Start-Process -NoNewWindow -FilePath "netsh" -ArgumentList "wlan set autoconfig enabled=yes interface=$($interface.Name)"
    ) > hotspotstop.ps1
)

:: Default to Wi-Fi as the interface
IF NOT EXIST ".\interface.txt" (
    echo Wi-Fi > .\interface.txt
)

:: Read the Wi-Fi interface name
set /p "interfacename=" < "interface.txt"

:: Automatically start hotspot when script is launched
powershell -ExecutionPolicy Bypass -File .\hotspotstart.ps1

netsh wlan disconnect
timeout 2
netsh wlan set autoconfig enabled=no interface="%interfacename%"

:: Wait until the batch file is closed to stop the hotspot
pause
netsh wlan set autoconfig enabled=yes interface="Wi-Fi"
:: Stop the hotspot and restore settings when the batch file is closed
powershell -ExecutionPolicy Bypass -File .\hotspotstop.ps1
exit
