# Ansible Infrastructure Automation

## Descrizione
Repository completo per l'automazione dell'infrastruttura e il deployment di applicazioni utilizzando Ansible. Supporta sia ambienti Linux che Windows con configurazione multi-piattaforma.

## Obiettivo
Realizzare un sistema di deployment automatizzato per la gestione delle applicazioni e configurazione dei server, riducendo i tempi di deployment manuale e migliorando la consistenza dell'ambiente.

## Prerequisiti

### Controller Ansible (Linux/WSL/macOS)
```bash
# Installa Ansible
pip install ansible

# Per Windows, installa anche pywinrm
pip install pywinrm[kerberos]
```

### Host Target Linux
```bash
# Installa Python e SSH
sudo apt update && sudo apt install python3 openssh-server
# oppure per RHEL/CentOS
sudo yum install python3 openssh-server

# Configura utente ansible con sudo
sudo useradd -m -s /bin/bash ansible
sudo usermod -aG sudo ansible
```

### Host Target Windows
```powershell
# Esegui lo script di setup WinRM
.\scripts\setup-winrm.ps1

# Oppure manualmente:
Enable-PSRemoting -Force
winrm quickconfig -q
```

## Configurazione Iniziale

### 1. Configura Inventory
Modifica `inventory/hosts.yml` con i tuoi server:

```yaml
all:
  children:
    linux_servers:
      hosts:
        web-server-01:
          ansible_host: 192.168.1.10
          ansible_user: ansible
    windows_servers:
      hosts:
        win-server-01:
          ansible_host: 192.168.1.20
          ansible_user: Administrator
```

### 2. Configura Variabili Criptate
```bash
# Crea file vault per password
ansible-vault create group_vars/all/vault.yml

# Aggiungi le password:
vault_windows_password: "TuaPasswordWindows"
vault_database_password: "TuaPasswordDB"
```

### 3. Test Connettività
```bash
# Test Linux
ansible linux_servers -m ping

# Test Windows  
ansible windows_servers -m win_ping
```

## Utilizzo

### Deployment Completo
```bash
# Linux/macOS
./scripts/deploy.sh production

# Windows
.\scripts\deploy.bat production

# PowerShell (con opzioni avanzate)
.\scripts\deploy.ps1 -Environment production -Tags all -Verbose
```

### Deployment Specifico per OS
```bash
# Solo Linux
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags linux

# Solo Windows
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags windows
```

### Deployment Applicazioni
```bash
# Deploy applicazione web
ansible-playbook -i inventory/hosts.yml playbooks/deploy_app.yml
```

### Modalità Dry Run
```bash
# Verifica modifiche senza applicarle
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --check

# Con PowerShell
.\scripts\deploy.ps1 -Environment development -DryRun
```

## Playbook Disponibili

### `site.yml` - Deployment Completo
Esegue setup base per tutti i server Linux e Windows.

**Tags disponibili:**
- `linux` - Solo configurazione Linux
- `windows` - Solo configurazione Windows  
- `setup` - Setup base completo

### `linux_setup.yml` - Configurazione Base Linux
- Aggiornamento pacchetti
- Installazione software comune
- Configurazione firewall
- Creazione utente deploy
- Configurazione timezone

### `windows_setup.yml` - Configurazione Base Windows
- Installazione Chocolatey
- Installazione software base
- Configurazione funzionalità Windows
- Configurazione Windows Updates
- Setup firewall

### `deploy_app.yml` - Deployment Applicazioni
- Download e deployment applicazioni
- Configurazione servizi
- Verifica health check
- Supporto rollback

## Role Disponibili

### `webserver`
Configura server web (Apache/IIS) per Linux e Windows:
- Installazione e configurazione web server
- Configurazione firewall per HTTP/HTTPS
- Gestione servizi

## Script di Utilità

### `deploy.sh` / `deploy.bat`
Script base per deployment rapido.

**Parametri:**
- `environment` - Ambiente target (development/production)
- `tags` - Tag specifici da eseguire

### `deploy.ps1`
Script PowerShell avanzato con opzioni complete.

**Parametri:**
- `-Environment` - Ambiente target
- `-Tags` - Tag da eseguire
- `-DryRun` - Modalità test senza modifiche
- `-Verbose` - Output dettagliato

### `setup-winrm.ps1`
Configura WinRM su host Windows per abilitare connessioni Ansible.

## Best Practices

### Sicurezza
- Usa sempre `ansible-vault` per password e chiavi
- Configura SSH key-based authentication per Linux
- Limita privilegi degli utenti di automazione
- Abilita firewall su tutti i server

### Gestione Inventory
- Organizza host per ambiente (dev/prod)
- Usa group_vars per configurazioni comuni
- Mantieni host_vars per configurazioni specifiche

### Deployment
- Testa sempre in ambiente di sviluppo prima
- Usa tag per deployment incrementali
- Implementa verifiche post-deployment
- Mantieni log per troubleshooting

### Monitoraggio
- Controlla log in `ansible.log`
- Verifica stato servizi dopo deployment
- Implementa health check per applicazioni

## Troubleshooting

### Errori Comuni Linux
```bash
# Problemi SSH
ssh-keygen -R <host_ip>

# Problemi sudo
ansible-playbook --ask-become-pass

# Problemi Python
ansible_python_interpreter=/usr/bin/python3
```

### Errori Comuni Windows
```powershell
# Verifica WinRM
Test-WSMan -ComputerName <host>

# Reset WinRM
winrm quickconfig -force

# Verifica firewall
netsh advfirewall firewall show rule name="WinRM-HTTP"
```

### Debug Ansible
```bash
# Aumenta verbosità
ansible-playbook -vvv

# Controlla sintassi
ansible-playbook --syntax-check

# Lista host
ansible-inventory --list
```

## 📚 Documentazione Completa

### Guide Disponibili

| Documento | Descrizione | Livello |
|-----------|-------------|---------|
| [**📖 Guida Completa**](docs/guida-completa/) | **Tutorial step-by-step dettagliato per tutti gli aspetti** | 🟢 Principiante |
| [⚡ Quick Start](docs/quick-start.md) | Setup rapido e comandi essenziali | 🟡 Intermedio |
| [🎯 Esempi e Template](docs/examples.md) | Template avanzati e configurazioni | 🔴 Avanzato |

### 🚀 **Per Iniziare Subito**
Se sei nuovo ad Ansible o vuoi una guida dettagliata passo-passo, inizia con la [**📖 Guida Completa**](docs/guida-completa/) che copre:

#### 📚 **Indice Guida Completa**
1. [**Introduzione e Prerequisiti**](docs/guida-completa/01-introduzione.md) - Cos'è Ansible, architettura, setup ambiente
2. [**Installazione e Configurazione**](docs/guida-completa/02-installazione.md) - Install su tutti gli OS, config SSH/WinRM  
3. [**Primo Progetto**](docs/guida-completa/03-primo-progetto.md) - Creazione progetto, primi playbook funzionanti
4. [**Inventory e Variabili**](docs/guida-completa/04-inventory-variabili.md) - Gestione avanzata host e configurazioni
5. [**Playbook e Tasks**](docs/guida-completa/05-playbook-tasks.md) - Tasks complessi, loop, conditionals, gestione errori
6. [**Roles e Template**](docs/guida-completa/06-roles-template.md) - Componenti riutilizzabili e template Jinja2

> **⏱️ Tempo stimato**: 10-16 ore per completare tutta la guida
> 
> **🎯 Risultato**: Sarai in grado di gestire infrastructure automation enterprise-ready

### 📋 **Checklist Rapida**
1. 📖 Leggi la [Guida Completa](docs/guida-completa/) per setup dettagliato
2. ⚡ Usa [Quick Start](docs/quick-start.md) per comandi rapidi  
3. 🎯 Consulta [Esempi](docs/examples.md) per configurazioni avanzate

## Estensioni Future

- [ ] Integrazione con CI/CD (Jenkins/GitLab)
- [ ] Monitoraggio con Prometheus/Grafana
- [ ] Backup automatizzato database
- [ ] Deployment container Docker/Kubernetes
- [ ] Integration testing automatizzato
- [ ] Notifiche Slack/Teams per deployment

## Supporto

### 🆘 Risoluzione Problemi
1. **Controlla i log** in `ansible.log`
2. **Consulta la [Guida Completa](docs/guida-completa/09-troubleshooting.md)** per problemi comuni
3. **Verifica configurazione** inventory e connettività
4. **Testa singoli comandi** con `ansible -m ping`

### 📞 Assistenza
- 📖 [Documentazione ufficiale Ansible](https://docs.ansible.com/)
- 🐛 [Issue tracker del progetto](../../issues)
- 💬 [Ansible Community](https://ansible.com/community)

## Licenza

Questo progetto è distribuito sotto licenza MIT. Vedi il file `LICENSE` per maggiori dettagli.

## Crediti

Questo progetto è stato sviluppato con ❤️ da [Gecky](https://github.com/Gecky2102)

## Star History

<details>
<summary>📊 Clicca per vedere il grafico </summary>
<br>

[![Star History Chart](https://api.star-history.com/svg?repos=Gecky2102/ansible-infrastructure&type=Date)](https://star-history.com/#Gecky2102/ansible-infrastructure&Date)

</details>