# 📜 Capitolo 5 - Playbook e Tasks

> **🎯 In questo capitolo**: Imparerai a creare playbook complessi con task avanzati, loop, conditionals, gestione errori e handlers.

---

## 🏗️ Anatomia di un Playbook

### **Struttura Completa Playbook**
```yaml
---
# playbooks/advanced_playbook.yml
- name: "Playbook Avanzato - Esempio Completo"
  hosts: webservers
  become: true
  gather_facts: true
  serial: 2  # Esegui su 2 host alla volta
  max_fail_percentage: 10  # Fallisci se più del 10% hosts fallisce
  
  # Variabili del playbook
  vars:
    app_name: "mywebapp"
    app_version: "2.1.0"
    app_port: 8080
    
  # File variabili esterne
  vars_files:
    - "../vars/app_config.yml"
    
  # Prompt per variabili runtime
  vars_prompt:
    - name: deployment_reason
      prompt: "Motivo del deployment"
      private: false
      default: "Deployment automatico"
      
  # Task che vengono eseguiti prima del resto
  pre_tasks:
    - name: "Validazione pre-deployment"
      debug:
        msg: "Inizio deployment {{ app_name }} v{{ app_version }} su {{ inventory_hostname }}"
      tags: always
      
  # Roles da includere
  roles:
    - role: common
      tags: basic
    - role: webserver
      tags: web
      
  # Task principali
  tasks:
    - name: "Task principale - Deploy applicazione"
      debug:
        msg: "Esecuzione task principali"
      tags: deploy
      
  # Task che vengono eseguiti dopo tutto il resto
  post_tasks:
    - name: "Verifica finale deployment"
      uri:
        url: "http://{{ ansible_default_ipv4.address }}:{{ app_port }}/health"
        method: GET
        status_code: 200
      retries: 5
      delay: 10
      tags: verify
      
  # Handlers per restart servizi
  handlers:
    - name: restart_nginx
      service:
        name: nginx
        state: restarted
        
    - name: restart_application
      systemd:
        name: "{{ app_name }}"
        state: restarted
```

---

## 🎯 Tasks Avanzati

### **Task con Conditionals**

#### **Conditionals Basici**
```yaml
# playbooks/conditionals_example.yml
- name: "Esempi Conditionals"
  hosts: all
  
  tasks:
    - name: "Installa Apache su Debian/Ubuntu"
      apt:
        name: apache2
        state: present
      when: ansible_os_family == "Debian"
      
    - name: "Installa Apache su RHEL/CentOS"
      yum:
        name: httpd
        state: present
      when: ansible_os_family == "RedHat"
      
    - name: "Configura Apache solo su web servers"
      template:
        src: apache.conf.j2
        dest: /etc/apache2/apache2.conf
      when: 
        - ansible_os_family == "Debian"
        - "'webservers' in group_names"
      notify: restart_apache
      
    - name: "Task per environment production"
      debug:
        msg: "Configurazione production attiva"
      when: environment == "production"
      
    - name: "Task condizionale complesso"
      package:
        name: "{{ item }}"
        state: present
      loop:
        - nginx
        - php-fpm
      when: 
        - install_web_stack | default(false)
        - ansible_distribution_major_version | int >= 8
        - ansible_memtotal_mb > 1024
```

#### **Conditionals con Variabili Complesse**
```yaml
tasks:
  - name: "Registra stato servizio"
    service_facts:
    
  - name: "Avvia servizio solo se non è attivo"
    service:
      name: nginx
      state: started
    when: ansible_facts.services["nginx.service"].state != "running"
    
  - name: "Configura database solo su master"
    mysql_db:
      name: "{{ app_db_name }}"
      state: present
    when: 
      - database_role is defined
      - database_role == "master"
      - ansible_facts.services["mysql.service"].state == "running"
      
  - name: "Task basato su risultato precedente"
    debug:
      msg: "Database creato con successo"
    when: database_creation_result is succeeded
```

### **Loops Avanzati**

#### **Loop Base**
```yaml
tasks:
  - name: "Installa pacchetti multipli"
    package:
      name: "{{ item }}"
      state: present
    loop:
      - nginx
      - mysql-client
      - python3-pip
      - git
      
  - name: "Crea directory multiple"
    file:
      path: "{{ item }}"
      state: directory
      mode: '0755'
    loop:
      - /opt/app
      - /var/log/app
      - /etc/app/conf.d
      - /var/lib/app/data
```

#### **Loop con Dizionari**
```yaml
tasks:
  - name: "Crea utenti con configurazioni specifiche"
    user:
      name: "{{ item.name }}"
      groups: "{{ item.groups | default([]) }}"
      shell: "{{ item.shell | default('/bin/bash') }}"
      create_home: "{{ item.create_home | default(true) }}"
      state: present
    loop:
      - name: webuser
        groups: ["www-data", "deploy"]
        shell: /bin/bash
      - name: dbuser
        groups: ["mysql"]
        shell: /bin/nologin
        create_home: false
      - name: monitoruser
        groups: ["monitoring"]
        
  - name: "Configura virtual hosts"
    template:
      src: "{{ item.template }}"
      dest: "/etc/nginx/sites-available/{{ item.name }}"
    loop:
      - name: webapp
        template: webapp.conf.j2
        port: 80
        ssl: false
      - name: api
        template: api.conf.j2
        port: 443
        ssl: true
    notify: reload_nginx
```

#### **Loop con Filtri**
```yaml
tasks:
  - name: "Loop su hosts di un gruppo specifico"
    debug:
      msg: "Configurando {{ item }} con IP {{ hostvars[item]['ansible_default_ipv4']['address'] }}"
    loop: "{{ groups['databases'] }}"
    when: hostvars[item]['database_role'] == 'master'
    
  - name: "Loop su file che matchano pattern"
    file:
      path: "{{ item }}"
      state: absent
    with_fileglob:
      - "/tmp/old_logs/*.log"
      - "/var/cache/app/*.cache"
      
  - name: "Loop su range numerico"
    debug:
      msg: "Worker process {{ item }}"
    loop: "{{ range(1, worker_processes + 1) | list }}"
    
  - name: "Loop su combinazioni (prodotto cartesiano)"
    debug:
      msg: "Backup {{ item.0 }} to {{ item.1 }}"
    loop: "{{ databases | product(backup_servers) | list }}"
```

### **Gestione Errori e Rescue**

#### **Task con Gestione Errori**
```yaml
# playbooks/error_handling.yml
- name: "Gestione Errori Avanzata"
  hosts: webservers
  
  tasks:
    - name: "Block con gestione errori"
      block:
        - name: "Download applicazione"
          get_url:
            url: "https://releases.example.com/app-{{ app_version }}.tar.gz"
            dest: "/tmp/app-{{ app_version }}.tar.gz"
            timeout: 30
            
        - name: "Verifica checksum"
          stat:
            path: "/tmp/app-{{ app_version }}.tar.gz"
            checksum_algorithm: sha256
          register: downloaded_file
          
        - name: "Estrai applicazione"
          unarchive:
            src: "/tmp/app-{{ app_version }}.tar.gz"
            dest: "/opt/app"
            remote_src: true
            creates: "/opt/app/version.txt"
            
      rescue:
        - name: "Log errore download"
          debug:
            msg: "Errore durante download o estrazione applicazione"
            
        - name: "Notifica team operations"
          mail:
            to: ops@company.com
            subject: "Deployment fallito su {{ inventory_hostname }}"
            body: "Errore durante deployment applicazione versione {{ app_version }}"
          delegate_to: localhost
          
        - name: "Rollback a versione precedente"
          command: /opt/app/scripts/rollback.sh
          register: rollback_result
          
        - name: "Fallisci se rollback non funziona"
          fail:
            msg: "Rollback fallito: {{ rollback_result.stderr }}"
          when: rollback_result.rc != 0
          
      always:
        - name: "Cleanup file temporanei"
          file:
            path: "/tmp/app-{{ app_version }}.tar.gz"
            state: absent
            
        - name: "Log fine operazione"
          debug:
            msg: "Operazione completata su {{ inventory_hostname }}"
```

#### **Retry e Until**
```yaml
tasks:
  - name: "Attendi che il servizio sia disponibile"
    uri:
      url: "http://{{ inventory_hostname }}:{{ app_port }}/health"
      method: GET
      status_code: 200
    register: health_check
    until: health_check.status == 200
    retries: 30
    delay: 10
    
  - name: "Attendi che il database sia ready"
    mysql_info:
      login_host: "{{ db_host }}"
      login_user: "{{ db_user }}"
      login_password: "{{ db_password }}"
    register: db_status
    until: db_status is succeeded
    retries: 10
    delay: 5
    
  - name: "Download con retry automatico"
    get_url:
      url: "{{ download_url }}"
      dest: "{{ download_path }}"
    register: download_result
    until: download_result is succeeded
    retries: 3
    delay: 5
```

---

## 🔄 Handlers Avanzati

### **Handlers con Conditionals**
```yaml
# playbooks/advanced_handlers.yml
- name: "Esempio Handlers Avanzati"
  hosts: webservers
  
  tasks:
    - name: "Modifica configurazione nginx"
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        backup: true
      notify: 
        - validate_nginx_config
        - restart_nginx
        
    - name: "Modifica configurazione SSL"
      template:
        src: ssl.conf.j2
        dest: /etc/nginx/conf.d/ssl.conf
      notify: 
        - validate_nginx_config
        - reload_nginx
      when: ssl_enabled | default(false)
      
  handlers:
    - name: validate_nginx_config
      command: nginx -t
      register: nginx_validation
      failed_when: nginx_validation.rc != 0
      listen: "validate nginx"
      
    - name: restart_nginx
      service:
        name: nginx
        state: restarted
      when: nginx_validation is succeeded
      listen: "restart nginx"
      
    - name: reload_nginx
      service:
        name: nginx
        state: reloaded
      when: 
        - nginx_validation is succeeded
        - not ansible_check_mode
        
    # Handler con multiple azioni
    - name: restart_web_stack
      block:
        - name: "Stop nginx"
          service:
            name: nginx
            state: stopped
            
        - name: "Restart php-fpm"
          service:
            name: php-fpm
            state: restarted
            
        - name: "Start nginx"
          service:
            name: nginx
            state: started
```

### **Handlers con Notifiche Multiple**
```yaml
tasks:
  - name: "Update configurazione completa"
    template:
      src: "{{ item.src }}"
      dest: "{{ item.dest }}"
    loop:
      - src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      - src: app.conf.j2
        dest: /etc/app/app.conf
      - src: logrotate.conf.j2
        dest: /etc/logrotate.d/app
    notify:
      - restart_nginx
      - restart_app
      - restart_rsyslog
      
handlers:
  # Sequenza restart con dipendenze
  - name: restart_app
    service:
      name: myapp
      state: restarted
    notify: verify_app_health
    
  - name: verify_app_health
    uri:
      url: "http://localhost:{{ app_port }}/health"
      status_code: 200
    retries: 5
    delay: 3
    
  - name: restart_nginx
    service:
      name: nginx
      state: restarted
    notify: verify_nginx_health
    
  - name: verify_nginx_health
    uri:
      url: "http://localhost/nginx-status"
      status_code: 200
```

---

## 🎛️ Include e Import

### **Include Tasks Dinamico**
```bash
# Crea task files modulari
mkdir -p tasks

# tasks/database_setup.yml
cat > tasks/database_setup.yml << 'EOF'
---
- name: "Installa database server"
  package:
    name: "{{ db_package_name }}"
    state: present
    
- name: "Configura database"
  template:
    src: "{{ db_config_template }}"
    dest: "{{ db_config_path }}"
  notify: restart_database
  
- name: "Crea database applicazione"
  mysql_db:
    name: "{{ app_db_name }}"
    state: present
EOF

# tasks/webserver_setup.yml
cat > tasks/webserver_setup.yml << 'EOF'
---
- name: "Installa web server"
  package:
    name: "{{ web_package_name }}"
    state: present
    
- name: "Configura virtual hosts"
  template:
    src: vhost.conf.j2
    dest: "/etc/{{ web_service_name }}/sites-available/{{ app_name }}.conf"
  notify: restart_webserver
EOF
```

#### **Playbook con Include Dinamico**
```yaml
# playbooks/dynamic_include.yml
- name: "Setup Dinamico basato su Ruolo Server"
  hosts: all
  
  vars:
    server_configs:
      webserver:
        package: nginx
        config_template: nginx.conf.j2
        service: nginx
      database:
        package: mysql-server
        config_template: mysql.conf.j2
        service: mysql
        
  tasks:
    - name: "Include task specifici per ruolo"
      include_tasks: "tasks/{{ server_role }}_setup.yml"
      vars:
        db_package_name: "{{ server_configs[server_role].package }}"
        db_config_template: "{{ server_configs[server_role].config_template }}"
        db_service_name: "{{ server_configs[server_role].service }}"
      when: server_role is defined
      
    - name: "Include task OS-specific"
      include_tasks: "tasks/{{ ansible_os_family | lower }}_specific.yml"
      
    - name: "Include task condizionali"
      include_tasks: tasks/ssl_setup.yml
      when: ssl_enabled | default(false)
```

### **Import Playbook**
```yaml
# playbooks/master_deployment.yml
---
# Import playbook completi
- import_playbook: infrastructure_setup.yml
  tags: infrastructure

- import_playbook: application_deployment.yml
  tags: application
  
- import_playbook: monitoring_setup.yml
  tags: monitoring
  when: enable_monitoring | default(true)

# Playbook finale di verifica
- name: "Verifica Deployment Completo"
  hosts: all
  
  tasks:
    - name: "Raccolta informazioni post-deployment"
      setup:
        filter: ansible_*
        
    - name: "Test connettività inter-servizi"
      uri:
        url: "http://{{ item }}:{{ health_check_port | default(8080) }}/health"
        method: GET
        status_code: 200
      loop: "{{ groups['webservers'] }}"
      delegate_to: "{{ groups['loadbalancers'][0] }}"
      when: groups['loadbalancers'] is defined
```

---

## 🏷️ Tags Avanzati

### **Strategia Tags Organizzata**
```yaml
# playbooks/tagged_deployment.yml
- name: "Deployment con Tag Organizzati"
  hosts: webservers
  
  tasks:
    # Tag funzionali
    - name: "Download applicazione"
      get_url:
        url: "{{ app_download_url }}"
        dest: "/tmp/{{ app_name }}.tar.gz"
      tags: 
        - download
        - preparation
        - never  # Non eseguire di default
        
    - name: "Backup versione corrente"
      archive:
        path: "/opt/{{ app_name }}"
        dest: "/backup/{{ app_name }}-{{ ansible_date_time.epoch }}.tar.gz"
      tags:
        - backup
        - safety
        - always  # Esegui sempre
        
    - name: "Stop applicazione"
      service:
        name: "{{ app_name }}"
        state: stopped
      tags:
        - stop
        - service_management
        - critical
        
    - name: "Deploy nuova versione"
      unarchive:
        src: "/tmp/{{ app_name }}.tar.gz"
        dest: "/opt/"
        remote_src: true
      tags:
        - deploy
        - application
        
    - name: "Aggiorna configurazione"
      template:
        src: "{{ item.src }}"
        dest: "{{ item.dest }}"
      loop:
        - src: app.conf.j2
          dest: "/opt/{{ app_name }}/config/app.conf"
        - src: database.conf.j2
          dest: "/opt/{{ app_name }}/config/database.conf"
      tags:
        - configuration
        - templates
        
    - name: "Start applicazione"
      service:
        name: "{{ app_name }}"
        state: started
      tags:
        - start
        - service_management
        - critical
        
    - name: "Verifica health check"
      uri:
        url: "http://localhost:{{ app_port }}/health"
        status_code: 200
      retries: 10
      delay: 5
      tags:
        - verify
        - health_check
        - critical
        
    - name: "Cleanup file temporanei"
      file:
        path: "/tmp/{{ app_name }}.tar.gz"
        state: absent
      tags:
        - cleanup
        - always
```

### **Esecuzione con Tag**
```bash
# Esempi di uso tag
ansible-playbook playbooks/tagged_deployment.yml --tags "backup,deploy,start"
ansible-playbook playbooks/tagged_deployment.yml --tags "critical"
ansible-playbook playbooks/tagged_deployment.yml --skip-tags "download,cleanup"
ansible-playbook playbooks/tagged_deployment.yml --tags "all,!never"

# Tag per debugging
ansible-playbook playbooks/tagged_deployment.yml --tags "debug" -v

# Tag per rollback
ansible-playbook playbooks/rollback.yml --tags "rollback,critical"
```

---

## 🚀 Playbook Patterns Avanzati

### **Rolling Deployment**
```yaml
# playbooks/rolling_deployment.yml
- name: "Rolling Deployment Zero-Downtime"
  hosts: webservers
  serial: 1  # Un server alla volta
  max_fail_percentage: 0  # Ferma se anche un solo host fallisce
  
  pre_tasks:
    - name: "Rimuovi server dal load balancer"
      uri:
        url: "{{ lb_api_url }}/servers/{{ inventory_hostname }}"
        method: DELETE
        status_code: [200, 404]
      delegate_to: localhost
      tags: load_balancer
      
    - name: "Attendi drain connections"
      wait_for:
        timeout: 30
      tags: drain
      
  tasks:
    - name: "Stop applicazione"
      service:
        name: "{{ app_name }}"
        state: stopped
        
    - name: "Backup configurazione corrente"
      archive:
        path: "/opt/{{ app_name }}"
        dest: "/backup/{{ app_name }}-pre-{{ deployment_id }}.tar.gz"
        
    - name: "Deploy nuova versione"
      unarchive:
        src: "{{ app_package_url }}"
        dest: "/opt/"
        remote_src: true
        creates: "/opt/{{ app_name }}/version-{{ app_version }}.txt"
        
    - name: "Aggiorna database schema"
      command: "/opt/{{ app_name }}/bin/migrate.sh"
      register: migration_result
      run_once: true  # Solo su un server
      
    - name: "Start applicazione"
      service:
        name: "{{ app_name }}"
        state: started
        
    - name: "Verifica health check applicazione"
      uri:
        url: "http://{{ ansible_default_ipv4.address }}:{{ app_port }}/health"
        status_code: 200
      retries: 15
      delay: 4
      
  post_tasks:
    - name: "Aggiungi server al load balancer"
      uri:
        url: "{{ lb_api_url }}/servers"
        method: POST
        body_format: json
        body:
          host: "{{ inventory_hostname }}"
          port: "{{ app_port }}"
          weight: "{{ lb_weight | default(1) }}"
      delegate_to: localhost
      
    - name: "Verifica health check via load balancer"
      uri:
        url: "{{ lb_frontend_url }}/health"
        status_code: 200
      retries: 10
      delay: 3
      delegate_to: localhost
```

### **Blue-Green Deployment**
```yaml
# playbooks/blue_green_deployment.yml
- name: "Blue-Green Deployment"
  hosts: webservers
  
  vars:
    current_color: "{{ 'blue' if active_color == 'green' else 'green' }}"
    app_path: "/opt/{{ app_name }}-{{ current_color }}"
    
  tasks:
    - name: "Determina colore attivo corrente"
      slurp:
        src: /opt/active_deployment
      register: active_deployment_file
      failed_when: false
      
    - name: "Set active_color da file"
      set_fact:
        active_color: "{{ (active_deployment_file.content | b64decode).strip() }}"
      when: active_deployment_file.content is defined
      
    - name: "Deploy su ambiente {{ current_color }}"
      unarchive:
        src: "{{ app_package_url }}"
        dest: "{{ app_path }}"
        remote_src: true
        
    - name: "Configura applicazione {{ current_color }}"
      template:
        src: app.conf.j2
        dest: "{{ app_path }}/config/app.conf"
      vars:
        app_port: "{{ blue_port if current_color == 'blue' else green_port }}"
        
    - name: "Start applicazione {{ current_color }}"
      systemd:
        name: "{{ app_name }}-{{ current_color }}"
        state: started
        enabled: true
        
    - name: "Health check {{ current_color }}"
      uri:
        url: "http://localhost:{{ blue_port if current_color == 'blue' else green_port }}/health"
        status_code: 200
      retries: 20
      delay: 3
      
    - name: "Switch load balancer a {{ current_color }}"
      template:
        src: lb_config.j2
        dest: /etc/nginx/conf.d/upstream.conf
      vars:
        active_port: "{{ blue_port if current_color == 'blue' else green_port }}"
      notify: reload_nginx
      
    - name: "Aggiorna file active deployment"
      copy:
        content: "{{ current_color }}"
        dest: /opt/active_deployment
        
    - name: "Stop vecchia applicazione {{ active_color }}"
      systemd:
        name: "{{ app_name }}-{{ active_color }}"
        state: stopped
      when: active_color is defined
```

---

## ✅ Checklist Playbook e Tasks

Prima di procedere al Capitolo 6, verifica:

### **Playbook Structure** 📜
- [ ] Playbook con tutte le sezioni (pre_tasks, tasks, post_tasks, handlers)
- [ ] Uso corretto di serial e max_fail_percentage
- [ ] Vars, vars_files e vars_prompt configurati
- [ ] Tag organizzati logicamente

### **Tasks Avanzati** 🎯
- [ ] Conditionals (when) con logica complessa
- [ ] Loop multipli con dizionari e liste
- [ ] Block/rescue/always per gestione errori
- [ ] Retry e until per operazioni asincrone

### **Handlers** 🔄
- [ ] Handlers con conditionals
- [ ] Notifiche multiple e catene di handlers
- [ ] Handlers con validazione

### **Modularità** 🧩
- [ ] Include tasks dinamico funzionante
- [ ] Import playbook per organizzazione
- [ ] Task files riutilizzabili

### **Deployment Patterns** 🚀
- [ ] Rolling deployment testato
- [ ] Blue-green pattern implementato
- [ ] Tag strategy definita
- [ ] Error handling robusto

---

## 🎓 Concetti Chiave Appresi

> **💡 Block/Rescue/Always**: Gestione errori strutturata come try/catch/finally
> 
> **💡 Serial Execution**: Controllo del parallelismo per deployment sicuri
> 
> **💡 Dynamic Includes**: Modularità e riusabilità del codice
> 
> **💡 Advanced Loops**: Iterazione su strutture dati complesse
> 
> **💡 Handler Chains**: Orchestrazione di restart e validazioni

---

## 🔗 Prossimo Passo

Fantastico! Ora padroneggi playbook e task avanzati. Procedi al:
👉 [**Capitolo 6 - Roles e Template**](06-roles-template.md)

Imparerai a creare roles riutilizzabili e template Jinja2 per configurazioni dinamiche.
