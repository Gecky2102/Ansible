# 🚀 Capitolo 7 - Deployment Applicazioni

> **Obiettivo**: Imparerai come automatizzare il deployment di applicazioni su server Linux e Windows, implementando strategie di rolling update e rollback automatico.

## 📋 Indice del Capitolo

1. [Strategie di Deployment](#strategie-di-deployment)
2. [Deployment su Linux](#deployment-su-linux)
3. [Deployment su Windows](#deployment-su-windows)
4. [Rolling Updates](#rolling-updates)
5. [Rollback Automatico](#rollback-automatico)
6. [Health Checks](#health-checks)
7. [Deployment Multi-Environment](#deployment-multi-environment)

---

## 🎯 Strategie di Deployment

### **Tipi di Deployment**

#### **1. Blue-Green Deployment**
```yaml
# playbooks/deploy-blue-green.yml
---
- name: Blue-Green Deployment
  hosts: webservers
  vars:
    app_version: "{{ version | default('latest') }}"
    deployment_slot: "{{ slot | default('blue') }}"
  
  tasks:
    - name: Stop traffic su slot corrente
      include_tasks: tasks/stop-traffic.yml
    
    - name: Deploy su slot inattivo
      include_tasks: tasks/deploy-app.yml
      vars:
        target_slot: "{{ 'green' if deployment_slot == 'blue' else 'blue' }}"
    
    - name: Health check nuovo deployment
      include_tasks: tasks/health-check.yml
    
    - name: Switch traffic
      include_tasks: tasks/switch-traffic.yml
```

#### **2. Rolling Deployment**
```yaml
# playbooks/deploy-rolling.yml
---
- name: Rolling Deployment
  hosts: webservers
  serial: 1  # Un server alla volta
  max_fail_percentage: 10
  
  tasks:
    - name: Remove from load balancer
      uri:
        url: "http://{{ load_balancer }}/remove/{{ inventory_hostname }}"
        method: POST
    
    - name: Deploy new version
      include_tasks: tasks/deploy-app.yml
    
    - name: Health check
      include_tasks: tasks/health-check.yml
    
    - name: Add back to load balancer
      uri:
        url: "http://{{ load_balancer }}/add/{{ inventory_hostname }}"
        method: POST
```

#### **3. Canary Deployment**
```yaml
# playbooks/deploy-canary.yml
---
- name: Canary Deployment
  hosts: webservers
  vars:
    canary_percentage: "{{ canary_percent | default(10) }}"
  
  tasks:
    - name: Select canary servers
      set_fact:
        is_canary: "{{ (ansible_play_hosts.index(inventory_hostname) * 100 // ansible_play_hosts|length) < canary_percentage|int }}"
    
    - name: Deploy to canary servers
      include_tasks: tasks/deploy-app.yml
      when: is_canary
    
    - name: Monitor canary metrics
      include_tasks: tasks/monitor-canary.yml
      when: is_canary
```

---

## 🐧 Deployment su Linux

### **Deployment Web Application**

#### **1. Preparazione Environment**
```yaml
# tasks/prepare-linux-env.yml
---
- name: Create application user
  user:
    name: "{{ app_user }}"
    system: yes
    shell: /bin/bash
    home: "/home/{{ app_user }}"
    create_home: yes

- name: Create application directories
  file:
    path: "{{ item }}"
    state: directory
    owner: "{{ app_user }}"
    group: "{{ app_user }}"
    mode: '0755'
  loop:
    - "{{ app_root }}"
    - "{{ app_root }}/releases"
    - "{{ app_root }}/shared"
    - "{{ app_root }}/shared/logs"
    - "{{ app_root }}/shared/config"

- name: Install application dependencies
  package:
    name: "{{ item }}"
    state: present
  loop:
    - git
    - nodejs
    - npm
    - nginx
  become: yes
```

#### **2. Download e Build Application**
```yaml
# tasks/deploy-app-linux.yml
---
- name: Set deployment facts
  set_fact:
    release_timestamp: "{{ ansible_date_time.epoch }}"
    release_path: "{{ app_root }}/releases/{{ ansible_date_time.epoch }}"

- name: Clone application repository
  git:
    repo: "{{ app_repo_url }}"
    dest: "{{ release_path }}"
    version: "{{ app_version }}"
    force: yes
  become_user: "{{ app_user }}"

- name: Install npm dependencies
  npm:
    path: "{{ release_path }}"
    production: yes
  become_user: "{{ app_user }}"

- name: Build application
  command: npm run build
  args:
    chdir: "{{ release_path }}"
  become_user: "{{ app_user }}"

- name: Copy configuration files
  template:
    src: "{{ item.src }}"
    dest: "{{ release_path }}/{{ item.dest }}"
    owner: "{{ app_user }}"
    group: "{{ app_user }}"
    mode: '0644'
  loop:
    - { src: app.conf.j2, dest: config/app.conf }
    - { src: database.conf.j2, dest: config/database.conf }
  notify: restart application
```

#### **3. Symlink e Cleanup**
```yaml
# tasks/finalize-deployment.yml
---
- name: Create symlink to current release
  file:
    src: "{{ release_path }}"
    dest: "{{ app_root }}/current"
    state: link
    owner: "{{ app_user }}"
    group: "{{ app_user }}"
  notify: restart application

- name: Remove old releases (keep last 5)
  shell: |
    cd {{ app_root }}/releases
    ls -1t | tail -n +6 | xargs rm -rf
  become_user: "{{ app_user }}"

- name: Start application service
  systemd:
    name: "{{ app_service_name }}"
    state: started
    enabled: yes
    daemon_reload: yes
  become: yes
```

#### **4. Service Template**
```ini
# templates/app-service.j2
[Unit]
Description={{ app_name }} Application
After=network.target

[Service]
Type=simple
User={{ app_user }}
Group={{ app_user }}
WorkingDirectory={{ app_root }}/current
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT={{ app_port }}

[Install]
WantedBy=multi-user.target
```

### **Nginx Configuration**
```nginx
# templates/nginx-app.conf.j2
upstream {{ app_name }} {
{% for server in groups['webservers'] %}
    server {{ hostvars[server]['ansible_default_ipv4']['address'] }}:{{ app_port }};
{% endfor %}
}

server {
    listen 80;
    server_name {{ app_domain }};

    location / {
        proxy_pass http://{{ app_name }};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://{{ app_name }}/health;
        access_log off;
    }
}
```

---

## 🪟 Deployment su Windows

### **Deployment IIS Application**

#### **1. Preparazione Environment Windows**
```yaml
# tasks/prepare-windows-env.yml
---
- name: Enable IIS features
  win_feature:
    name: "{{ item }}"
    state: present
  loop:
    - IIS-WebServerRole
    - IIS-WebServer
    - IIS-CommonHttpFeatures
    - IIS-HttpRedirect
    - IIS-NetFxExtensibility45
    - IIS-ASPNET45

- name: Create application pool
  win_iis_webapppool:
    name: "{{ app_pool_name }}"
    state: present
    attributes:
      processModel.identityType: ApplicationPoolIdentity
      recycling.periodicRestart.time: "1.05:00:00"

- name: Create application directories
  win_file:
    path: "{{ item }}"
    state: directory
  loop:
    - "{{ app_root }}"
    - "{{ app_root }}\\releases"
    - "{{ app_root }}\\shared"
    - "{{ app_root }}\\shared\\logs"
```

#### **2. Deploy .NET Application**
```yaml
# tasks/deploy-app-windows.yml
---
- name: Set deployment facts
  set_fact:
    release_timestamp: "{{ ansible_date_time.epoch }}"
    release_path: "{{ app_root }}\\releases\\{{ ansible_date_time.epoch }}"

- name: Create release directory
  win_file:
    path: "{{ release_path }}"
    state: directory

- name: Download application package
  win_get_url:
    url: "{{ app_package_url }}"
    dest: "{{ release_path }}\\app.zip"

- name: Extract application
  win_unzip:
    src: "{{ release_path }}\\app.zip"
    dest: "{{ release_path }}"
    delete_archive: yes

- name: Copy configuration files
  win_template:
    src: "{{ item.src }}"
    dest: "{{ release_path }}\\{{ item.dest }}"
  loop:
    - { src: web.config.j2, dest: web.config }
    - { src: appsettings.json.j2, dest: appsettings.json }

- name: Stop application pool
  win_iis_webapppool:
    name: "{{ app_pool_name }}"
    state: stopped

- name: Update current symlink
  win_command: |
    cmd /c "rmdir {{ app_root }}\current"
    cmd /c "mklink /D {{ app_root }}\current {{ release_path }}"
  ignore_errors: yes

- name: Start application pool
  win_iis_webapppool:
    name: "{{ app_pool_name }}"
    state: started
```

#### **3. IIS Site Configuration**
```yaml
# tasks/configure-iis-site.yml
---
- name: Create IIS website
  win_iis_website:
    name: "{{ app_name }}"
    state: present
    port: 80
    physical_path: "{{ app_root }}\\current"
    application_pool: "{{ app_pool_name }}"

- name: Configure IIS bindings
  win_iis_webbinding:
    name: "{{ app_name }}"
    protocol: http
    port: 80
    host_header: "{{ app_domain }}"
    state: present
```

---

## 🔄 Rolling Updates

### **Implementazione Rolling Update**

#### **1. Playbook Rolling Update**
```yaml
# playbooks/rolling-update.yml
---
- name: Rolling Update Strategy
  hosts: webservers
  serial: "{{ batch_size | default('25%') }}"
  max_fail_percentage: 10
  
  pre_tasks:
    - name: Check if load balancer is available
      uri:
        url: "http://{{ load_balancer }}/health"
        method: GET
      delegate_to: localhost
      run_once: true

  tasks:
    - name: Remove server from load balancer
      uri:
        url: "http://{{ load_balancer }}/api/servers/{{ inventory_hostname }}/disable"
        method: POST
        headers:
          Authorization: "Bearer {{ lb_token }}"
      delegate_to: localhost
      
    - name: Wait for connections to drain
      wait_for:
        timeout: 30
      
    - name: Deploy new version
      include_tasks: tasks/deploy-app.yml
      
    - name: Start application services
      service:
        name: "{{ app_service_name }}"
        state: started
      when: ansible_os_family == "RedHat" or ansible_os_family == "Debian"
      
    - name: Start Windows services
      win_service:
        name: "{{ app_service_name }}"
        state: started
      when: ansible_os_family == "Windows"
      
    - name: Health check new deployment
      uri:
        url: "http://{{ inventory_hostname }}/health"
        method: GET
        status_code: 200
      retries: 5
      delay: 10
      
    - name: Add server back to load balancer
      uri:
        url: "http://{{ load_balancer }}/api/servers/{{ inventory_hostname }}/enable"
        method: POST
        headers:
          Authorization: "Bearer {{ lb_token }}"
      delegate_to: localhost

  post_tasks:
    - name: Verify all servers are healthy
      uri:
        url: "http://{{ item }}/health"
        method: GET
        status_code: 200
      loop: "{{ groups['webservers'] }}"
      delegate_to: localhost
      run_once: true
```

#### **2. Gestione Batch Size Dinamico**
```yaml
# tasks/calculate-batch-size.yml
---
- name: Calculate optimal batch size
  set_fact:
    calculated_batch_size: "{{ (groups['webservers']|length * 0.25)|round|int }}"
  when: batch_size is not defined

- name: Ensure minimum batch size
  set_fact:
    final_batch_size: "{{ [calculated_batch_size|int, 1]|max }}"

- name: Debug batch information
  debug:
    msg: |
      Total servers: {{ groups['webservers']|length }}
      Batch size: {{ final_batch_size }}
      Estimated batches: {{ (groups['webservers']|length / final_batch_size|int)|round|int }}
```

---

## ⏪ Rollback Automatico

### **Sistema di Rollback**

#### **1. Rollback Playbook**
```yaml
# playbooks/rollback.yml
---
- name: Automatic Rollback
  hosts: webservers
  vars:
    rollback_version: "{{ target_version | default('previous') }}"
  
  tasks:
    - name: Find previous release
      find:
        paths: "{{ app_root }}/releases"
        file_type: directory
      register: releases
      when: rollback_version == 'previous'
      
    - name: Set rollback target
      set_fact:
        rollback_target: "{{ (releases.files | sort(attribute='mtime', reverse=True))[1].path }}"
      when: rollback_version == 'previous'
      
    - name: Set specific rollback target
      set_fact:
        rollback_target: "{{ app_root }}/releases/{{ rollback_version }}"
      when: rollback_version != 'previous'
      
    - name: Verify rollback target exists
      stat:
        path: "{{ rollback_target }}"
      register: rollback_stat
      failed_when: not rollback_stat.stat.exists
      
    - name: Stop application
      service:
        name: "{{ app_service_name }}"
        state: stopped
      when: ansible_os_family != "Windows"
      
    - name: Stop Windows application
      win_service:
        name: "{{ app_service_name }}"
        state: stopped
      when: ansible_os_family == "Windows"
      
    - name: Update current symlink
      file:
        src: "{{ rollback_target }}"
        dest: "{{ app_root }}/current"
        state: link
        force: yes
      when: ansible_os_family != "Windows"
      
    - name: Update Windows current link
      win_command: |
        cmd /c "rmdir {{ app_root }}\current && mklink /D {{ app_root }}\current {{ rollback_target }}"
      when: ansible_os_family == "Windows"
      
    - name: Start application
      service:
        name: "{{ app_service_name }}"
        state: started
      when: ansible_os_family != "Windows"
      
    - name: Start Windows application
      win_service:
        name: "{{ app_service_name }}"
        state: started
      when: ansible_os_family == "Windows"
      
    - name: Verify rollback health
      uri:
        url: "http://{{ inventory_hostname }}/health"
        method: GET
        status_code: 200
      retries: 3
      delay: 5
```

#### **2. Rollback Automatico su Failure**
```yaml
# tasks/deploy-with-rollback.yml
---
- name: Deploy new version
  block:
    - name: Deploy application
      include_tasks: tasks/deploy-app.yml
      
    - name: Health check deployment
      uri:
        url: "http://{{ inventory_hostname }}/health"
        method: GET
        status_code: 200
      retries: 3
      delay: 10
      
  rescue:
    - name: Log deployment failure
      debug:
        msg: "Deployment failed, initiating rollback"
        
    - name: Execute rollback
      include_tasks: tasks/rollback.yml
      
    - name: Verify rollback success
      uri:
        url: "http://{{ inventory_hostname }}/health"
        method: GET
        status_code: 200
      retries: 3
      delay: 5
      
    - name: Fail deployment
      fail:
        msg: "Deployment failed and rollback completed"
```

---

## 🏥 Health Checks

### **Health Check Comprehensive**

#### **1. Multi-Layer Health Checks**
```yaml
# tasks/health-check.yml
---
- name: Application health check
  uri:
    url: "http://{{ inventory_hostname }}:{{ app_port }}/health"
    method: GET
    status_code: 200
    timeout: 10
  retries: 5
  delay: 5
  register: app_health

- name: Database connectivity check
  uri:
    url: "http://{{ inventory_hostname }}:{{ app_port }}/health/database"
    method: GET
    status_code: 200
  retries: 3
  delay: 5
  register: db_health

- name: Dependencies health check
  uri:
    url: "http://{{ inventory_hostname }}:{{ app_port }}/health/dependencies"
    method: GET
    status_code: 200
  register: deps_health

- name: Performance benchmark
  uri:
    url: "http://{{ inventory_hostname }}:{{ app_port }}/health/performance"
    method: GET
    status_code: 200
  register: perf_check
  
- name: Verify response time
  fail:
    msg: "Response time too slow: {{ perf_check.elapsed }}s"
  when: perf_check.elapsed > 2.0

- name: Log health check results
  debug:
    msg: |
      Health Check Results:
      - Application: {{ 'OK' if app_health.status == 200 else 'FAILED' }}
      - Database: {{ 'OK' if db_health.status == 200 else 'FAILED' }}
      - Dependencies: {{ 'OK' if deps_health.status == 200 else 'FAILED' }}
      - Response Time: {{ perf_check.elapsed }}s
```

#### **2. Custom Health Check Script**
```bash
#!/bin/bash
# scripts/health-check.sh

APP_URL="$1"
MAX_RETRIES=5
RETRY_DELAY=5

echo "Starting comprehensive health check for $APP_URL"

# Function to check endpoint
check_endpoint() {
    local endpoint="$1"
    local expected_status="$2"
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        status=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint")
        if [ "$status" = "$expected_status" ]; then
            echo "✅ $endpoint - OK ($status)"
            return 0
        fi
        
        echo "⚠️  $endpoint - Status $status (retry $((retries+1))/$MAX_RETRIES)"
        retries=$((retries+1))
        sleep $RETRY_DELAY
    done
    
    echo "❌ $endpoint - FAILED after $MAX_RETRIES retries"
    return 1
}

# Check application endpoints
check_endpoint "$APP_URL/health" "200"
health_status=$?

check_endpoint "$APP_URL/health/database" "200"
db_status=$?

check_endpoint "$APP_URL/health/ready" "200"
ready_status=$?

# Overall result
if [ $health_status -eq 0 ] && [ $db_status -eq 0 ] && [ $ready_status -eq 0 ]; then
    echo "🎉 All health checks passed!"
    exit 0
else
    echo "💥 Some health checks failed!"
    exit 1
fi
```

---

## 🌍 Deployment Multi-Environment

### **Environment-Specific Deployment**

#### **1. Environment Variables**
```yaml
# group_vars/development.yml
---
app_environment: development
app_debug: true
app_log_level: debug
app_replica_count: 1
database_pool_size: 5
cache_ttl: 60

# group_vars/staging.yml
---
app_environment: staging
app_debug: false
app_log_level: info
app_replica_count: 2
database_pool_size: 10
cache_ttl: 300

# group_vars/production.yml
---
app_environment: production
app_debug: false
app_log_level: warn
app_replica_count: 5
database_pool_size: 50
cache_ttl: 3600
deployment_strategy: rolling
max_surge: 25%
max_unavailable: 25%
```

#### **2. Environment-Aware Deployment**
```yaml
# playbooks/deploy-multi-env.yml
---
- name: Multi-Environment Deployment
  hosts: "{{ target_environment }}"
  vars:
    app_version: "{{ version }}"
    environment: "{{ target_environment }}"
  
  pre_tasks:
    - name: Validate environment
      fail:
        msg: "Invalid environment: {{ target_environment }}"
      when: target_environment not in ['development', 'staging', 'production']
    
    - name: Load environment variables
      include_vars: "group_vars/{{ target_environment }}.yml"
    
    - name: Deployment approval for production
      pause:
        prompt: "Deploying {{ app_version }} to PRODUCTION. Continue? (yes/no)"
      when: target_environment == 'production'
      delegate_to: localhost
      run_once: true

  tasks:
    - name: Deploy based on environment strategy
      include_tasks: "tasks/deploy-{{ deployment_strategy | default('basic') }}.yml"
    
    - name: Configure environment-specific settings
      template:
        src: "config/{{ target_environment }}.conf.j2"
        dest: "{{ app_root }}/current/config/app.conf"
      notify: restart application
    
    - name: Run environment-specific tests
      include_tasks: "tasks/test-{{ target_environment }}.yml"

  post_tasks:
    - name: Notify deployment completion
      uri:
        url: "{{ slack_webhook_url }}"
        method: POST
        body_format: json
        body:
          text: "✅ Deployment completed: {{ app_version }} to {{ target_environment }}"
      when: slack_webhook_url is defined
```

---

## 💡 Best Practices Deployment

### **1. Pre-deployment Checks**
```yaml
# tasks/pre-deployment-checks.yml
---
- name: Check disk space
  shell: df -h {{ app_root }} | awk 'NR==2 {print $5}' | sed 's/%//'
  register: disk_usage
  failed_when: disk_usage.stdout|int > 85

- name: Check memory usage
  shell: free | awk 'FNR==2{printf "%.0f", $3/($3+$4)*100}'
  register: memory_usage
  failed_when: memory_usage.stdout|int > 90

- name: Verify application is not already deploying
  stat:
    path: "{{ app_root }}/.deploying"
  register: deploy_lock
  failed_when: deploy_lock.stat.exists

- name: Create deployment lock
  file:
    path: "{{ app_root }}/.deploying"
    state: touch
```

### **2. Post-deployment Cleanup**
```yaml
# tasks/post-deployment-cleanup.yml
---
- name: Remove deployment lock
  file:
    path: "{{ app_root }}/.deploying"
    state: absent
  
- name: Clean old releases
  shell: |
    cd {{ app_root }}/releases
    ls -1t | tail -n +{{ keep_releases | default(5) }} | xargs rm -rf
  
- name: Clean temporary files
  find:
    paths: /tmp
    patterns: "{{ app_name }}-*"
    age: "1d"
  register: temp_files
  
- name: Remove old temp files
  file:
    path: "{{ item.path }}"
    state: absent
  loop: "{{ temp_files.files }}"

- name: Update deployment metadata
  copy:
    content: |
      version: {{ app_version }}
      deployed_at: {{ ansible_date_time.iso8601 }}
      deployed_by: {{ ansible_user_id }}
      environment: {{ target_environment }}
    dest: "{{ app_root }}/current/.deployment-info"
```

---

## ✅ Checkpoint - Verifica Deployment

Verifica che tutto funzioni correttamente:

```bash
# Test deployment locale
ansible-playbook -i inventory/hosts.yml playbooks/deploy-app.yml -e "app_version=v1.2.3"

# Test rolling update
ansible-playbook -i inventory/hosts.yml playbooks/rolling-update.yml -e "batch_size=25%"

# Test rollback
ansible-playbook -i inventory/hosts.yml playbooks/rollback.yml -e "rollback_version=previous"

# Health check manuale
curl -s http://server1/health | jq .
```

> **✅ VERIFICA COMPLETATA**: I tuoi deployment ora sono automatizzati e sicuri!

---

## 🔗 Prossimo Capitolo

Nel [**Capitolo 8 - Monitoraggio e Logging**](08-monitoraggio.md) implementeremo sistemi di monitoraggio completi per tenere sotto controllo l'infrastruttura e le applicazioni.

---

## 📚 Risorse Aggiuntive

- [Ansible Deployment Strategies](https://docs.ansible.com/ansible/latest/user_guide/playbooks_strategies.html)
- [Rolling Updates Best Practices](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Blue-Green Deployment Guide](https://martinfowler.com/bliki/BlueGreenDeployment.html)
