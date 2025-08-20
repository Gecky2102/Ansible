# Script per configurare WinRM su host Windows target
# Eseguire questo script sui server Windows prima del primo deployment

# Abilita WinRM
Enable-PSRemoting -Force

# Configura WinRM per connessioni HTTP
winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

# Configura firewall per WinRM
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow

# Configura listener HTTP
winrm create winrm/config/listener?Address=*+Transport=HTTP

# Verifica configurazione
Write-Host "Configurazione WinRM completata. Verifica:"
winrm enumerate winrm/config/listener

# Test connessione locale
Test-WSMan -ComputerName localhost

Write-Host "Setup WinRM completato!"
Write-Host "Ora puoi eseguire i playbook Ansible da un controller Linux/WSL"
