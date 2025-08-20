# Guida Rapida - Quick Start

## Setup Veloce

### 1. Prepara Environment
```bash
# Clona o scarica il progetto
cd Ansible

# Installa dipendenze
pip install ansible pywinrm[kerberos]
```

### 2. Configura Host
Modifica `inventory/hosts.yml` con i tuoi server:

```yaml
linux_servers:
  hosts:
    my-server:
      ansible_host: IP_DEL_TUO_SERVER
      ansible_user: TUO_UTENTE

windows_servers:
  hosts:
    my-win-server:
      ansible_host: IP_DEL_TUO_SERVER_WIN
      ansible_user: Administrator
```

### 3. Test Connessione
```bash
# Linux
ansible linux_servers -m ping

# Windows (dopo setup WinRM)
ansible windows_servers -m win_ping
```

### 4. Prima Esecuzione
```bash
# Linux/macOS
./scripts/deploy.sh development

# Windows
.\scripts\deploy.ps1 -Environment development
```

## Comandi Essenziali

### Deployment Base
```bash
# Setup completo tutti i server
ansible-playbook -i inventory/hosts.yml playbooks/site.yml

# Solo Linux
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags linux

# Solo Windows
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags windows
```

### Gestione Password
```bash
# Crea vault per password
ansible-vault create group_vars/all/vault.yml

# Modifica vault esistente
ansible-vault edit group_vars/all/vault.yml

# Esegui con password vault
ansible-playbook playbook.yml --ask-vault-pass
```

### Debug e Test
```bash
# Controlla sintassi
ansible-playbook --syntax-check playbooks/site.yml

# Dry run (non applica modifiche)
ansible-playbook --check playbooks/site.yml

# Debug verboso
ansible-playbook -vvv playbooks/site.yml
```

## Esempi Pratici

### Installare Software
```bash
# Installa nginx su tutti i Linux
ansible linux_servers -m package -a "name=nginx state=present" --become

# Installa Chrome su Windows via Chocolatey
ansible windows_servers -m win_chocolatey -a "name=googlechrome"
```

### Gestire Servizi
```bash
# Restart Apache su Linux
ansible linux_servers -m systemd -a "name=apache2 state=restarted" --become

# Restart IIS su Windows
ansible windows_servers -m win_service -a "name=W3SVC state=restarted"
```

### Copiare File
```bash
# Copia file su Linux
ansible linux_servers -m copy -a "src=./config.txt dest=/etc/myapp/"

# Copia file su Windows
ansible windows_servers -m win_copy -a "src=./config.txt dest=C:\MyApp\"
```

## Risoluzione Problemi Rapida

### Linux Non Raggiungibile
```bash
# Verifica SSH
ssh utente@ip_server

# Rigenera chiavi SSH
ssh-keygen -R ip_server

# Usa password invece di chiavi
ansible-playbook --ask-pass playbook.yml
```

### Windows Non Raggiungibile
```powershell
# Su Windows target, esegui:
.\scripts\setup-winrm.ps1

# Testa WinRM
Test-WSMan -ComputerName ip_server
```

### Problemi Permission Denied
```bash
# Usa sudo
ansible-playbook --ask-become-pass playbook.yml

# Verifica utente nel gruppo sudo
sudo usermod -aG sudo nome_utente
```
