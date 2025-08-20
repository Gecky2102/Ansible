# 📖 Capitolo 1 - Introduzione e Prerequisiti

> **🎯 In questo capitolo**: Capirai cos'è Ansible, come funziona e preparerai tutto il necessario per iniziare.

---

## 🤔 Cos'è Ansible?

**Ansible** è uno strumento di automazione IT che ti permette di:
- **Configurare server** automaticamente
- **Deployare applicazioni** su decine di server contemporaneamente  
- **Gestire configurazioni** in modo consistente
- **Orchestrare** operazioni complesse

### 🏗️ Perché Usare Ansible?

#### **Problemi Senza Automazione**
Immagina di dover:
- Installare nginx su 20 server Linux ➜ 20 connessioni SSH manuali
- Aggiornare un'applicazione su 10 server Windows ➜ 10 sessioni RDP
- Configurare firewall su 50 server ➜ 50 configurazioni manuali

**Risultato**: Ore di lavoro, errori umani, configurazioni inconsistenti.

#### **Soluzione con Ansible**
```bash
# Un comando, tutti i server configurati
ansible-playbook setup-servers.yml
```
**Risultato**: 5 minuti, zero errori, configurazione identica ovunque.

---

## 🏗️ Come Funziona Ansible

### **Architettura**

```
┌─────────────────┐    SSH/WinRM    ┌─────────────────┐
│   CONTROLLER    │ ──────────────► │   TARGET HOST   │
│   (Ansible)     │                 │   (Linux/Win)   │
│                 │                 │                 │
│ • Playbooks     │                 │ • Python        │
│ • Inventory     │                 │ • SSH/WinRM     │
│ • Vault         │                 │                 │
└─────────────────┘                 └─────────────────┘
```

### **Componenti Principali**

#### **1. Controller** 🎮
- **Cosa**: Il tuo computer dove installi Ansible
- **Ruolo**: Esegue i playbook e coordina tutto
- **OS**: Linux, macOS, Windows (WSL)

#### **2. Target Hosts** 🎯  
- **Cosa**: I server che vuoi gestire
- **Ruolo**: Ricevono ed eseguono i comandi
- **OS**: Linux, Windows, macOS, BSD, router, switch

#### **3. Inventory** 📋
- **Cosa**: Lista dei server da gestire
- **Formato**: File YAML o INI
- **Esempio**:
```yaml
webservers:
  hosts:
    web1.example.com:
    web2.example.com:
```

#### **4. Playbooks** 📜
- **Cosa**: "Ricette" che descrivono cosa fare
- **Formato**: File YAML
- **Esempio**:
```yaml
- name: Install nginx
  package:
    name: nginx
    state: present
```

#### **5. Modules** 🧩
- **Cosa**: Comandi predefiniti (installa pacchetti, copia file, etc.)
- **Esempi**: `package`, `copy`, `service`, `user`
- **Quantità**: 3000+ moduli disponibili

---

## 🔧 Prerequisiti Hardware

### **Controller Ansible**

| Risorsa | Minimo | Consigliato | Note |
|---------|--------|-------------|------|
| **RAM** | 1 GB | 4 GB | Più host = più RAM |
| **CPU** | 1 core | 2+ core | Parallelizzazione |
| **Disk** | 10 GB | 50 GB | Logs e backup |
| **Network** | 1 Mbps | 10+ Mbps | Trasferimento file |

### **Target Hosts**

| Sistema | RAM | CPU | Disk | Note |
|---------|-----|-----|------|------|
| **Linux** | 512 MB | 1 core | 5 GB | Python richiesto |
| **Windows** | 1 GB | 1 core | 10 GB | WinRM abilitato |

---

## 💻 Prerequisiti Software

### **Sul Controller**

#### **Sistemi Supportati** ✅
- ✅ **Linux** (Ubuntu, RHEL, CentOS, Debian, etc.)
- ✅ **macOS** (10.12+)
- ✅ **Windows** (WSL o Docker)
- ❌ **Windows nativo** (non supportato direttamente)

#### **Software Richiesto**
```bash
# Python 3.8+
python3 --version

# pip (package manager Python)
pip3 --version

# SSH client (già presente su Linux/macOS)
ssh -V

# Git (opzionale ma consigliato)
git --version
```

### **Sui Target Hosts**

#### **Linux Hosts** 🐧
```bash
# Python 3.6+ (di solito già presente)
python3 --version

# SSH server
sudo systemctl status ssh
# o su RHEL/CentOS:
sudo systemctl status sshd

# Sudo access per l'utente Ansible
sudo visudo
```

#### **Windows Hosts** 🪟
```powershell
# PowerShell 3.0+ (Windows 7+)
$PSVersionTable.PSVersion

# WinRM abilitato
winrm get winrm/config

# .NET Framework 4.0+
Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release
```

---

## 🌐 Prerequisiti Network

### **Porte Richieste**

| Protocollo | Porta | Direzione | Descrizione |
|------------|-------|-----------|-------------|
| **SSH** | 22 | Controller → Linux | Connessione SSH |
| **WinRM HTTP** | 5985 | Controller → Windows | WinRM non criptato |
| **WinRM HTTPS** | 5986 | Controller → Windows | WinRM criptato |

### **Connectivity Test**
```bash
# Test SSH (Linux)
ssh user@linux-host

# Test WinRM (Windows)
telnet windows-host 5985
```

---

## 🔐 Prerequisiti Sicurezza

### **Autenticazione Linux** 🔑

#### **Opzione 1: SSH Keys (Consigliata)**
```bash
# Genera chiave SSH
ssh-keygen -t rsa -b 4096 -C "ansible@controller"

# Copia chiave sul target
ssh-copy-id user@linux-host

# Test senza password
ssh user@linux-host
```

#### **Opzione 2: Password**
```bash
# Installa sshpass per password
sudo apt install sshpass  # Ubuntu/Debian
sudo yum install sshpass  # RHEL/CentOS
```

### **Autenticazione Windows** 🗝️

#### **Preparazione Account**
```powershell
# Crea utente locale (su Windows target)
$Password = Read-Host -AsSecureString
New-LocalUser "ansible" -Password $Password -FullName "Ansible User"
Add-LocalGroupMember -Group "Administrators" -Member "ansible"
```

#### **Configurazione WinRM**
```powershell
# Abilita WinRM (su Windows target)
Enable-PSRemoting -Force
winrm quickconfig -quiet
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
```

---

## 📁 Preparazione Ambiente

### **1. Crea Directory Progetto**
```bash
# Crea struttura base
mkdir ~/ansible-project
cd ~/ansible-project

# Crea sottocartelle
mkdir -p {inventory,playbooks,roles,group_vars,host_vars}
```

### **2. Setup Utenti Target**

#### **Linux Target**
```bash
# Sul server Linux target
sudo useradd -m -s /bin/bash ansible
sudo usermod -aG sudo ansible

# Configura sudo senza password
echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible
```

#### **Windows Target**
```powershell
# Sul server Windows target
# (Eseguito come Amministratore)
$SecurePassword = ConvertTo-SecureString "AnsiblePassword123!" -AsPlainText -Force
New-LocalUser -Name "ansible" -Password $SecurePassword -FullName "Ansible Service Account"
Add-LocalGroupMember -Group "Administrators" -Member "ansible"
```

---

## ✅ Checklist Pre-installazione

Prima di procedere al Capitolo 2, verifica di aver completato:

### **Controller Setup** 🎮
- [ ] Sistema operativo supportato (Linux/macOS/WSL)
- [ ] Python 3.8+ installato
- [ ] pip installato e funzionante
- [ ] SSH client disponibile
- [ ] Connessione internet attiva

### **Target Hosts Setup** 🎯
- [ ] **Linux**: SSH server attivo, utente con sudo
- [ ] **Windows**: WinRM configurato, utente amministratore
- [ ] Connettività di rete dal controller
- [ ] Firewall configurato per le porte necessarie

### **Network e Security** 🔐
- [ ] Porte 22 (SSH) e/o 5985/5986 (WinRM) aperte
- [ ] Chiavi SSH generate (per Linux)
- [ ] Credenziali di accesso valide
- [ ] Test di connettività eseguito

---

## 🎓 Concetti Chiave da Ricordare

> **💡 IMPORTANTE**: Ansible è **agentless** - non installa nulla sui server target

> **⚠️ ATTENZIONE**: Ansible su Windows richiede WSL o Linux/macOS come controller

> **✅ BEST PRACTICE**: Usa sempre chiavi SSH per Linux e utenti dedicati

---

## 🔗 Prossimo Passo

Ora che hai tutti i prerequisiti, procedi al:
👉 [**Capitolo 2 - Installazione e Configurazione**](02-installazione.md)

Imparerai come installare Ansible e configurare la connessione ai tuoi server.
