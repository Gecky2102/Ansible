# 📚 Appendice A - Riferimenti Rapidi

> **Scopo**: Quick reference per comandi, configurazioni e sintassi più utilizzati in Ansible.

## 🚀 Comandi Essenziali

### **Comandi Base**
```bash
# Test connettività
ansible all -m ping
ansible all -m ping -i inventory/hosts.yml

# Esecuzione playbook
ansible-playbook site.yml
ansible-playbook -i inventory/hosts.yml playbooks/site.yml

# Check mode (dry run)
ansible-playbook site.yml --check

# Verbose mode
ansible-playbook site.yml -v    # verbose
ansible-playbook site.yml -vv   # more verbose
ansible-playbook site.yml -vvv  # molto verbose

# Limitare l'esecuzione
ansible-playbook site.yml --limit webservers
ansible-playbook site.yml --limit 'webservers:!production'

# Tag specifici
ansible-playbook site.yml --tags "setup,config"
ansible-playbook site.yml --skip-tags "debug"

# Con extra variables
ansible-playbook site.yml -e "env=production debug=true"
ansible-playbook site.yml --extra-vars "@vars.yml"
```

### **Gestione Inventory**
```bash
# Lista host
ansible-inventory --list
ansible-inventory --list -i inventory/hosts.yml

# Host specifico
ansible-inventory --host webserver1

# Grafico delle relazioni
ansible-inventory --graph

# Validazione syntax
ansible-inventory --list --yaml
```

### **Vault (Crittografia)**
```bash
# Creare file criptato
ansible-vault create secrets.yml

# Editare file criptato
ansible-vault edit secrets.yml

# Visualizzare file criptato
ansible-vault view secrets.yml

# Criptare file esistente
ansible-vault encrypt plain_file.yml

# Decriptare file
ansible-vault decrypt secrets.yml

# Cambiare password vault
ansible-vault rekey secrets.yml

# Eseguire playbook con vault
ansible-playbook site.yml --ask-vault-pass
ansible-playbook site.yml --vault-password-file vault_pass.txt
```

### **Moduli Ad-Hoc**
```bash
# Gestione file
ansible all -m copy -a "src=/tmp/file dest=/tmp/file"
ansible all -m file -a "path=/tmp/test state=directory"

# Comandi shell
ansible all -m shell -a "uptime"
ansible all -m command -a "ls -la /tmp"

# Gestione pacchetti
ansible all -m package -a "name=htop state=present"
ansible all -m yum -a "name=httpd state=latest"

# Gestione servizi
ansible all -m service -a "name=httpd state=started enabled=yes"
ansible all -m systemd -a "name=nginx state=restarted"

# Raccolta facts
ansible all -m setup
ansible all -m setup -a "filter=ansible_*mb"

# Windows specifici
ansible windows -m win_ping
ansible windows -m win_shell -a "Get-Service"
ansible windows -m win_package -a "name=firefox state=present"
```

---

## 📝 Sintassi YAML

### **Struttura Base Playbook**
```yaml
---
- name: Playbook description
  hosts: target_hosts
  become: yes
  vars:
    variable_name: value
  
  tasks:
    - name: Task description
      module_name:
        parameter: value
        parameter2: value2
      register: result_var
      when: condition
      notify: handler_name
      tags: [tag1, tag2]

  handlers:
    - name: handler_name
      module_name:
        parameter: value
```

### **Variabili**
```yaml
# Semplici
app_name: myapp
app_port: 8080
debug_mode: true

# Liste
packages:
  - nginx
  - mysql-server
  - php

# Dizionari
database:
  host: localhost
  port: 3306
  name: myapp_db
  user: myapp_user

# Dizionari nidificati
environments:
  development:
    debug: true
    database:
      host: dev-db.local
  production:
    debug: false
    database:
      host: prod-db.local
```

### **Conditionals**
```yaml
# Condizioni semplici
- name: Install package
  package:
    name: nginx
  when: ansible_os_family == "Debian"

# Condizioni multiple (AND)
when: 
  - ansible_distribution == "Ubuntu"
  - ansible_distribution_version >= "18.04"

# Condizioni multiple (OR)
when: ansible_distribution == "Ubuntu" or ansible_distribution == "Debian"

# Condizioni complesse
when: (ansible_distribution == "Ubuntu" and ansible_distribution_version >= "18.04") or 
      (ansible_distribution == "CentOS" and ansible_distribution_major_version >= "7")

# Verificare se variabile è definita
when: my_variable is defined

# Verificare se variabile non è definita
when: my_variable is not defined

# Verificare se lista non è vuota
when: my_list | length > 0

# Verificare file esistente
when: ansible_stat.stat.exists
```

### **Loops**
```yaml
# Loop semplice
- name: Install packages
  package:
    name: "{{ item }}"
  loop:
    - nginx
    - mysql-server
    - php

# Loop con dizionari
- name: Create users
  user:
    name: "{{ item.name }}"
    group: "{{ item.group }}"
  loop:
    - { name: "alice", group: "admin" }
    - { name: "bob", group: "users" }

# Loop con variabili
- name: Process hosts
  debug:
    msg: "Processing {{ item }}"
  loop: "{{ groups['webservers'] }}"

# Loop con range
- name: Create directories
  file:
    path: "/tmp/dir{{ item }}"
    state: directory
  loop: "{{ range(1, 6) | list }}"  # 1,2,3,4,5

# Loop con condizioni
- name: Install packages
  package:
    name: "{{ item }}"
  loop: "{{ packages }}"
  when: item != "debug-package"
```

---

## ⚙️ Configurazioni

### **ansible.cfg Base**
```ini
[defaults]
# Inventory location
inventory = inventory/hosts.yml

# Logging
log_path = ansible.log

# SSH settings
host_key_checking = False
ssh_args = -o ControlMaster=auto -o ControlPersist=3600s

# Performance
forks = 50
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_fact_cache

# Privilege escalation
become = True
become_method = sudo
become_user = root

[ssh_connection]
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
```

### **Inventory Hosts Esempi**
```yaml
# inventory/hosts.yml
all:
  children:
    webservers:
      hosts:
        web1:
          ansible_host: 192.168.1.10
          ansible_user: ubuntu
        web2:
          ansible_host: 192.168.1.11
          ansible_user: ubuntu
      vars:
        app_port: 8080
        
    databases:
      hosts:
        db1:
          ansible_host: 192.168.1.20
          ansible_user: admin
          mysql_root_password: "{{ vault_mysql_password }}"
    
    production:
      children:
        webservers:
        databases:
      vars:
        environment: production
        
    development:
      hosts:
        dev-server:
          ansible_host: 192.168.1.100
      vars:
        environment: development
        debug: true
```

### **Group Variables Esempio**
```yaml
# group_vars/all.yml
---
# Common variables for all hosts
ansible_user: deploy
ansible_ssh_private_key_file: ~/.ssh/id_rsa

# Application settings
app_name: myapp
app_version: "1.0.0"
app_port: 8080

# Common packages
common_packages:
  - curl
  - wget
  - htop
  - vim

# Timezone
timezone: Europe/Rome
```

---

## 🔧 Template Jinja2

### **Sintassi Base**
```jinja2
{# Commento #}

{# Variabili #}
{{ variable_name }}
{{ dict.key }}
{{ list[0] }}

{# Escape HTML #}
{{ variable_name | e }}

{# Condizioni #}
{% if condition %}
  content
{% elif other_condition %}
  other content
{% else %}
  default content
{% endif %}

{# Loop #}
{% for item in list %}
  {{ item }}
{% endfor %}

{# Loop con indice #}
{% for item in list %}
  {{ loop.index }}: {{ item }}
{% endfor %}

{# Filtri comuni #}
{{ string_var | upper }}
{{ string_var | lower }}
{{ list_var | length }}
{{ number_var | round(2) }}
{{ date_var | strftime('%Y-%m-%d') }}
```

### **Template Configurazione Esempio**
```jinja2
{# templates/nginx.conf.j2 #}
server {
    listen {{ app_port }};
    server_name {{ ansible_fqdn }};
    
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    {% if ssl_enabled %}
    listen 443 ssl;
    ssl_certificate {{ ssl_cert_path }};
    ssl_certificate_key {{ ssl_key_path }};
    {% endif %}
}

upstream backend {
    {% for host in groups['webservers'] %}
    server {{ hostvars[host]['ansible_default_ipv4']['address'] }}:{{ backend_port }};
    {% endfor %}
}

# Environment: {{ environment }}
# Generated on: {{ ansible_date_time.iso8601 }}
```

---

## 🎯 Role Structure

### **Struttura Directory Standard**
```
roles/
  role_name/
    tasks/
      main.yml          # Task principali
    handlers/
      main.yml          # Handlers
    templates/
      config.j2         # Template Jinja2
    files/
      static_file       # File statici
    vars/
      main.yml          # Variabili del role
    defaults/
      main.yml          # Variabili di default
    meta/
      main.yml          # Metadati e dipendenze
```

### **Role Meta Example**
```yaml
# roles/webserver/meta/main.yml
---
dependencies:
  - role: common
    vars:
      common_packages:
        - nginx
        - openssl

galaxy_info:
  author: Your Name
  description: Web server configuration
  license: MIT
  min_ansible_version: 2.9
  platforms:
    - name: Ubuntu
      versions:
        - 18.04
        - 20.04
    - name: CentOS
      versions:
        - 7
        - 8
  galaxy_tags:
    - webserver
    - nginx
```

---

## 🔍 Debug e Troubleshooting

### **Debug Commands**
```yaml
# Debug semplice
- debug:
    msg: "Valore variabile: {{ my_var }}"

# Debug variabile completa
- debug:
    var: my_complex_var

# Debug condizionale
- debug:
    msg: "Debug mode attivo"
  when: debug_mode | default(false)

# Debug con facts
- debug:
    msg: |
      OS: {{ ansible_distribution }}
      IP: {{ ansible_default_ipv4.address }}
      Memory: {{ ansible_memtotal_mb }}MB

# Registrare output per debug
- command: ls -la /tmp
  register: ls_output

- debug:
    var: ls_output.stdout_lines
```

### **Comandi Troubleshooting**
```bash
# Aumentare verbosity
ansible-playbook site.yml -vvv

# Check syntax
ansible-playbook site.yml --syntax-check

# Dry run
ansible-playbook site.yml --check

# Step mode (interattivo)
ansible-playbook site.yml --step

# Start da task specifico
ansible-playbook site.yml --start-at-task="Install packages"

# Lista task
ansible-playbook site.yml --list-tasks

# Lista host
ansible-playbook site.yml --list-hosts

# Test connettività singolo host
ansible webserver1 -m ping -vvv

# Raccogliere facts per debug
ansible all -m setup | grep ansible_distribution
```

---

## 📊 Facts Ansible Utili

### **System Facts**
```yaml
# Sistema operativo
{{ ansible_distribution }}           # Ubuntu, CentOS, etc.
{{ ansible_distribution_version }}   # 20.04, 8.2, etc.
{{ ansible_os_family }}             # Debian, RedHat, etc.
{{ ansible_kernel }}                 # Versione kernel

# Hardware
{{ ansible_processor_count }}        # Numero CPU
{{ ansible_memtotal_mb }}           # RAM totale in MB
{{ ansible_architecture }}          # x86_64, etc.

# Network
{{ ansible_default_ipv4.address }}  # IP primario
{{ ansible_default_ipv4.gateway }}  # Gateway
{{ ansible_fqdn }}                  # FQDN completo
{{ ansible_hostname }}              # Hostname

# Storage
{{ ansible_mounts }}                # Punti di mount
{{ ansible_devices }}               # Dispositivi storage

# Date/Time
{{ ansible_date_time.iso8601 }}     # 2023-01-01T12:00:00Z
{{ ansible_date_time.date }}        # 2023-01-01
{{ ansible_date_time.time }}        # 12:00:00
```

### **Filtri Facts per Troubleshooting**
```bash
# Solo facts di rete
ansible all -m setup -a "filter=ansible_*ipv4*"

# Solo facts memoria
ansible all -m setup -a "filter=ansible_mem*"

# Solo facts disco
ansible all -m setup -a "filter=ansible_mounts"

# Facts customizzati
ansible all -m setup -a "filter=ansible_env"
```

---

## 🚨 Patterns Limitazione Host

### **Sintassi Patterns**
```bash
# Singolo host
ansible webserver1 -m ping

# Gruppo di host
ansible webservers -m ping

# Tutti gli host
ansible all -m ping

# Wildcard
ansible web*.example.com -m ping

# Range numerici
ansible web[1:5].example.com -m ping

# Lista esplicita
ansible web1,web2,db1 -m ping

# Intersezione (AND)
ansible 'webservers:&production' -m ping

# Esclusione (NOT)
ansible 'all:!databases' -m ping

# Combinazioni complesse
ansible 'webservers:&production:!maintenance' -m ping

# Regex
ansible '~web.*\.prod\..*' -m ping
```

---

## 🔐 Best Practices Security

### **SSH Security**
```bash
# Generare chiave SSH
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible_key

# Copiare chiave pubblica
ssh-copy-id -i ~/.ssh/ansible_key.pub user@server

# Test connessione
ssh -i ~/.ssh/ansible_key user@server

# SSH config per Ansible
# ~/.ssh/config
Host *.prod.company.com
    User deploy
    IdentityFile ~/.ssh/ansible_key
    StrictHostKeyChecking no
```

### **Vault Best Practices**
```bash
# Struttura file vault consigliata
group_vars/
  all/
    main.yml           # Variabili pubbliche
    vault.yml          # Variabili segrete (criptate)

# Nel main.yml referenziare vault
database_password: "{{ vault_database_password }}"
api_key: "{{ vault_api_key }}"

# File .gitignore
*.retry
vault_pass.txt
.vault_pass
```

---

## 📈 Performance Tips

### **Ottimizzazioni ansible.cfg**
```ini
[defaults]
# Più fork paralleli
forks = 50

# Cache facts
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/facts_cache
fact_caching_timeout = 86400

# SSH multiplexing
ssh_args = -o ControlMaster=auto -o ControlPersist=3600s

[ssh_connection]
# Pipeline comandi
pipelining = True

# Control path per SSH
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
```

### **Playbook Performance**
```yaml
# Disabilitare gather_facts se non necessario
- hosts: all
  gather_facts: false

# Usare async per task lunghi
- command: /long/running/command
  async: 300
  poll: 0

# Parallelismo con strategy
- hosts: all
  strategy: free  # Non aspettare altri host

# Limitare facts collection
- setup:
    filter: "ansible_*ipv4*"
```

---

Questa appendice fornisce un riferimento rapido per le operazioni più comuni con Ansible. Usa questi esempi come base per i tuoi playbook e configurazioni!
