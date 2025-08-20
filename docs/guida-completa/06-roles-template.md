# 🎭 Capitolo 6 - Roles e Template

> **🎯 In questo capitolo**: Imparerai a creare roles riutilizzabili, gestire dipendenze e utilizzare template Jinja2 per configurazioni dinamiche.

---

## 🏗️ Introduzione ai Roles

### **Cos'è un Role**
Un role è una collezione organizzata di:
- **Tasks** - Operazioni da eseguire
- **Handlers** - Azioni trigger da notifiche
- **Variables** - Configurazioni specifiche
- **Templates** - File dinamici
- **Files** - File statici
- **Meta** - Metadati e dipendenze

### **Struttura Role**
```
roles/
└── webserver/
    ├── tasks/
    │   └── main.yml          # Task principali
    ├── handlers/
    │   └── main.yml          # Handlers
    ├── templates/
    │   ├── nginx.conf.j2     # Template Jinja2
    │   └── vhost.conf.j2
    ├── files/
    │   ├── ssl-cert.pem      # File statici
    │   └── favicon.ico
    ├── vars/
    │   └── main.yml          # Variabili del role
    ├── defaults/
    │   └── main.yml          # Valori default
    ├── meta/
    │   └── main.yml          # Metadati e dipendenze
    └── README.md             # Documentazione
```

---

## 🎯 Creazione del Primo Role

### **Generazione Role con ansible-galaxy**
```bash
# Crea struttura role automaticamente
cd roles/
ansible-galaxy init webserver

# Verifica struttura creata
tree webserver/
```

### **Role Webserver Completo**

#### **defaults/main.yml**
```yaml
---
# Valori default per il role webserver
webserver_package: nginx
webserver_service: nginx
webserver_port: 80
webserver_ssl_port: 443
webserver_user: www-data
webserver_group: www-data

# Configurazioni base
webserver_worker_processes: "{{ ansible_processor_vcpus }}"
webserver_worker_connections: 1024
webserver_keepalive_timeout: 65
webserver_client_max_body_size: "64m"

# SSL configuration
webserver_ssl_enabled: false
webserver_ssl_cert_path: "/etc/ssl/certs/{{ ansible_fqdn }}.crt"
webserver_ssl_key_path: "/etc/ssl/private/{{ ansible_fqdn }}.key"

# Virtual hosts
webserver_vhosts: []
# Esempio:
# webserver_vhosts:
#   - name: "example.com"
#     template: "vhost.conf.j2"
#     port: 80
#     document_root: "/var/www/example.com"

# Log configuration
webserver_access_log: "/var/log/nginx/access.log"
webserver_error_log: "/var/log/nginx/error.log"
webserver_log_level: "warn"

# Security headers
webserver_security_headers: true
webserver_server_tokens: "off"
```

#### **vars/main.yml**
```yaml
---
# Variabili OS-specific
webserver_packages:
  Debian: nginx
  RedHat: nginx
  
webserver_services:
  Debian: nginx
  RedHat: nginx
  
webserver_config_paths:
  Debian:
    config_file: "/etc/nginx/nginx.conf"
    sites_available: "/etc/nginx/sites-available"
    sites_enabled: "/etc/nginx/sites-enabled"
    conf_d: "/etc/nginx/conf.d"
  RedHat:
    config_file: "/etc/nginx/nginx.conf"
    sites_available: "/etc/nginx/conf.d"
    sites_enabled: "/etc/nginx/conf.d"
    conf_d: "/etc/nginx/conf.d"

webserver_users:
  Debian: www-data
  RedHat: nginx
```

#### **tasks/main.yml**
```yaml
---
# Main tasks per webserver role
- name: "Include OS-specific variables"
  include_vars: "{{ ansible_os_family }}.yml"
  failed_when: false
  tags: always

- name: "Set OS-specific facts"
  set_fact:
    webserver_package_name: "{{ webserver_packages[ansible_os_family] }}"
    webserver_service_name: "{{ webserver_services[ansible_os_family] }}"
    webserver_config: "{{ webserver_config_paths[ansible_os_family] }}"
    webserver_system_user: "{{ webserver_users[ansible_os_family] }}"
  tags: always

- name: "Include installation tasks"
  include_tasks: install.yml
  tags: 
    - webserver
    - install

- name: "Include configuration tasks"
  include_tasks: configure.yml
  tags:
    - webserver
    - configure

- name: "Include vhosts tasks"
  include_tasks: vhosts.yml
  when: webserver_vhosts | length > 0
  tags:
    - webserver
    - vhosts

- name: "Include SSL tasks"
  include_tasks: ssl.yml
  when: webserver_ssl_enabled | bool
  tags:
    - webserver
    - ssl

- name: "Ensure webserver is started and enabled"
  service:
    name: "{{ webserver_service_name }}"
    state: started
    enabled: true
  tags:
    - webserver
    - service
```

#### **tasks/install.yml**
```yaml
---
- name: "Update package cache (Debian/Ubuntu)"
  apt:
    update_cache: true
    cache_valid_time: 3600
  when: ansible_os_family == "Debian"

- name: "Install webserver package"
  package:
    name: "{{ webserver_package_name }}"
    state: present

- name: "Install additional packages"
  package:
    name: "{{ item }}"
    state: present
  loop:
    - openssl
    - curl
  when: webserver_ssl_enabled | bool

- name: "Create webserver directories"
  file:
    path: "{{ item }}"
    state: directory
    owner: root
    group: root
    mode: '0755'
  loop:
    - "{{ webserver_config.sites_available }}"
    - "{{ webserver_config.sites_enabled }}"
    - "/var/log/nginx"
    - "/var/cache/nginx"
```

#### **tasks/configure.yml**
```yaml
---
- name: "Template main nginx configuration"
  template:
    src: nginx.conf.j2
    dest: "{{ webserver_config.config_file }}"
    owner: root
    group: root
    mode: '0644'
    backup: true
  notify:
    - validate nginx configuration
    - restart nginx
  tags: config

- name: "Remove default site (Debian/Ubuntu)"
  file:
    path: "{{ webserver_config.sites_enabled }}/default"
    state: absent
  when: ansible_os_family == "Debian"
  notify: reload nginx

- name: "Create custom nginx configurations directory"
  file:
    path: "{{ webserver_config.conf_d }}/custom"
    state: directory
    mode: '0755'

- name: "Template security configuration"
  template:
    src: security.conf.j2
    dest: "{{ webserver_config.conf_d }}/custom/security.conf"
    mode: '0644'
  when: webserver_security_headers | bool
  notify: reload nginx

- name: "Configure log rotation"
  template:
    src: nginx_logrotate.j2
    dest: /etc/logrotate.d/nginx
    mode: '0644'
```

#### **tasks/vhosts.yml**
```yaml
---
- name: "Template virtual hosts"
  template:
    src: "{{ item.template | default('vhost.conf.j2') }}"
    dest: "{{ webserver_config.sites_available }}/{{ item.name }}"
    owner: root
    group: root
    mode: '0644'
    backup: true
  loop: "{{ webserver_vhosts }}"
  register: vhost_configs
  notify:
    - validate nginx configuration
    - reload nginx

- name: "Enable virtual hosts (Debian/Ubuntu)"
  file:
    src: "{{ webserver_config.sites_available }}/{{ item.name }}"
    dest: "{{ webserver_config.sites_enabled }}/{{ item.name }}"
    state: link
  loop: "{{ webserver_vhosts }}"
  when: ansible_os_family == "Debian"
  notify: reload nginx

- name: "Create document roots"
  file:
    path: "{{ item.document_root | default('/var/www/' + item.name) }}"
    state: directory
    owner: "{{ webserver_system_user }}"
    group: "{{ webserver_system_user }}"
    mode: '0755'
  loop: "{{ webserver_vhosts }}"

- name: "Create default index files"
  template:
    src: index.html.j2
    dest: "{{ item.document_root | default('/var/www/' + item.name) }}/index.html"
    owner: "{{ webserver_system_user }}"
    group: "{{ webserver_system_user }}"
    mode: '0644'
  loop: "{{ webserver_vhosts }}"
  when: item.create_index | default(true)
```

#### **handlers/main.yml**
```yaml
---
- name: validate nginx configuration
  command: nginx -t
  register: nginx_config_test
  failed_when: nginx_config_test.rc != 0
  changed_when: false

- name: restart nginx
  service:
    name: "{{ webserver_service_name }}"
    state: restarted
  when: nginx_config_test.rc == 0

- name: reload nginx
  service:
    name: "{{ webserver_service_name }}"
    state: reloaded
  when: nginx_config_test.rc == 0

- name: start nginx
  service:
    name: "{{ webserver_service_name }}"
    state: started
```

---

## 📄 Template Jinja2 Avanzati

### **Template nginx.conf.j2**
```nginx
# {{ ansible_managed }}
# Nginx configuration for {{ inventory_hostname }}
# Generated on {{ ansible_date_time.iso8601 }}

user {{ webserver_system_user }};
worker_processes {{ webserver_worker_processes }};
pid /run/nginx.pid;

events {
    worker_connections {{ webserver_worker_connections }};
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout {{ webserver_keepalive_timeout }};
    types_hash_max_size 2048;
    client_max_body_size {{ webserver_client_max_body_size }};
    
    {% if webserver_server_tokens == "off" %}
    server_tokens off;
    {% endif %}

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging Settings
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                   '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for"';
                   
    access_log {{ webserver_access_log }} main;
    error_log {{ webserver_error_log }} {{ webserver_log_level }};

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        application/atom+xml
        application/javascript
        application/json
        application/rss+xml
        application/vnd.ms-fontobject
        application/x-font-ttf
        application/x-web-app-manifest+json
        application/xhtml+xml
        application/xml
        font/opentype
        image/svg+xml
        image/x-icon
        text/css
        text/plain
        text/x-component;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=login:10m rate=10r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;

    # Include additional configurations
    include {{ webserver_config.conf_d }}/*.conf;
    include {{ webserver_config.sites_enabled }}/*;
}
```

### **Template vhost.conf.j2**
```nginx
# {{ ansible_managed }}
# Virtual Host: {{ item.name }}

{% set document_root = item.document_root | default('/var/www/' + item.name) %}
{% set port = item.port | default(webserver_port) %}
{% set ssl_enabled = item.ssl | default(webserver_ssl_enabled) %}

{% if ssl_enabled %}
# Redirect HTTP to HTTPS
server {
    listen {{ webserver_port }};
    server_name {{ item.name }}{% if item.aliases is defined %} {{ item.aliases | join(' ') }}{% endif %};
    return 301 https://$server_name$request_uri;
}

# HTTPS Server Block
server {
    listen {{ webserver_ssl_port }} ssl http2;
    server_name {{ item.name }}{% if item.aliases is defined %} {{ item.aliases | join(' ') }}{% endif %};
    
    # SSL Configuration
    ssl_certificate {{ item.ssl_cert | default(webserver_ssl_cert_path) }};
    ssl_certificate_key {{ item.ssl_key | default(webserver_ssl_key_path) }};
    
    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    
{% else %}
# HTTP Server Block
server {
    listen {{ port }};
    server_name {{ item.name }}{% if item.aliases is defined %} {{ item.aliases | join(' ') }}{% endif %};
{% endif %}

    # Document Root
    root {{ document_root }};
    index index.html index.htm{% if item.php | default(false) %} index.php{% endif %};

    # Access and Error Logs
    access_log /var/log/nginx/{{ item.name }}_access.log main;
    error_log /var/log/nginx/{{ item.name }}_error.log;

    # Basic Security
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    {% if item.php | default(false) %}
    # PHP Processing
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Security
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors on;
    }
    {% endif %}

    {% if item.locations is defined %}
    # Custom Locations
    {% for location in item.locations %}
    location {{ location.path }} {
        {% if location.proxy_pass is defined %}
        proxy_pass {{ location.proxy_pass }};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        {% endif %}
        
        {% if location.alias is defined %}
        alias {{ location.alias }};
        {% endif %}
        
        {% if location.return is defined %}
        return {{ location.return }};
        {% endif %}
        
        {% if location.extra_config is defined %}
        {{ location.extra_config | indent(8) }}
        {% endif %}
    }
    {% endfor %}
    {% endif %}

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Deny access to sensitive files
    location ~* \.(htaccess|htpasswd|ini|log|sh|sql|conf)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
```

### **Template per Configurazioni Condizionali**
```yaml
# templates/app_config.yml.j2
# {{ ansible_managed }}
# Application configuration for {{ inventory_hostname }}

application:
  name: {{ app_name }}
  version: {{ app_version }}
  environment: {{ environment }}
  
database:
{% if groups['databases'] is defined %}
  {% if database_cluster_mode | default(false) %}
  # Database cluster configuration
  cluster:
    enabled: true
    nodes:
    {% for host in groups['databases'] %}
      - host: {{ hostvars[host]['ansible_default_ipv4']['address'] }}
        port: {{ hostvars[host]['mysql_port'] | default(3306) }}
        role: {{ hostvars[host]['database_role'] | default('slave') }}
        weight: {{ hostvars[host]['database_weight'] | default(1) }}
    {% endfor %}
  {% else %}
  # Single database configuration
  host: {{ groups['databases'][0] }}
  port: {{ hostvars[groups['databases'][0]]['mysql_port'] | default(3306) }}
  {% endif %}
{% else %}
  # Local database configuration
  host: localhost
  port: 3306
{% endif %}
  name: {{ app_database_name }}
  user: {{ app_database_user }}
  password: {{ app_database_password }}
  
redis:
{% if groups['redis'] is defined %}
  {% for host in groups['redis'] %}
  - host: {{ hostvars[host]['ansible_default_ipv4']['address'] }}
    port: {{ hostvars[host]['redis_port'] | default(6379) }}
    {% if loop.first %}
    role: master
    {% else %}
    role: slave
    {% endif %}
  {% endfor %}
{% else %}
  host: localhost
  port: 6379
{% endif %}

# Feature flags based on environment
features:
  debug_mode: {{ debug_mode | default(false) }}
  profiling: {{ profiling_enabled | default(false) }}
  analytics: {{ analytics_enabled | default(true) }}
  maintenance_mode: {{ maintenance_mode | default(false) }}
  
# Load balancer configuration (only for LB hosts)
{% if 'loadbalancers' in group_names %}
load_balancer:
  algorithm: {{ lb_algorithm | default('round_robin') }}
  health_check:
    enabled: true
    path: {{ health_check_path | default('/health') }}
    interval: {{ health_check_interval | default(30) }}
    timeout: {{ health_check_timeout | default(5) }}
  backends:
  {% for host in groups['webservers'] %}
    - name: {{ host }}
      address: {{ hostvars[host]['ansible_default_ipv4']['address'] }}
      port: {{ hostvars[host]['app_port'] | default(8080) }}
      weight: {{ hostvars[host]['backend_weight'] | default(1) }}
      backup: {{ hostvars[host]['backup_server'] | default(false) }}
  {% endfor %}
{% endif %}

# Environment-specific settings
{% if environment == 'production' %}
logging:
  level: WARN
  file: /var/log/{{ app_name }}/production.log
  rotation: daily
  retention: 30

performance:
  cache_ttl: 3600
  connection_pool_size: 20
  worker_processes: {{ ansible_processor_vcpus }}
  
{% elif environment == 'staging' %}
logging:
  level: INFO
  file: /var/log/{{ app_name }}/staging.log
  rotation: daily
  retention: 7

performance:
  cache_ttl: 300
  connection_pool_size: 10
  worker_processes: {{ (ansible_processor_vcpus / 2) | int }}
  
{% else %}
logging:
  level: DEBUG
  file: /var/log/{{ app_name }}/development.log
  rotation: never
  retention: 3

performance:
  cache_ttl: 60
  connection_pool_size: 5
  worker_processes: 2
{% endif %}
```

---

## 🔗 Meta e Dipendenze

### **meta/main.yml**
```yaml
---
galaxy_info:
  author: "Your Name"
  description: "Nginx webserver configuration role"
  company: "Your Company"
  license: MIT
  min_ansible_version: 2.9
  
  platforms:
    - name: Ubuntu
      versions:
        - bionic
        - focal
        - jammy
    - name: EL
      versions:
        - 7
        - 8
        - 9
    - name: Debian
      versions:
        - buster
        - bullseye
        - bookworm
        
  galaxy_tags:
    - webserver
    - nginx
    - http
    - proxy
    - ssl

# Role dependencies
dependencies:
  - role: common
    vars:
      common_packages:
        - curl
        - wget
        - unzip
  - role: firewall
    when: webserver_firewall_enabled | default(true)
    vars:
      firewall_rules:
        - port: "{{ webserver_port }}"
          protocol: tcp
          rule: allow
        - port: "{{ webserver_ssl_port }}"
          protocol: tcp
          rule: allow
          when: "{{ webserver_ssl_enabled }}"

# Allow duplicate dependencies
allow_duplicates: false
```

---

## 🎭 Role Multipli e Dipendenze

### **Role Database con Dipendenze**
```bash
# Crea role database
ansible-galaxy init database

# meta/main.yml per database role
cat > roles/database/meta/main.yml << 'EOF'
---
dependencies:
  - role: common
  - role: firewall
    vars:
      firewall_ports:
        - 3306
        - 33060
  - role: monitoring
    when: monitoring_enabled | default(false)
EOF
```

### **Playbook con Role Multipli**
```yaml
# playbooks/full_stack_deployment.yml
- name: "Deploy Full Stack Application"
  hosts: all
  become: true
  
  roles:
    # Common configuration per tutti i server
    - role: common
      tags: common
      
    # Database servers
    - role: database
      when: "'databases' in group_names"
      vars:
        mysql_root_password: "{{ vault_mysql_root_password }}"
        mysql_databases:
          - name: "{{ app_database_name }}"
            encoding: utf8mb4
            collation: utf8mb4_unicode_ci
        mysql_users:
          - name: "{{ app_database_user }}"
            password: "{{ vault_app_database_password }}"
            priv: "{{ app_database_name }}.*:ALL"
            host: "%"
      tags: database
      
    # Web servers
    - role: webserver
      when: "'webservers' in group_names"
      vars:
        webserver_vhosts:
          - name: "{{ app_domain }}"
            document_root: "/var/www/{{ app_name }}"
            php: true
            ssl: "{{ ssl_enabled | default(false) }}"
            locations:
              - path: "/api"
                proxy_pass: "http://{{ groups['api_servers'][0] }}:{{ api_port }}"
              - path: "/static"
                alias: "/var/www/{{ app_name }}/static"
                extra_config: |
                  expires 1y;
                  add_header Cache-Control "public, immutable";
      tags: webserver
      
    # Load balancers
    - role: loadbalancer
      when: "'loadbalancers' in group_names"
      vars:
        lb_backend_servers: "{{ groups['webservers'] }}"
        lb_health_check_path: "/health"
      tags: loadbalancer
      
    # Monitoring
    - role: monitoring
      vars:
        monitoring_targets: "{{ groups['all'] }}"
      tags: monitoring
```

---

## 🔄 Role Condizionali e Dinamici

### **Role Selection Dinamico**
```yaml
# playbooks/dynamic_roles.yml
- name: "Deploy con Role Dinamici"
  hosts: all
  
  vars:
    # Mappa server_type -> roles
    server_roles_map:
      web:
        - common
        - webserver
        - monitoring
      db:
        - common
        - database
        - backup
        - monitoring
      lb:
        - common
        - loadbalancer
        - monitoring
      cache:
        - common
        - redis
        - monitoring
        
  tasks:
    - name: "Determina roles da applicare"
      set_fact:
        roles_to_apply: "{{ server_roles_map[server_type] | default(['common']) }}"
      when: server_type is defined
      
    - name: "Apply roles dinamicamente"
      include_role:
        name: "{{ item }}"
      loop: "{{ roles_to_apply }}"
      vars:
        # Passa variabili condizionali ai roles
        role_config: "{{ role_configs[item] | default({}) }}"
```

### **Role con Configurazioni Multiple**
```yaml
# group_vars/all.yml
role_configs:
  webserver:
    webserver_worker_processes: "{{ ansible_processor_vcpus }}"
    webserver_ssl_enabled: "{{ environment == 'production' }}"
    webserver_vhosts:
      - name: "{{ app_domain }}"
        port: 80
        ssl: "{{ environment == 'production' }}"
        
  database:
    mysql_innodb_buffer_pool_size: "{{ (ansible_memtotal_mb * 0.7) | int }}M"
    mysql_max_connections: "{{ mysql_connections_map[instance_size] | default(100) }}"
    mysql_slow_query_log: "{{ environment != 'production' }}"
    
  monitoring:
    prometheus_retention_time: "{{ retention_map[environment] | default('15d') }}"
    grafana_admin_password: "{{ vault_grafana_password }}"
    alert_manager_webhook: "{{ vault_slack_webhook }}"
```

---

## ✅ Checklist Roles e Template

Prima di procedere al Capitolo 7, verifica:

### **Role Structure** 🎭
- [ ] Role con struttura standard creato
- [ ] Tasks organizzati in file separati
- [ ] Defaults e vars configurati correttamente
- [ ] Handlers funzionanti
- [ ] Meta con dipendenze definite

### **Template Jinja2** 📄
- [ ] Template con logica condizionale
- [ ] Loop e filtri utilizzati correttamente
- [ ] Variabili magic integrate
- [ ] Template multi-environment funzionanti

### **Role Avanzati** 🔄
- [ ] Dipendenze tra role configurate
- [ ] Role condizionali implementati
- [ ] Configurazioni dinamiche funzionanti
- [ ] Role riutilizzabili in playbook multipli

### **Best Practices** ⭐
- [ ] Documentazione role completa
- [ ] Variabili con naming consistente
- [ ] Gestione errori implementata
- [ ] Test di validazione inclusi

---

## 🎓 Concetti Chiave Appresi

> **💡 Role Modularity**: Organizzazione del codice in componenti riutilizzabili
> 
> **💡 Template Logic**: Jinja2 per configurazioni dinamiche e condizionali
> 
> **💡 Role Dependencies**: Gestione automatica delle dipendenze tra role
> 
> **💡 Variable Hierarchy**: Precedenza tra defaults, vars e user variables
> 
> **💡 Dynamic Inclusion**: Include role basato su condizioni runtime

---

## 🔗 Prossimo Passo

Eccellente! Ora masterizzi roles e template come un professionista. Procedi al:
👉 [**Capitolo 7 - Deployment Applicazioni**](07-deployment.md)

Imparerai strategie di deployment avanzate, rolling updates, blue-green deployment e automazione CI/CD.
