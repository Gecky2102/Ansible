# 📋 Capitolo 4 - Gestione Inventory e Variabili

> **🎯 In questo capitolo**: Imparerai a gestire inventory complessi, organizzare variabili in modo scalabile e utilizzare Ansible Vault per la sicurezza.

---

## 🏗️ Inventory Avanzato

### **Strutture Inventory Complesse**

#### **Inventory Multi-Ambiente**
```bash
# Crea structure per multi-ambiente
mkdir -p inventory/{development,staging,production}

# Inventory Development
cat > inventory/development/hosts.yml << 'EOF'
all:
  children:
    webservers:
      hosts:
        dev-web-01:
          ansible_host: 192.168.1.10
          ansible_user: ansible
          server_role: frontend
          app_version: "1.0.0-dev"
        dev-web-02:
          ansible_host: 192.168.1.11
          ansible_user: ansible
          server_role: frontend
          app_version: "1.0.0-dev"
          
    databases:
      hosts:
        dev-db-01:
          ansible_host: 192.168.1.20
          ansible_user: ansible
          server_role: database
          mysql_port: 3306
          
    loadbalancers:
      hosts:
        dev-lb-01:
          ansible_host: 192.168.1.30
          ansible_user: ansible
          server_role: loadbalancer
          
  vars:
    environment: development
    domain_suffix: ".dev.mycompany.com"
    debug_mode: true
    log_level: debug
EOF

# Inventory Production
cat > inventory/production/hosts.yml << 'EOF'
all:
  children:
    webservers:
      hosts:
        prod-web-01:
          ansible_host: 10.0.1.10
          ansible_user: ansible
          server_role: frontend
          app_version: "1.2.5"
        prod-web-02:
          ansible_host: 10.0.1.11
          ansible_user: ansible
          server_role: frontend
          app_version: "1.2.5"
        prod-web-03:
          ansible_host: 10.0.1.12
          ansible_user: ansible
          server_role: frontend
          app_version: "1.2.5"
          
    databases:
      hosts:
        prod-db-01:
          ansible_host: 10.0.2.10
          ansible_user: ansible
          server_role: database
          mysql_port: 3306
          replication_role: master
        prod-db-02:
          ansible_host: 10.0.2.11
          ansible_user: ansible
          server_role: database
          mysql_port: 3306
          replication_role: slave
          
    loadbalancers:
      hosts:
        prod-lb-01:
          ansible_host: 10.0.3.10
          ansible_user: ansible
          server_role: loadbalancer
        prod-lb-02:
          ansible_host: 10.0.3.11
          ansible_user: ansible
          server_role: loadbalancer
          
  vars:
    environment: production
    domain_suffix: ".mycompany.com"
    debug_mode: false
    log_level: warning
EOF
```

#### **Inventory con Datacenter e Regioni**
```yaml
# inventory/production/hosts.yml (versione estesa)
all:
  children:
    # Raggruppamento per datacenter
    datacenter_east:
      children:
        east_webservers:
          hosts:
            east-web-01:
              ansible_host: 10.1.1.10
              datacenter: east
              rack: A01
            east-web-02:
              ansible_host: 10.1.1.11
              datacenter: east
              rack: A02
        east_databases:
          hosts:
            east-db-01:
              ansible_host: 10.1.2.10
              datacenter: east
              rack: B01
      vars:
        datacenter_location: "New York"
        backup_server: "10.1.100.10"
        
    datacenter_west:
      children:
        west_webservers:
          hosts:
            west-web-01:
              ansible_host: 10.2.1.10
              datacenter: west
              rack: C01
            west-web-02:
              ansible_host: 10.2.1.11
              datacenter: west
              rack: C02
        west_databases:
          hosts:
            west-db-01:
              ansible_host: 10.2.2.10
              datacenter: west
              rack: D01
      vars:
        datacenter_location: "Los Angeles"
        backup_server: "10.2.100.10"
        
    # Raggruppamento per funzione
    webservers:
      children:
        - east_webservers
        - west_webservers
      vars:
        app_port: 8080
        health_check_path: "/health"
        
    databases:
      children:
        - east_databases
        - west_databases
      vars:
        mysql_port: 3306
        backup_schedule: "2 AM daily"
```

### **Inventory Dinamico**

#### **Script Inventory Python**
```python
#!/usr/bin/env python3
# inventory/dynamic_inventory.py

import json
import argparse

def get_inventory():
    """Ritorna inventory dinamico"""
    inventory = {
        'webservers': {
            'hosts': ['web-01', 'web-02', 'web-03'],
            'vars': {
                'app_port': 8080,
                'health_check': True
            }
        },
        'databases': {
            'hosts': ['db-01', 'db-02'],
            'vars': {
                'mysql_port': 3306,
                'replication': True
            }
        },
        '_meta': {
            'hostvars': {
                'web-01': {
                    'ansible_host': '192.168.1.10',
                    'server_id': 1
                },
                'web-02': {
                    'ansible_host': '192.168.1.11',
                    'server_id': 2
                },
                'web-03': {
                    'ansible_host': '192.168.1.12',
                    'server_id': 3
                },
                'db-01': {
                    'ansible_host': '192.168.1.20',
                    'server_id': 10,
                    'replication_role': 'master'
                },
                'db-02': {
                    'ansible_host': '192.168.1.21',
                    'server_id': 11,
                    'replication_role': 'slave'
                }
            }
        }
    }
    return inventory

def get_host_vars(host):
    """Ritorna variabili per un host specifico"""
    inventory = get_inventory()
    return inventory['_meta']['hostvars'].get(host, {})

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--list', action='store_true', help='List all hosts')
    parser.add_argument('--host', help='Get host vars')
    args = parser.parse_args()
    
    if args.list:
        print(json.dumps(get_inventory(), indent=2))
    elif args.host:
        print(json.dumps(get_host_vars(args.host), indent=2))
```

```bash
# Rendi eseguibile
chmod +x inventory/dynamic_inventory.py

# Test inventory dinamico
./inventory/dynamic_inventory.py --list

# Usa con ansible
ansible-playbook -i inventory/dynamic_inventory.py playbooks/site.yml
```

---

## 🔧 Gestione Variabili Avanzata

### **Gerarchia Variabili**

Ansible applica le variabili in questo ordine (dal meno al più prioritario):

1. **Defaults dei role** (`roles/*/defaults/main.yml`)
2. **Group vars all** (`group_vars/all.yml`)
3. **Group vars specifici** (`group_vars/webservers.yml`)
4. **Host vars** (`host_vars/web-01.yml`)
5. **Facts di Ansible** (raccolti automaticamente)
6. **Variabili del playbook**
7. **Variabili della command line** (`-e var=value`)

#### **Esempio Pratico Gerarchia**
```bash
# 1. Default globali
cat > group_vars/all.yml << 'EOF'
app_port: 8080
app_environment: development
debug_enabled: true
EOF

# 2. Variabili per gruppo webservers
cat > group_vars/webservers.yml << 'EOF'
app_port: 80  # Override del default
nginx_workers: 4
ssl_enabled: false
EOF

# 3. Variabili per host specifico
mkdir -p host_vars
cat > host_vars/web-01.yml << 'EOF'
app_port: 8443  # Override per questo host
ssl_enabled: true  # Override per questo host
ssl_cert_path: "/etc/ssl/web-01.crt"
EOF
```

### **Variabili Calcolate e Magic Variables**

#### **Magic Variables di Ansible**
```yaml
# playbooks/debug_variables.yml
- name: "Debug Magic Variables"
  hosts: all
  gather_facts: true
  
  tasks:
    - name: "Mostra magic variables importanti"
      debug:
        msg:
          - "Host corrente: {{ inventory_hostname }}"
          - "IP host corrente: {{ ansible_default_ipv4.address | default('N/A') }}"
          - "Tutti gli host nel gruppo: {{ groups['webservers'] | default([]) }}"
          - "Tutti i gruppi: {{ group_names }}"
          - "Directory del playbook: {{ playbook_dir }}"
          - "Utente Ansible: {{ ansible_user }}"
          - "Sistema operativo: {{ ansible_os_family }}"
          - "Timestamp: {{ ansible_date_time.iso8601 }}"
          
    - name: "Iterazione su altri host del gruppo"
      debug:
        msg: "Host {{ item }} ha IP {{ hostvars[item]['ansible_default_ipv4']['address'] | default('unknown') }}"
      loop: "{{ groups['webservers'] | default([]) }}"
      when: item != inventory_hostname
```

#### **Variabili Calcolate**
```yaml
# group_vars/webservers.yml
# Calcola configurazioni basate su facts
nginx_worker_processes: "{{ ansible_processor_vcpus | default(2) }}"
nginx_worker_connections: "{{ (ansible_memtotal_mb | default(1024) / 4) | int }}"

# URL dinamiche basate su environment
api_base_url: "https://api{% if environment == 'development' %}-dev{% elif environment == 'staging' %}-staging{% endif %}.mycompany.com"

# Lista dinamica server database
database_servers: "{{ groups['databases'] | map('extract', hostvars, 'ansible_default_ipv4') | map(attribute='address') | list }}"

# Configurazione conditional
app_replicas: "{{ 3 if environment == 'production' else 1 }}"
```

### **Variabili da File Esterni**

#### **Caricamento da File YAML**
```bash
# Crea file con configurazioni complesse
cat > vars/application_config.yml << 'EOF'
database_config:
  development:
    host: "dev-db.internal"
    port: 3306
    name: "myapp_dev"
    pool_size: 5
  production:
    host: "prod-db.internal"
    port: 3306
    name: "myapp_prod"
    pool_size: 20
    
redis_config:
  development:
    host: "dev-redis.internal"
    port: 6379
    db: 0
  production:
    host: "prod-redis.internal"
    port: 6379
    db: 1
    
feature_flags:
  new_ui_enabled: "{{ environment == 'production' }}"
  debug_toolbar: "{{ environment != 'production' }}"
  analytics_enabled: true
EOF

# Usa nel playbook
cat > playbooks/app_config.yml << 'EOF'
- name: "Deploy Application with External Config"
  hosts: webservers
  vars_files:
    - "../vars/application_config.yml"
    
  tasks:
    - name: "Mostra configurazione database per environment"
      debug:
        var: database_config[environment]
        
    - name: "Template configurazione applicazione"
      template:
        src: app_config.j2
        dest: /opt/myapp/config.yml
        backup: true
      notify: restart_application
EOF
```

#### **Caricamento da File JSON**
```bash
# Crea configurazione JSON
cat > vars/servers_config.json << 'EOF'
{
  "load_balancer_config": {
    "algorithm": "round_robin",
    "health_check_interval": 30,
    "max_fails": 3,
    "backends": []
  },
  "monitoring_config": {
    "metrics_enabled": true,
    "log_level": "info",
    "alert_email": "ops@mycompany.com"
  }
}
EOF

# Usa nel playbook
- name: "Load JSON configuration"
  include_vars: "../vars/servers_config.json"
```

---

## 🔐 Ansible Vault Avanzato

### **Gestione Vault Multi-File**

#### **Struttura Vault Organizzata**
```bash
# Crea directory per vault files
mkdir -p vault/{development,staging,production}

# Vault per development
ansible-vault create vault/development/secrets.yml
```

Contenuto vault development:
```yaml
# Database passwords
vault_db_root_password: "DevRootP@ss123!"
vault_db_app_password: "DevAppP@ss456!"

# API Keys
vault_payment_api_key: "dev_pk_test_123456789"
vault_email_api_key: "dev_email_key_987654321"

# SSL certificates (paths)
vault_ssl_key_content: |
  -----BEGIN PRIVATE KEY-----
  MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAo...
  -----END PRIVATE KEY-----

vault_ssl_cert_content: |
  -----BEGIN CERTIFICATE-----
  MIIDXTCCAkWgAwIBAgIJAKoK/heBjcOuMA0GCSqGSIb3DQEB...
  -----END CERTIFICATE-----

# Service account credentials
vault_service_account_json: |
  {
    "type": "service_account",
    "project_id": "my-dev-project",
    "private_key_id": "123456789",
    "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
  }
```

#### **Vault per Production**
```bash
ansible-vault create vault/production/secrets.yml
```

```yaml
# Production secrets - passwords più complesse
vault_db_root_password: "ProdRootP@ssw0rd#2024!"
vault_db_app_password: "ProdAppP@ssw0rd#2024!"

# Production API keys
vault_payment_api_key: "prod_pk_live_realkey123456789"
vault_email_api_key: "prod_email_key_realkey987654321"

# Production SSL certificates
vault_ssl_key_content: |
  -----BEGIN PRIVATE KEY-----
  Real production private key content here...
  -----END PRIVATE KEY-----
```

### **Gestione Password Vault**

#### **File Password Vault**
```bash
# Crea file password per ogni environment
echo "development_vault_password" > ~/.ansible_vault_dev
echo "production_vault_password" > ~/.ansible_vault_prod

# Imposta permessi sicuri
chmod 600 ~/.ansible_vault_*

# Configura ansible.cfg per ogni environment
cat > inventory/development/ansible.cfg << 'EOF'
[defaults]
vault_password_file = ~/.ansible_vault_dev
inventory = hosts.yml
EOF

cat > inventory/production/ansible.cfg << 'EOF'
[defaults]
vault_password_file = ~/.ansible_vault_prod
inventory = hosts.yml
EOF
```

#### **Uso di Vault ID (Multiviault)**
```bash
# Crea vault con ID specifico
ansible-vault create --vault-id dev@~/.ansible_vault_dev vault/development/secrets.yml
ansible-vault create --vault-id prod@~/.ansible_vault_prod vault/production/secrets.yml

# Esegui playbook con vault specifico
ansible-playbook -i inventory/development/ --vault-id dev@~/.ansible_vault_dev playbooks/site.yml
```

### **Best Practices Vault**

#### **Separazione Dati Sensibili**
```bash
# File variabili pubbliche
cat > group_vars/all/main.yml << 'EOF'
# Configurazioni non sensibili
database_host: "{{ vault_database_host }}"
database_port: 3306
database_name: "myapp_{{ environment }}"
database_user: "{{ vault_database_user }}"
database_password: "{{ vault_database_password }}"

api_endpoint: "{{ vault_api_endpoint }}"
api_key: "{{ vault_api_key }}"

ssl_cert_path: "/etc/ssl/certs/app.crt"
ssl_key_path: "/etc/ssl/private/app.key"
EOF

# File variabili criptate
ansible-vault create group_vars/all/vault.yml
```

Contenuto group_vars/all/vault.yml:
```yaml
# Dati sensibili criptati
vault_database_host: "db.internal.company.com"
vault_database_user: "myapp_user"
vault_database_password: "SuperSecretP@ssw0rd!"

vault_api_endpoint: "https://api.internal.company.com"
vault_api_key: "sk_live_super_secret_api_key_123456789"
```

#### **Template per Gestione Secrets**
```bash
# Script per facilitare gestione vault
cat > scripts/vault_manager.sh << 'EOF'
#!/bin/bash

ENV=${1:-development}
ACTION=${2:-edit}

VAULT_FILE="vault/${ENV}/secrets.yml"
PASSWORD_FILE="~/.ansible_vault_${ENV}"

case $ACTION in
    "create")
        ansible-vault create --vault-password-file ${PASSWORD_FILE} ${VAULT_FILE}
        ;;
    "edit")
        ansible-vault edit --vault-password-file ${PASSWORD_FILE} ${VAULT_FILE}
        ;;
    "view")
        ansible-vault view --vault-password-file ${PASSWORD_FILE} ${VAULT_FILE}
        ;;
    "encrypt")
        ansible-vault encrypt --vault-password-file ${PASSWORD_FILE} ${VAULT_FILE}
        ;;
    "decrypt")
        ansible-vault decrypt --vault-password-file ${PASSWORD_FILE} ${VAULT_FILE}
        ;;
    *)
        echo "Usage: $0 <environment> <create|edit|view|encrypt|decrypt>"
        exit 1
        ;;
esac
EOF

chmod +x scripts/vault_manager.sh

# Uso del script
./scripts/vault_manager.sh development edit
./scripts/vault_manager.sh production view
```

---

## 🎯 Inventory e Variabili in Pratica

### **Playbook Multi-Environment**
```yaml
# playbooks/deploy_multi_env.yml
- name: "Deploy Multi-Environment Application"
  hosts: webservers
  vars_files:
    - "../vault/{{ environment }}/secrets.yml"
    - "../vars/application_config.yml"
    
  vars:
    app_config: "{{ database_config[environment] }}"
    current_timestamp: "{{ ansible_date_time.epoch }}"
    
  pre_tasks:
    - name: "Valida environment"
      fail:
        msg: "Environment {{ environment }} non supportato"
      when: environment not in ['development', 'staging', 'production']
      
    - name: "Mostra configurazione deployment"
      debug:
        msg:
          - "Environment: {{ environment }}"
          - "Host: {{ inventory_hostname }}"
          - "Database host: {{ app_config.host }}"
          - "Application replicas: {{ app_replicas }}"
          - "Debug mode: {{ debug_enabled }}"
          
  tasks:
    - name: "Template application configuration"
      template:
        src: app_config.j2
        dest: "/opt/myapp/config/{{ environment }}.yml"
        backup: true
        mode: '0640'
      vars:
        config_data:
          database:
            host: "{{ app_config.host }}"
            port: "{{ app_config.port }}"
            name: "{{ app_config.name }}"
            user: "{{ vault_database_user }}"
            password: "{{ vault_database_password }}"
          api:
            endpoint: "{{ vault_api_endpoint }}"
            key: "{{ vault_api_key }}"
          features:
            debug: "{{ debug_enabled }}"
            analytics: "{{ feature_flags.analytics_enabled }}"
      notify: restart_application
      
    - name: "Deploy SSL certificates"
      copy:
        content: "{{ item.content }}"
        dest: "{{ item.dest }}"
        mode: "{{ item.mode }}"
        backup: true
      loop:
        - content: "{{ vault_ssl_cert_content }}"
          dest: "{{ ssl_cert_path }}"
          mode: '0644'
        - content: "{{ vault_ssl_key_content }}"
          dest: "{{ ssl_key_path }}"
          mode: '0600'
      when: ssl_enabled | default(false)
      notify: restart_nginx
      
  handlers:
    - name: restart_application
      systemd:
        name: myapp
        state: restarted
        
    - name: restart_nginx
      systemd:
        name: nginx
        state: restarted
```

### **Template di Configurazione**
```bash
# templates/app_config.j2
# Application Configuration for {{ environment }}
# Generated on {{ ansible_date_time.iso8601 }}

database:
  host: {{ config_data.database.host }}
  port: {{ config_data.database.port }}
  name: {{ config_data.database.name }}
  user: {{ config_data.database.user }}
  password: {{ config_data.database.password }}
  pool_size: {{ app_config.pool_size }}

api:
  base_url: {{ config_data.api.endpoint }}
  api_key: {{ config_data.api.key }}
  timeout: {{ api_timeout | default(30) }}

features:
  debug_mode: {{ config_data.features.debug }}
  analytics: {{ config_data.features.analytics }}
  new_ui: {{ feature_flags.new_ui_enabled }}

server:
  port: {{ app_port }}
  workers: {{ nginx_worker_processes }}
  environment: {{ environment }}
  
# Environment specific settings
{% if environment == 'production' %}
logging:
  level: WARNING
  file: /var/log/myapp/production.log
{% else %}
logging:
  level: DEBUG
  file: /var/log/myapp/{{ environment }}.log
{% endif %}

# Load balancer backends (solo per load balancers)
{% if 'loadbalancers' in group_names %}
backends:
{% for host in groups['webservers'] %}
  - name: {{ host }}
    address: {{ hostvars[host]['ansible_default_ipv4']['address'] }}:{{ hostvars[host]['app_port'] | default(8080) }}
    weight: {{ hostvars[host]['lb_weight'] | default(1) }}
{% endfor %}
{% endif %}
```

---

## ✅ Checklist Inventory e Variabili

Prima di procedere al Capitolo 5, verifica:

### **Inventory** 📋
- [ ] Inventory multi-environment configurato
- [ ] Raggruppamenti logici (webservers, databases, etc.)
- [ ] Host vars e group vars organizzati
- [ ] Magic variables comprese e utilizzate

### **Variabili** 🔧
- [ ] Gerarchia variabili compresa
- [ ] Variabili calcolate implementate
- [ ] File esterni (YAML/JSON) utilizzati
- [ ] Template con variabili funzionanti

### **Vault** 🔐
- [ ] Vault multi-environment configurato
- [ ] Password vault sicure e separate
- [ ] Secrets separati da configurazioni pubbliche
- [ ] Script di gestione vault funzionanti

### **Test** 🧪
- [ ] Deploy multi-environment testato
- [ ] Template generano configurazioni corrette
- [ ] Vault decryption funzionante
- [ ] Variabili risolte correttamente

---

## 🎓 Concetti Chiave Appresi

> **💡 Inventory Dinamico**: Genera host lists automaticamente da fonti esterne
> 
> **💡 Gerarchia Variabili**: Priorità delle variabili dalla meno alla più specifica
> 
> **💡 Magic Variables**: Variabili speciali di Ansible per accedere a metadati
> 
> **💡 Vault Multi-Environment**: Gestione sicura di secrets per ogni ambiente
> 
> **💡 Template Jinja2**: Generazione dinamica di file di configurazione

---

## 🔗 Prossimo Passo

Ottimo lavoro! Ora gestisci inventory e variabili come un professionista. Procedi al:
👉 [**Capitolo 5 - Playbook e Tasks**](05-playbook-tasks.md)

Imparerai a creare playbook complessi con task avanzati, loop, conditionals e gestione errori.
