# Template e Esempi

## Template Systemd Service (Linux)

Crea `roles/webserver/templates/app.service.j2`:

```ini
[Unit]
Description={{ app_name }} Application
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/opt/{{ app_name }}
ExecStart=/usr/bin/java -jar app.jar
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## Esempio Inventory Completo

```yaml
all:
  children:
    linux_servers:
      hosts:
        web-01:
          ansible_host: 192.168.1.10
          ansible_user: ansible
          server_role: web
        web-02:
          ansible_host: 192.168.1.11
          ansible_user: ansible
          server_role: web
        db-01:
          ansible_host: 192.168.1.12
          ansible_user: ansible
          server_role: database
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_become: true
    
    windows_servers:
      hosts:
        win-web-01:
          ansible_host: 192.168.1.20
          ansible_user: Administrator
          server_role: web
        win-app-01:
          ansible_host: 192.168.1.21
          ansible_user: Administrator
          server_role: app
      vars:
        ansible_connection: winrm
        ansible_port: 5985
    
    webservers:
      children:
        linux_web:
          hosts:
            web-01:
            web-02:
        windows_web:
          hosts:
            win-web-01:
    
    databases:
      hosts:
        db-01:
    
    development:
      children:
        - linux_servers
        - windows_servers
      vars:
        environment: dev
        debug_mode: true
    
    production:
      children:
        - linux_servers  
        - windows_servers
      vars:
        environment: prod
        debug_mode: false
```

## Playbook Avanzato per Database

```yaml
---
- name: "Setup Database Server"
  hosts: databases
  become: true
  vars:
    mysql_root_password: "{{ vault_mysql_root_password }}"
    mysql_databases:
      - name: webapp_db
        encoding: utf8
      - name: logs_db
        encoding: utf8
    mysql_users:
      - name: webapp_user
        password: "{{ vault_webapp_db_password }}"
        priv: "webapp_db.*:ALL"
        host: "%"
  
  tasks:
    - name: "Installa MySQL"
      package:
        name: "{{ mysql_package_name }}"
        state: present
        
    - name: "Abilita e avvia MySQL"
      systemd:
        name: "{{ mysql_service_name }}"
        enabled: true
        state: started
        
    - name: "Configura root password MySQL"
      mysql_user:
        name: root
        password: "{{ mysql_root_password }}"
        host: localhost
        
    - name: "Crea database"
      mysql_db:
        name: "{{ item.name }}"
        encoding: "{{ item.encoding }}"
        state: present
      loop: "{{ mysql_databases }}"
      
    - name: "Crea utenti database"
      mysql_user:
        name: "{{ item.name }}"
        password: "{{ item.password }}"
        priv: "{{ item.priv }}"
        host: "{{ item.host }}"
        state: present
      loop: "{{ mysql_users }}"
      
    - name: "Configura firewall per MySQL"
      firewalld:
        service: mysql
        permanent: true
        state: enabled
        immediate: true
```

## Script di Backup

```yaml
---
- name: "Backup Database e Applicazioni"
  hosts: all
  vars:
    backup_dir: "/opt/backups/{{ ansible_date_time.date }}"
    
  tasks:
    - name: "Crea directory backup"
      file:
        path: "{{ backup_dir }}"
        state: directory
        mode: '0755'
      when: ansible_os_family != "Windows"
      
    - name: "Backup MySQL Database"
      mysql_db:
        name: webapp_db
        state: dump
        target: "{{ backup_dir }}/webapp_db.sql"
      when: "'databases' in group_names"
      
    - name: "Backup applicazione"
      archive:
        path: "/opt/webapp"
        dest: "{{ backup_dir }}/webapp.tar.gz"
        format: gz
      when: ansible_os_family != "Windows"
      
    - name: "Backup Windows Application"
      win_copy:
        src: "C:\\Apps\\webapp\\"
        dest: "C:\\Backups\\{{ ansible_date_time.date }}\\webapp\\"
        remote_src: true
      when: ansible_os_family == "Windows"
      
    - name: "Cleanup vecchi backup (>7 giorni)"
      find:
        paths: "/opt/backups"
        age: 7d
        file_type: directory
      register: old_backups
      when: ansible_os_family != "Windows"
      
    - name: "Rimuovi vecchi backup"
      file:
        path: "{{ item.path }}"
        state: absent
      loop: "{{ old_backups.files }}"
      when: ansible_os_family != "Windows"
```

## Configurazione Nginx

```yaml
---
- name: "Configura Nginx Reverse Proxy"
  hosts: webservers
  become: true
  
  tasks:
    - name: "Installa Nginx"
      package:
        name: nginx
        state: present
        
    - name: "Configura virtual host"
      template:
        src: nginx-site.conf.j2
        dest: "/etc/nginx/sites-available/{{ app_name }}"
        backup: true
      notify: restart_nginx
      
    - name: "Abilita virtual host"
      file:
        src: "/etc/nginx/sites-available/{{ app_name }}"
        dest: "/etc/nginx/sites-enabled/{{ app_name }}"
        state: link
      notify: restart_nginx
      
    - name: "Test configurazione Nginx"
      command: nginx -t
      register: nginx_test
      failed_when: nginx_test.rc != 0
      
  handlers:
    - name: restart_nginx
      systemd:
        name: nginx
        state: restarted
```

Template `roles/webserver/templates/nginx-site.conf.j2`:

```nginx
server {
    listen 80;
    server_name {{ ansible_fqdn }};
    
    location / {
        proxy_pass http://127.0.0.1:{{ app_port }};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

## Deployment con Rolling Update

```yaml
---
- name: "Rolling Update Applicazione"
  hosts: webservers
  serial: 1
  max_fail_percentage: 0
  
  pre_tasks:
    - name: "Rimuovi server dal load balancer"
      uri:
        url: "http://loadbalancer/api/servers/{{ inventory_hostname }}/disable"
        method: POST
      delegate_to: localhost
      
  tasks:
    - name: "Stop applicazione"
      systemd:
        name: webapp
        state: stopped
        
    - name: "Backup versione corrente"
      command: cp -r /opt/webapp /opt/webapp.backup
      
    - name: "Deploy nuova versione"
      unarchive:
        src: "webapp-{{ app_version }}.tar.gz"
        dest: /opt/webapp
        remote_src: false
        
    - name: "Start applicazione"
      systemd:
        name: webapp
        state: started
        
    - name: "Verifica health check"
      uri:
        url: "http://{{ ansible_default_ipv4.address }}:8080/health"
        status_code: 200
      retries: 5
      delay: 10
      
  post_tasks:
    - name: "Aggiungi server al load balancer"
      uri:
        url: "http://loadbalancer/api/servers/{{ inventory_hostname }}/enable"
        method: POST
      delegate_to: localhost
      
  rescue:
    - name: "Rollback in caso di errore"
      command: cp -r /opt/webapp.backup /opt/webapp
      
    - name: "Restart applicazione dopo rollback"
      systemd:
        name: webapp
        state: restarted
```
