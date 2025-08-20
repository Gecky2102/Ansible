# 🔧 Capitolo 2 - Installazione e Configurazione

> **🎯 In questo capitolo**: Installerai Ansible sul controller e configurerai la connessione ai server target Linux e Windows.

---

## 📦 Installazione Ansible

### **Su Linux (Ubuntu/Debian)**

#### **Metodo 1: Package Manager (Consigliato)**
```bash
# Aggiorna sistema
sudo apt update

# Installa Ansible e dipendenze
sudo apt install -y ansible python3-pip

# Verifica installazione
ansible --version
```

#### **Metodo 2: PIP (Versione Latest)**
```bash
# Installa pip se non presente
sudo apt install -y python3-pip python3-venv

# Crea virtual environment (opzionale ma consigliato)
python3 -m venv ansible-env
source ansible-env/bin/activate

# Installa Ansible via pip
pip install ansible

# Verifica installazione
ansible --version
```

### **Su Linux (RHEL/CentOS/Fedora)**

#### **RHEL/CentOS 8+**
```bash
# Abilita repository EPEL
sudo dnf install -y epel-release

# Installa Ansible
sudo dnf install -y ansible python3-pip

# Verifica
ansible --version
```

#### **CentOS 7**
```bash
# Installa EPEL
sudo yum install -y epel-release

# Installa Ansible
sudo yum install -y ansible python-pip

# Verifica
ansible --version
```

### **Su macOS**

#### **Metodo 1: Homebrew (Consigliato)**
```bash
# Installa Homebrew se non presente
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Installa Ansible
brew install ansible

# Verifica
ansible --version
```

#### **Metodo 2: PIP**
```bash
# Installa Python se non presente
brew install python

# Installa Ansible
pip3 install ansible

# Verifica
ansible --version
```

### **Su Windows (WSL)**

#### **Setup WSL**
```powershell
# In PowerShell come Amministratore
wsl --install

# Riavvia il computer
```

#### **Setup Ubuntu in WSL**
```bash
# Aggiorna sistema
sudo apt update && sudo apt upgrade -y

# Installa Ansible
sudo apt install -y ansible python3-pip

# Verifica
ansible --version
```

### **🐳 Con Docker (Alternativa)**
```bash
# Esegui Ansible in container
docker run --rm -it -v $(pwd):/ansible quay.io/ansible/ansible:latest

# O crea alias permanente
echo 'alias ansible-docker="docker run --rm -it -v $(pwd):/ansible -w /ansible quay.io/ansible/ansible:latest"' >> ~/.bashrc
```

---

## 🔧 Configurazione Base Ansible

### **File di Configurazione**

#### **Crea ansible.cfg**
```bash
cd ~/ansible-project

# Crea file configurazione
cat > ansible.cfg << 'EOF'
[defaults]
# File inventory predefinito
inventory = inventory/hosts.yml

# Disabilita verifica chiavi SSH (solo per test)
host_key_checking = False

# Timeout connessione
timeout = 30

# Log file
log_path = ./ansible.log

# Interprete Python sui target
interpreter_python = auto_silent

# Gathering dei facts (informazioni sui server)
gathering = smart
fact_caching = memory
fact_caching_timeout = 86400

[ssh_connection]
# Ottimizzazioni SSH
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True

[privilege_escalation]
# Configurazione sudo
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF
```

#### **Verifica Configurazione**
```bash
# Mostra configurazione corrente
ansible-config dump --only-changed

# Verifica file di configurazione
ansible-config view
```

---

## 🐧 Configurazione Target Linux

### **1. Preparazione Server Linux**

#### **Crea Utente Ansible**
```bash
# Sul server Linux target
sudo useradd -m -s /bin/bash ansible
sudo passwd ansible

# Aggiungi a gruppo sudo/wheel
sudo usermod -aG sudo ansible        # Ubuntu/Debian
# oppure
sudo usermod -aG wheel ansible       # RHEL/CentOS
```

#### **Configura Sudo senza Password**
```bash
# Sul server Linux target
sudo visudo

# Aggiungi alla fine del file:
ansible ALL=(ALL) NOPASSWD:ALL

# O crea file dedicato (metodo preferito)
echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible
sudo chmod 440 /etc/sudoers.d/ansible
```

### **2. Configurazione SSH**

#### **Setup Chiavi SSH (Metodo Consigliato)**
```bash
# Sul controller
ssh-keygen -t rsa -b 4096 -C "ansible@$(hostname)"

# Accetta tutti i default premendo Enter
# Passphrase opzionale (lascia vuoto per automazione)
```

#### **Copia Chiave sui Target**
```bash
# Per ogni server Linux
ssh-copy-id ansible@IP_SERVER_LINUX

# Esempio:
ssh-copy-id ansible@192.168.1.10
ssh-copy-id ansible@192.168.1.11
```

#### **Test Connessione**
```bash
# Test connessione senza password
ssh ansible@192.168.1.10

# Se funziona, esci
exit
```

### **3. Test con Ansible**
```bash
# Test ping Ansible
ansible all -i "192.168.1.10," -u ansible -m ping

# Output atteso:
# 192.168.1.10 | SUCCESS => {
#     "ansible_facts": {
#         "discovered_interpreter_python": "/usr/bin/python3"
#     },
#     "changed": false,
#     "ping": "pong"
# }
```

---

## 🪟 Configurazione Target Windows

### **1. Preparazione Server Windows**

#### **Installa Dipendenze Python (Sul Controller)**
```bash
# Installa moduli Python per Windows
pip install pywinrm[kerberos]

# Per autenticazione NTLM
pip install pywinrm[credssp]
```

#### **Crea Utente su Windows**
```powershell
# Su Windows target (PowerShell come Amministratore)
$Password = ConvertTo-SecureString "AnsibleP@ssw0rd!" -AsPlainText -Force
New-LocalUser -Name "ansible" -Password $Password -FullName "Ansible Service Account" -Description "Account for Ansible automation"

# Aggiungi a gruppo Administrators
Add-LocalGroupMember -Group "Administrators" -Member "ansible"

# Verifica
Get-LocalGroupMember -Group "Administrators"
```

### **2. Configurazione WinRM**

#### **Setup Automatico (Script Ufficiale)**
```powershell
# Su Windows target (PowerShell come Amministratore)
# Download e esecuzione script ufficiale Ansible
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
$file = "$env:temp\ConfigureRemotingForAnsible.ps1"
(New-Object -TypeName System.Net.WebClient).DownloadFile($url, $file)
powershell.exe -ExecutionPolicy ByPass -File $file
```

#### **Setup Manuale WinRM**
```powershell
# Su Windows target
# Abilita WinRM
Enable-PSRemoting -Force

# Configura WinRM per HTTP
winrm quickconfig -quiet
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'

# Abilita autenticazione Basic
winrm set winrm/config/service/auth '@{Basic="true"}'

# Permetti connessioni non criptate (solo per test)
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Configura firewall
New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow
```

### **3. Verifica WinRM**
```powershell
# Su Windows target
# Verifica configurazione
winrm enumerate winrm/config/listener

# Test locale
Test-WSMan -ComputerName localhost

# Mostra configurazione
winrm get winrm/config
```

### **4. Test da Controller Linux**
```bash
# Test connessione WinRM
python3 -c "
import winrm
session = winrm.Session('192.168.1.20:5985', auth=('ansible', 'AnsibleP@ssw0rd!'))
result = session.run_cmd('ipconfig')
print(result.std_out.decode())
"
```

---

## 📋 Creazione Inventory

### **Crea File Inventory**
```bash
# Crea directory
mkdir -p inventory

# Crea file hosts
cat > inventory/hosts.yml << 'EOF'
all:
  children:
    linux_servers:
      hosts:
        linux-web-01:
          ansible_host: 192.168.1.10
          ansible_user: ansible
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
        linux-db-01:
          ansible_host: 192.168.1.11
          ansible_user: ansible
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_become: true
        ansible_become_method: sudo
    
    windows_servers:
      hosts:
        win-web-01:
          ansible_host: 192.168.1.20
          ansible_user: ansible
          ansible_password: AnsibleP@ssw0rd!
        win-app-01:
          ansible_host: 192.168.1.21
          ansible_user: ansible
          ansible_password: AnsibleP@ssw0rd!
      vars:
        ansible_connection: winrm
        ansible_port: 5985
        ansible_winrm_transport: basic
        ansible_winrm_server_cert_validation: ignore
    
    development:
      children:
        - linux_servers
        - windows_servers
      vars:
        environment: dev
    
    production:
      children:
        - linux_servers
        - windows_servers
      vars:
        environment: prod
EOF
```

### **⚠️ Sicurezza Password**

> **ATTENZIONE**: Mai mettere password in chiaro nell'inventory!

#### **Usa Ansible Vault**
```bash
# Crea file vault per password
ansible-vault create group_vars/all/vault.yml

# Inserisci password (editor si aprirà):
vault_windows_password: AnsibleP@ssw0rd!
vault_database_password: MyDbP@ssw0rd!

# Salva e chiudi editor
```

#### **Aggiorna Inventory**
```yaml
# In inventory/hosts.yml sostituisci:
ansible_password: AnsibleP@ssw0rd!
# Con:
ansible_password: "{{ vault_windows_password }}"
```

---

## ✅ Test Completo Connettività

### **Test Linux**
```bash
# Test gruppo Linux
ansible linux_servers -m ping

# Test specifico host
ansible linux-web-01 -m ping

# Test con sudo
ansible linux_servers -m setup -a "filter=ansible_os_family"
```

### **Test Windows**
```bash
# Test gruppo Windows (senza vault)
ansible windows_servers -m win_ping

# Test con vault
ansible windows_servers -m win_ping --ask-vault-pass

# Test comandi Windows
ansible windows_servers -m win_command -a "ipconfig" --ask-vault-pass
```

### **Test Completo**
```bash
# Test tutti i server
ansible all -m ping --ask-vault-pass

# Raccolta informazioni dettagliate
ansible all -m setup --ask-vault-pass | head -50
```

---

## 🔧 Configurazioni Avanzate

### **Configurazione SSH Avanzata**

#### **Config SSH personalizzata**
```bash
# Crea file SSH config
mkdir -p ~/.ssh
cat > ~/.ssh/config << 'EOF'
# Configurazione per server Ansible
Host ansible-*
    User ansible
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ControlMaster auto
    ControlPath ~/.ssh/ansible-%h-%p-%r
    ControlPersist 10m

# Server specifici
Host linux-web-01
    HostName 192.168.1.10

Host linux-db-01
    HostName 192.168.1.11
EOF
```

### **Configurazione WinRM HTTPS**

#### **Setup Certificato (Windows Target)**
```powershell
# Crea certificato self-signed
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My -DnsName "$(hostname)"

# Configura listener HTTPS
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$(hostname)`";CertificateThumbprint=`"$($cert.Thumbprint)`"}"

# Configura firewall
New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow
```

#### **Aggiorna Inventory per HTTPS**
```yaml
windows_servers:
  vars:
    ansible_connection: winrm
    ansible_port: 5986
    ansible_winrm_transport: ssl
    ansible_winrm_server_cert_validation: ignore
```

---

## 🐛 Troubleshooting Installazione

### **Errori Comuni Linux**

#### **Errore: ansible command not found**
```bash
# Soluzione 1: Reinstalla
sudo apt remove ansible
sudo apt install ansible

# Soluzione 2: Verifica PATH
echo $PATH
which ansible

# Soluzione 3: Usa full path
/usr/bin/ansible --version
```

#### **Errore: SSH Permission denied**
```bash
# Debug SSH
ssh -vvv ansible@target-host

# Verifica chiavi
ls -la ~/.ssh/
ssh-add -l

# Ricopia chiave
ssh-copy-id -f ansible@target-host
```

### **Errori Comuni Windows**

#### **Errore: Connection timeout**
```bash
# Test porta WinRM
telnet windows-host 5985

# Test con Python
python3 -c "
import socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
result = sock.connect_ex(('192.168.1.20', 5985))
print('Open' if result == 0 else 'Closed')
sock.close()
"
```

#### **Errore: 401 Unauthorized**
```powershell
# Su Windows target - verifica utente
Get-LocalUser ansible
Get-LocalGroupMember -Group "Administrators"

# Reset password
$Password = ConvertTo-SecureString "NewP@ssw0rd!" -AsPlainText -Force
Set-LocalUser -Name "ansible" -Password $Password
```

---

## ✅ Checklist Installazione

Prima di procedere al Capitolo 3, verifica:

### **Controller** 🎮
- [ ] Ansible installato e funzionante (`ansible --version`)
- [ ] File `ansible.cfg` configurato
- [ ] Directory progetto creata
- [ ] Moduli Python Windows installati (`pywinrm`)

### **Linux Targets** 🐧
- [ ] Utente `ansible` creato con sudo
- [ ] SSH keys configurate
- [ ] Connessione SSH senza password funzionante
- [ ] Test `ansible linux_servers -m ping` success

### **Windows Targets** 🪟
- [ ] Utente `ansible` con privilegi admin
- [ ] WinRM configurato e attivo
- [ ] Firewall configurato per porta 5985/5986
- [ ] Test `ansible windows_servers -m win_ping` success

### **Inventory** 📋
- [ ] File `inventory/hosts.yml` creato
- [ ] IP address corretti
- [ ] Credenziali configurate (preferibilmente con vault)
- [ ] Test `ansible all -m ping` success

---

## 🎓 Concetti Chiave Appresi

> **💡 SSH Keys**: Metodo più sicuro per autenticazione Linux
> 
> **💡 WinRM**: Protocollo per gestione remota Windows
> 
> **💡 Ansible Vault**: Sempre utilizzare per password sensibili
> 
> **💡 Inventory**: File centrale per definire i server da gestire

---

## 🔗 Prossimo Passo

Ottimo! Ora hai Ansible installato e configurato. Procedi al:
👉 [**Capitolo 3 - Primo Progetto**](03-primo-progetto.md)

Creerai il tuo primo playbook e eseguirai comandi Ansible sui server.
