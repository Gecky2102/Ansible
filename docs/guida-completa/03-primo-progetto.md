# 🚀 Capitolo 3 - Primo Progetto

> **🎯 In questo capitolo**: Creerai il tuo primo progetto Ansible funzionante con playbook base per Linux e Windows.

---

## 📁 Struttura del Progetto

### **Organizzazione Consigliata**
```
ansible-project/
├── ansible.cfg                 # Configurazione Ansible
├── inventory/
│   ├── hosts.yml              # Definizione server
│   └── group_vars/
│       ├── all.yml            # Variabili globali
│       ├── linux_servers.yml  # Variabili Linux
│       └── windows_servers.yml # Variabili Windows
├── playbooks/
│   ├── site.yml               # Playbook principale
│   ├── linux_setup.yml       # Setup Linux
│   └── windows_setup.yml     # Setup Windows
├── roles/                     # Roles riutilizzabili (cap. 6)
├── group_vars/               # Variabili per gruppi
├── host_vars/                # Variabili per singoli host
├── files/                    # File statici
├── templates/                # Template Jinja2
└── vault/                    # File criptati
```

### **Crea Struttura Base**
```bash
cd ~/ansible-project

# Crea tutte le directory
mkdir -p {playbooks,roles,group_vars,host_vars,files,templates,vault}
mkdir -p inventory/group_vars

# Verifica struttura
tree . || ls -la
```

---

## 🔧 Configurazione Variabili

### **1. Variabili Globali**

#### **Crea group_vars/all.yml**
```bash
cat > group_vars/all.yml << 'EOF'
---
# Variabili globali per tutti i server

# Informazioni progetto
project_name: "my-infrastructure"
environment: "{{ env | default('development') }}"

# Timezone comune
timezone: "Europe/Rome"

# Utente per deployment
deploy_user: "deploy"

# Configurazioni di sicurezza
security_updates_enabled: true
firewall_enabled: true

# Logging
log_level: "INFO"

# Backup
backup_enabled: true
backup_retention_days: 7
EOF
```

### **2. Variabili Linux**

#### **Crea group_vars/linux_servers.yml**
```bash
cat > group_vars/linux_servers.yml << 'EOF'
---
# Variabili specifiche per server Linux

# Interprete Python
ansible_python_interpreter: /usr/bin/python3

# Privilege escalation
ansible_become: true
ansible_become_method: sudo

# Pacchetti base da installare
base_packages:
  - curl
  - wget
  - git
  - htop
  - vim
  - unzip
  - tree
  - net-tools

# Servizi da abilitare
base_services:
  - ssh
  - firewalld   # RHEL/CentOS
  - ufw         # Ubuntu (sarà ignorato su RHEL)

# Configurazioni sistema
max_open_files: 65536
swap_swappiness: 10

# Utenti di sistema
system_users:
  - name: "{{ deploy_user }}"
    groups: 
      - sudo    # Ubuntu/Debian
      - wheel   # RHEL/CentOS
    shell: /bin/bash
    create_home: true
EOF
```

### **3. Variabili Windows**

#### **Crea group_vars/windows_servers.yml**
```bash
cat > group_vars/windows_servers.yml << 'EOF'
---
# Variabili specifiche per server Windows

# Connessione WinRM
ansible_connection: winrm
ansible_port: 5985
ansible_winrm_transport: basic
ansible_winrm_server_cert_validation: ignore

# Funzionalità Windows da abilitare
windows_features:
  - IIS-WebServerRole
  - IIS-WebServer
  - IIS-CommonHttpFeatures
  - IIS-HttpRedirect

# Software da installare tramite Chocolatey
chocolatey_packages:
  - googlechrome
  - firefox
  - 7zip
  - notepadplusplus
  - git
  - python3

# Configurazioni Windows
windows_updates_enabled: "{{ security_updates_enabled }}"
windows_firewall_enabled: "{{ firewall_enabled }}"

# Servizi Windows
windows_services:
  - name: W3SVC
    state: started
    startup: auto
  - name: WinRM
    state: started
    startup: auto

# Directory applicazioni
apps_directory: "C:\\Apps"
logs_directory: "C:\\Logs"
EOF
```

---

## 📜 Primo Playbook

### **1. Playbook Linux Setup**

#### **Crea playbooks/linux_setup.yml**
```bash
cat > playbooks/linux_setup.yml << 'EOF'
---
- name: "Setup Base Server Linux"
  hosts: linux_servers
  become: true
  gather_facts: true
  
  vars:
    packages_to_install: "{{ base_packages }}"
    services_to_start: "{{ base_services }}"
    
  pre_tasks:
    - name: "Verifica connessione e raccolta informazioni"
      setup:
      tags: always
      
    - name: "Mostra informazioni server"
      debug:
        msg:
          - "Server: {{ inventory_hostname }}"
          - "OS: {{ ansible_distribution }} {{ ansible_distribution_version }}"
          - "Architettura: {{ ansible_architecture }}"
          - "IP: {{ ansible_default_ipv4.address }}"
      tags: always
  
  tasks:
    - name: "Aggiorna cache pacchetti (Debian/Ubuntu)"
      apt:
        update_cache: true
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"
      tags: packages
      
    - name: "Aggiorna cache pacchetti (RHEL/CentOS)"
      yum:
        update_cache: true
      when: ansible_os_family == "RedHat"
      tags: packages
      
    - name: "Installa pacchetti base"
      package:
        name: "{{ packages_to_install }}"
        state: present
      tags: packages
      
    - name: "Configura timezone"
      timezone:
        name: "{{ timezone }}"
      notify: restart_rsyslog
      tags: system
      
    - name: "Crea utente di deployment"
      user:
        name: "{{ deploy_user }}"
        groups: "{{ system_users[0].groups }}"
        shell: "{{ system_users[0].shell }}"
        create_home: "{{ system_users[0].create_home }}"
        state: present
      tags: users
      
    - name: "Configura sudoers per utente deploy"
      lineinfile:
        path: "/etc/sudoers.d/{{ deploy_user }}"
        create: true
        line: "{{ deploy_user }} ALL=(ALL) NOPASSWD:ALL"
        mode: '0440'
        validate: 'visudo -cf %s'
      tags: users
      
    - name: "Configura limits per open files"
      lineinfile:
        path: /etc/security/limits.conf
        line: "* soft nofile {{ max_open_files }}"
        create: true
      tags: system
      
    - name: "Configura swappiness"
      sysctl:
        name: vm.swappiness
        value: "{{ swap_swappiness }}"
        state: present
        reload: true
      tags: system
      
    - name: "Abilita e avvia servizi base"
      systemd:
        name: "{{ item }}"
        enabled: true
        state: started
      loop: "{{ services_to_start }}"
      ignore_errors: true  # Alcuni servizi potrebbero non esistere
      tags: services
      
    - name: "Configura firewall base (UFW - Ubuntu)"
      ufw:
        rule: allow
        port: ssh
        state: enabled
      when: 
        - ansible_distribution == "Ubuntu"
        - firewall_enabled
      ignore_errors: true
      tags: firewall
      
    - name: "Configura firewall base (firewalld - RHEL/CentOS)"
      firewalld:
        service: ssh
        permanent: true
        state: enabled
        immediate: true
      when: 
        - ansible_os_family == "RedHat"
        - firewall_enabled
      ignore_errors: true
      tags: firewall
      
  handlers:
    - name: restart_rsyslog
      service:
        name: rsyslog
        state: restarted
        
  post_tasks:
    - name: "Verifica finale - Stato servizi"
      command: systemctl is-active ssh
      register: ssh_status
      changed_when: false
      tags: verify
      
    - name: "Report finale setup"
      debug:
        msg:
          - "✅ Setup Linux completato per {{ inventory_hostname }}"
          - "🔧 Pacchetti installati: {{ packages_to_install | length }}"
          - "👤 Utente deploy: {{ deploy_user }}"
          - "🕒 Timezone: {{ timezone }}"
          - "🔒 SSH attivo: {{ ssh_status.stdout }}"
      tags: always
EOF
```

### **2. Playbook Windows Setup**

#### **Crea playbooks/windows_setup.yml**
```bash
cat > playbooks/windows_setup.yml << 'EOF'
---
- name: "Setup Base Server Windows"
  hosts: windows_servers
  gather_facts: true
  
  vars:
    features_to_install: "{{ windows_features }}"
    packages_to_install: "{{ chocolatey_packages }}"
    
  pre_tasks:
    - name: "Verifica connessione WinRM"
      win_ping:
      tags: always
      
    - name: "Raccolta informazioni Windows"
      setup:
      tags: always
      
    - name: "Mostra informazioni server"
      debug:
        msg:
          - "Server: {{ inventory_hostname }}"
          - "OS: {{ ansible_os_name }}"
          - "Versione: {{ ansible_os_version }}"
          - "Architettura: {{ ansible_architecture }}"
          - "IP: {{ ansible_ip_addresses[0] | default('N/A') }}"
      tags: always
  
  tasks:
    - name: "Verifica e installa Chocolatey"
      win_chocolatey:
        name: chocolatey
        state: present
      tags: packages
      
    - name: "Installa pacchetti Chocolatey"
      win_chocolatey:
        name: "{{ item }}"
        state: present
      loop: "{{ packages_to_install }}"
      tags: packages
      
    - name: "Abilita funzionalità Windows"
      win_optional_feature:
        name: "{{ item }}"
        state: present
        include_parent: true
      loop: "{{ features_to_install }}"
      register: windows_features_result
      notify: reboot_if_required
      tags: features
      
    - name: "Configura timezone Windows"
      win_timezone:
        timezone: "{{ timezone }}"
      tags: system
      
    - name: "Crea directory applicazioni"
      win_file:
        path: "{{ apps_directory }}"
        state: directory
      tags: filesystem
      
    - name: "Crea directory logs"
      win_file:
        path: "{{ logs_directory }}"
        state: directory
      tags: filesystem
      
    - name: "Configura servizi Windows"
      win_service:
        name: "{{ item.name }}"
        state: "{{ item.state }}"
        start_mode: "{{ item.startup }}"
      loop: "{{ windows_services }}"
      tags: services
      
    - name: "Configura Windows Firewall per WinRM"
      win_firewall_rule:
        name: "WinRM HTTP"
        localport: 5985
        action: allow
        direction: in
        protocol: tcp
        state: present
      when: windows_firewall_enabled
      tags: firewall
      
    - name: "Configura Windows Firewall per HTTP"
      win_firewall_rule:
        name: "HTTP"
        localport: 80
        action: allow
        direction: in
        protocol: tcp
        state: present
      when: windows_firewall_enabled
      tags: firewall
      
    - name: "Installa Windows Updates (solo security)"
      win_updates:
        category_names:
          - SecurityUpdates
          - CriticalUpdates
        state: installed
        reboot: false
      when: windows_updates_enabled
      register: windows_updates_result
      tags: updates
      
  handlers:
    - name: reboot_if_required
      win_reboot:
        reboot_timeout: 600
        connect_timeout: 60
        pre_reboot_delay: 10
      when: windows_features_result.reboot_required | default(false)
        
  post_tasks:
    - name: "Verifica servizi Windows"
      win_service_info:
        name: "{{ item.name }}"
      loop: "{{ windows_services }}"
      register: services_status
      tags: verify
      
    - name: "Report finale setup"
      debug:
        msg:
          - "✅ Setup Windows completato per {{ inventory_hostname }}"
          - "📦 Pacchetti installati: {{ packages_to_install | length }}"
          - "🔧 Funzionalità abilitate: {{ features_to_install | length }}"
          - "📁 Directory create: {{ apps_directory }}, {{ logs_directory }}"
          - "🔄 Servizi configurati: {{ windows_services | length }}"
      tags: always
EOF
```

### **3. Playbook Master**

#### **Crea playbooks/site.yml**
```bash
cat > playbooks/site.yml << 'EOF'
---
# Playbook principale - esegue setup di tutti i server
- import_playbook: linux_setup.yml
  tags: 
    - linux
    - setup

- import_playbook: windows_setup.yml
  tags:
    - windows
    - setup

# Report finale di tutti i deployment
- name: "Report Finale Deployment"
  hosts: all
  gather_facts: false
  
  tasks:
    - name: "Report deployment completo"
      debug:
        msg:
          - "🎉 DEPLOYMENT COMPLETATO"
          - "📊 Server Linux gestiti: {{ groups['linux_servers'] | length }}"
          - "📊 Server Windows gestiti: {{ groups['windows_servers'] | length }}"
          - "🕒 Timestamp: {{ ansible_date_time.iso8601 }}"
          - "👤 Eseguito da: {{ ansible_user_id | default('ansible') }}"
      run_once: true
      tags: always
EOF
```

---

## 🧪 Test del Primo Progetto

### **1. Verifica Sintassi**
```bash
# Controlla sintassi di tutti i playbook
ansible-playbook --syntax-check playbooks/site.yml
ansible-playbook --syntax-check playbooks/linux_setup.yml
ansible-playbook --syntax-check playbooks/windows_setup.yml

# Output atteso:
# playbook: playbooks/site.yml
```

### **2. Dry Run (Simulazione)**
```bash
# Simula esecuzione senza modifiche
ansible-playbook playbooks/site.yml --check

# Solo Linux
ansible-playbook playbooks/linux_setup.yml --check

# Solo Windows (con vault se configurato)
ansible-playbook playbooks/windows_setup.yml --check --ask-vault-pass
```

### **3. Test su Singolo Host**
```bash
# Test su un solo server Linux
ansible-playbook playbooks/linux_setup.yml --limit linux-web-01

# Test su un solo server Windows
ansible-playbook playbooks/windows_setup.yml --limit win-web-01
```

### **4. Esecuzione Completa**
```bash
# Esecuzione completa (tutti i server)
ansible-playbook playbooks/site.yml

# Con vault password
ansible-playbook playbooks/site.yml --ask-vault-pass

# Solo specifici tag
ansible-playbook playbooks/site.yml --tags "packages,services"
```

---

## 📊 Monitoring e Logging

### **1. Verifica Log**
```bash
# Controlla log Ansible
tail -f ansible.log

# Cerca errori
grep ERROR ansible.log

# Filtra per host specifico
grep "linux-web-01" ansible.log
```

### **2. Comandi di Verifica**

#### **Linux**
```bash
# Verifica pacchetti installati
ansible linux_servers -m package -a "name=git state=present" --check

# Verifica servizi
ansible linux_servers -m service_facts

# Verifica utenti
ansible linux_servers -m getent -a "database=passwd key={{ deploy_user }}"

# Info sistema
ansible linux_servers -m setup -a "filter=ansible_distribution*"
```

#### **Windows**
```bash
# Verifica servizi Windows
ansible windows_servers -m win_service_info -a "name=W3SVC"

# Verifica software installato
ansible windows_servers -m win_command -a "choco list --local-only"

# Info sistema
ansible windows_servers -m setup -a "filter=ansible_os_*"
```

---

## 🎯 Primi Comandi Utili

### **Comandi Ad-Hoc Linux**
```bash
# Riavvia tutti i server Linux
ansible linux_servers -m reboot --become

# Verifica spazio disco
ansible linux_servers -m shell -a "df -h /"

# Aggiorna tutti i pacchetti
ansible linux_servers -m package -a "name='*' state=latest" --become

# Crea file temporaneo
ansible linux_servers -m file -a "path=/tmp/ansible_test state=touch" --become

# Copia file locale sui server
ansible linux_servers -m copy -a "src=./test.txt dest=/tmp/test.txt" --become
```

### **Comandi Ad-Hoc Windows**
```bash
# Riavvia server Windows
ansible windows_servers -m win_reboot

# Verifica spazio disco
ansible windows_servers -m win_command -a "dir c:\\"

# Info sistema
ansible windows_servers -m win_command -a "systeminfo"

# Crea directory
ansible windows_servers -m win_file -a "path=C:\Temp\ansible_test state=directory"

# Copia file sui server Windows
ansible windows_servers -m win_copy -a "src=./test.txt dest=C:\Temp\test.txt"
```

---

## 🐛 Troubleshooting Primo Progetto

### **Errori Comuni**

#### **Errore: "No hosts matched"**
```bash
# Verifica inventory
ansible-inventory --list

# Test connettività
ansible all -m ping

# Controlla nome gruppi nel playbook
grep "hosts:" playbooks/*.yml
```

#### **Errore: "Permission denied"**
```bash
# Linux - controlla chiavi SSH
ssh ansible@target-host

# Forza refresh chiavi
ssh-keygen -R target-host
ssh-copy-id ansible@target-host

# Windows - controlla credenziali
ansible windows_servers -m win_ping --ask-vault-pass
```

#### **Errore: "Module not found"**
```bash
# Verifica installazione Ansible
ansible --version
ansible-doc -l | grep win_

# Reinstalla se necessario
pip install --upgrade ansible
```

### **Debug Avanzato**
```bash
# Esecuzione con debug verboso
ansible-playbook playbooks/site.yml -vvv

# Debug specifico task
ansible-playbook playbooks/linux_setup.yml --start-at-task="Installa pacchetti base" -v

# Esecuzione step-by-step
ansible-playbook playbooks/site.yml --step
```

---

## ✅ Checklist Primo Progetto

Prima di procedere al Capitolo 4, verifica:

### **Struttura Progetto** 📁
- [ ] Directory del progetto organizzata correttamente
- [ ] File `ansible.cfg` configurato
- [ ] File variabili (`group_vars/*.yml`) creati
- [ ] Playbook (`playbooks/*.yml`) creati

### **Test Funzionalità** 🧪
- [ ] `ansible-playbook --syntax-check` passa per tutti i playbook
- [ ] `ansible-playbook --check` simula correttamente
- [ ] Esecuzione reale su almeno un server Linux
- [ ] Esecuzione reale su almeno un server Windows (se disponibile)

### **Verifica Risultati** ✅
- [ ] Pacchetti installati correttamente sui server
- [ ] Servizi avviati e configurati
- [ ] Utente deploy creato con privilegi corretti
- [ ] Log `ansible.log` contiene info di successo
- [ ] Comandi ad-hoc funzionano

---

## 🎓 Concetti Chiave Appresi

> **💡 Playbook**: File YAML che descrive le configurazioni desiderate
> 
> **💡 Tasks**: Singole operazioni da eseguire sui server
> 
> **💡 Handlers**: Tasks che vengono eseguiti solo quando notificati
> 
> **💡 Tags**: Etichette per eseguire subset di tasks
> 
> **💡 Variables**: Valori riutilizzabili definiti in file separati

---

## 🔗 Prossimo Passo

Eccellente! Hai creato e testato il tuo primo progetto Ansible funzionante. Procedi al:
👉 [**Capitolo 4 - Gestione Inventory e Variabili**](04-inventory-variabili.md)

Imparerai a gestire inventory complessi, variabili avanzate e Ansible Vault per la sicurezza.
