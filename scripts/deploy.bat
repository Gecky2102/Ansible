@echo off
REM Script PowerShell per deployment Ansible su Windows
REM Uso: deploy.bat [environment] [tags]

setlocal EnableDelayedExpansion

set ENVIRONMENT=%1
if "%ENVIRONMENT%"=="" set ENVIRONMENT=development

set TAGS=%2
if "%TAGS%"=="" set TAGS=all

set INVENTORY_FILE=inventory\hosts.yml
set PLAYBOOK=playbooks\site.yml

echo 🚀 Avvio deployment Ansible
echo Environment: %ENVIRONMENT%
echo Tags: %TAGS%
echo Inventory: %INVENTORY_FILE%
echo Playbook: %PLAYBOOK%
echo.

REM Verifica che i file esistano
if not exist "%INVENTORY_FILE%" (
    echo ❌ File inventory non trovato: %INVENTORY_FILE%
    exit /b 1
)

if not exist "%PLAYBOOK%" (
    echo ❌ Playbook non trovato: %PLAYBOOK%
    exit /b 1
)

REM Verifica connettività
echo 🔍 Verifica connettività hosts...
ansible all -i "%INVENTORY_FILE%" -m ping --limit "%ENVIRONMENT%"

if errorlevel 1 (
    echo ❌ Problemi di connettività rilevati
    set /p REPLY="Continuare comunque? (y/N): "
    if /i not "!REPLY!"=="y" exit /b 1
)

REM Esegui il playbook
echo.
echo 🎬 Esecuzione playbook...
if "%TAGS%"=="all" (
    ansible-playbook -i "%INVENTORY_FILE%" "%PLAYBOOK%" --limit "%ENVIRONMENT%"
) else (
    ansible-playbook -i "%INVENTORY_FILE%" "%PLAYBOOK%" --limit "%ENVIRONMENT%" --tags "%TAGS%"
)

echo.
echo ✅ Deployment completato!
pause
