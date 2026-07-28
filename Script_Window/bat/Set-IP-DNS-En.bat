@echo off
setlocal enabledelayedexpansion

:: ==============================================
:: Configuration
:: ==============================================
set "mask=255.255.255.0"
set "gateway=172.16.0.1"
set "dns_primary=172.16.0.197"
set "dns_backup=114.114.114.114"
set "keyword=Realtek"
set "network_prefix=172.16.0"

:: ==============================================
:: Auto Admin Privilege
:: ==============================================
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting admin privilege...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs"
    pushd "%~dp0"
    cls

:: ==============================================
:: Step 1: Find Realtek Adapters
:: ==============================================
echo.
echo ============ Adapter Detection ============
echo Scanning for enabled %keyword% network adapters...

set /a count=0
set "adapter_list="

for /f "tokens=2 delims==" %%a in (
    'wmic nic where "NetEnabled=true and Name like '%%%keyword%%%'" get NetConnectionID /value 2^>nul'
) do (
    for /f "delims=" %%b in ("%%a") do (
        if not "%%b"=="" (
            set /a count+=1
            set "adapter_list=!adapter_list! "%%b""
            echo Found: %%b
        )
    )
)

if %count%==0 (
    echo.
    echo ERROR: No enabled %keyword% adapter found.
    echo ===========================================
    pause
    exit /b 1
)
echo Total: %count% adapter(s) will be configured
echo ===========================================

:: ==============================================
:: Step 2: Input & Validate IP
:: ==============================================
:input_ip
echo.
set "input_ip="
set /p "input_ip=Enter static IP (format: %network_prefix%.x, range 2-254): "

if "%input_ip%"=="" (
    echo Input cannot be empty!
    goto input_ip
)

set "ip_valid=1"
for /f "tokens=1-4 delims=." %%a in ("%input_ip%") do (
    if "%%d"=="" set "ip_valid=0"
    echo %%a| findstr /r "^[0-9]*$" >nul || set "ip_valid=0"
    echo %%b| findstr /r "^[0-9]*$" >nul || set "ip_valid=0"
    echo %%c| findstr /r "^[0-9]*$" >nul || set "ip_valid=0"
    echo %%d| findstr /r "^[0-9]*$" >nul || set "ip_valid=0"
    if not "%%a.%%b.%%c"=="%network_prefix%" set "ip_valid=0"
    if %%d lss 2 set "ip_valid=0"
    if %%d gtr 254 set "ip_valid=0"
    if %%d equ 1 set "ip_valid=0"
)

if "%ip_valid%"=="0" (
    echo Invalid IP! Must be between %network_prefix%.2 and %network_prefix%.254
    echo Example: 172.16.0.100
    goto input_ip
)

echo.
echo Target IP: %input_ip% , starting configuration...
echo ===========================================

:: ==============================================
:: Step 3: Apply Configuration
:: ==============================================
set /a success_ip=0
set /a success_dns=0

for %%i in (%adapter_list%) do (
    echo.
    echo Configuring: %%~i

    netsh interface ipv4 set address name=%%~i static %input_ip% %mask% %gateway% >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [1/2] IP/Gateway OK
        set /a success_ip+=1
    ) else (
        echo   [1/2] IP/Gateway FAILED
    )

    netsh interface ipv4 set dns name=%%~i static %dns_primary% primary >nul 2>&1
    netsh interface ipv4 add dns name=%%~i %dns_backup% index=2 >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [2/2] DNS OK
        set /a success_dns+=1
    ) else (
        echo   [2/2] DNS FAILED
    )
)

:: ==============================================
:: Step 4: Result
:: ==============================================
echo.
echo Refreshing network cache...
ipconfig /flushdns >nul
arp -d * >nul

echo.
echo ============ Configuration Done ============
echo Adapters: %count%
echo IP Address: %input_ip%
echo Subnet Mask: %mask%
echo Gateway: %gateway%
echo Primary DNS: %dns_primary%
echo Secondary DNS: %dns_backup%
echo ===========================================

echo.
echo Current active configuration:
for %%i in (%adapter_list%) do (
    echo.
    echo [%%~i]
    netsh interface ipv4 show address "%%~i" | findstr /c:"IP Address" /c:"Subnet Prefix" /c:"Default Gateway"
    netsh interface ipv4 show dns "%%~i" | findstr /c:"Server Address"
)

echo.
pause