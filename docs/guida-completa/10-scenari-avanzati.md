# 🚀 Capitolo 10 - Scenari Avanzati

> **Obiettivo**: Esplorare scenari enterprise avanzati con integrazione CI/CD, gestione multi-environment, backup automatizzato e scaling per infrastrutture complesse.

## 📋 Indice del Capitolo

1. [Integrazione CI/CD](#integrazione-cicd)
2. [Multi-Environment Management](#multi-environment-management)
3. [Backup e Disaster Recovery](#backup-e-disaster-recovery)
4. [Scaling e Load Balancing](#scaling-e-load-balancing)
5. [Container e Kubernetes](#container-e-kubernetes)
6. [Infrastructure as Code](#infrastructure-as-code)
7. [Automation Testing](#automation-testing)
8. [Enterprise Integration](#enterprise-integration)

---

## 🔄 Integrazione CI/CD

### **Jenkins Integration**

#### **1. Jenkins Pipeline per Ansible**

```groovy
// Jenkinsfile
pipeline {
    agent any
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['development', 'staging', 'production'],
            description: 'Target environment'
        )
        choice(
            name: 'DEPLOYMENT_TYPE',
            choices: ['full', 'app-only', 'config-only'],
            description: 'Deployment type'
        )
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: false,
            description: 'Perform dry run'
        )
    }
    
    environment {
        ANSIBLE_VAULT_PASSWORD_FILE = credentials('ansible-vault-password')
        ANSIBLE_CONFIG = "${WORKSPACE}/ansible.cfg"
        ENVIRONMENT = "${params.ENVIRONMENT}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.BUILD_TIMESTAMP = sh(
                        script: 'date +%Y%m%d-%H%M%S',
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Validate') {
            parallel {
                stage('Syntax Check') {
                    steps {
                        sh '''
                            ansible-playbook --syntax-check playbooks/site.yml
                            ansible-playbook --syntax-check playbooks/deploy_app.yml
                        '''
                    }
                }
                stage('Lint Check') {
                    steps {
                        sh '''
                            ansible-lint playbooks/ || true
                            yamllint inventory/ || true
                        '''
                    }
                }
                stage('Security Check') {
                    steps {
                        sh './scripts/vault-security-check.sh'
                    }
                }
            }
        }
        
        stage('Test Connection') {
            steps {
                sh '''
                    ansible all -i inventory/hosts.yml -m ping --limit ${ENVIRONMENT}
                '''
            }
        }
        
        stage('Deploy Infrastructure') {
            when {
                anyOf {
                    expression { params.DEPLOYMENT_TYPE == 'full' }
                    expression { params.DEPLOYMENT_TYPE == 'config-only' }
                }
            }
            steps {
                script {
                    def dryRunFlag = params.DRY_RUN ? '--check' : ''
                    sh """
                        ansible-playbook -i inventory/hosts.yml playbooks/site.yml \\
                            --limit ${ENVIRONMENT} \\
                            ${dryRunFlag} \\
                            --extra-vars "deployment_id=${BUILD_NUMBER}-${BUILD_TIMESTAMP}"
                    """
                }
            }
        }
        
        stage('Deploy Application') {
            when {
                anyOf {
                    expression { params.DEPLOYMENT_TYPE == 'full' }
                    expression { params.DEPLOYMENT_TYPE == 'app-only' }
                }
            }
            steps {
                script {
                    def dryRunFlag = params.DRY_RUN ? '--check' : ''
                    sh """
                        ansible-playbook -i inventory/hosts.yml playbooks/deploy_app.yml \\
                            --limit ${ENVIRONMENT} \\
                            ${dryRunFlag} \\
                            --extra-vars "app_version=${BUILD_NUMBER} deployment_id=${BUILD_NUMBER}-${BUILD_TIMESTAMP}"
                    """
                }
            }
        }
        
        stage('Health Check') {
            when {
                not { params.DRY_RUN }
            }
            steps {
                sh '''
                    ansible-playbook -i inventory/hosts.yml playbooks/health_check.yml \\
                        --limit ${ENVIRONMENT}
                '''
            }
        }
        
        stage('Performance Test') {
            when {
                allOf {
                    not { params.DRY_RUN }
                    expression { params.ENVIRONMENT != 'production' }
                }
            }
            steps {
                sh '''
                    ansible-playbook -i inventory/hosts.yml playbooks/performance_test.yml \\
                        --limit ${ENVIRONMENT}
                '''
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'logs/*.log', allowEmptyArchive: true
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'reports',
                reportFiles: 'deployment-report.html',
                reportName: 'Deployment Report'
            ])
        }
        success {
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: "✅ Deployment successful: ${ENVIRONMENT} - Build ${BUILD_NUMBER}"
            )
        }
        failure {
            slackSend(
                channel: '#deployments',
                color: 'danger',
                message: "❌ Deployment failed: ${ENVIRONMENT} - Build ${BUILD_NUMBER}"
            )
        }
    }
}
```

#### **2. GitLab CI Integration**

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - test
  - deploy-dev
  - deploy-staging
  - deploy-prod

variables:
  ANSIBLE_CONFIG: "${CI_PROJECT_DIR}/ansible.cfg"
  ANSIBLE_VAULT_PASSWORD_FILE: "/tmp/vault_pass"

before_script:
  - echo "$VAULT_PASSWORD" > /tmp/vault_pass
  - chmod 600 /tmp/vault_pass
  - pip install ansible ansible-lint yamllint

validate-syntax:
  stage: validate
  script:
    - ansible-playbook --syntax-check playbooks/site.yml
    - ansible-lint playbooks/
    - yamllint inventory/
  only:
    - merge_requests
    - main

test-connectivity:
  stage: test
  script:
    - ansible all -i inventory/hosts.yml -m ping --limit development
  only:
    - merge_requests
    - main

deploy-development:
  stage: deploy-dev
  script:
    - |
      ansible-playbook -i inventory/hosts.yml playbooks/site.yml \
        --limit development \
        --extra-vars "deployment_id=${CI_PIPELINE_ID}-${CI_COMMIT_SHORT_SHA}"
  environment:
    name: development
    url: https://dev.myapp.com
  only:
    - main

deploy-staging:
  stage: deploy-staging
  script:
    - |
      ansible-playbook -i inventory/hosts.yml playbooks/site.yml \
        --limit staging \
        --extra-vars "deployment_id=${CI_PIPELINE_ID}-${CI_COMMIT_SHORT_SHA}"
  environment:
    name: staging
    url: https://staging.myapp.com
  when: manual
  only:
    - main

deploy-production:
  stage: deploy-prod
  script:
    - |
      ansible-playbook -i inventory/hosts.yml playbooks/site.yml \
        --limit production \
        --extra-vars "deployment_id=${CI_PIPELINE_ID}-${CI_COMMIT_SHORT_SHA}"
  environment:
    name: production
    url: https://myapp.com
  when: manual
  only:
    - main
  before_script:
    - echo "Deploying to production - Build ${CI_PIPELINE_ID}"
  after_script:
    - echo "Production deployment completed"
```

#### **3. GitHub Actions Workflow**

```yaml
# .github/workflows/ansible-deploy.yml
name: Ansible Deployment

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'development'
        type: choice
        options:
          - development
          - staging
          - production
      dry_run:
        description: 'Perform dry run'
        required: false
        default: false
        type: boolean

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
          
      - name: Install Ansible
        run: |
          pip install ansible ansible-lint yamllint
          
      - name: Validate syntax
        run: |
          ansible-playbook --syntax-check playbooks/site.yml
          ansible-lint playbooks/
          yamllint inventory/

  deploy:
    needs: validate
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'
    
    strategy:
      matrix:
        environment: 
          - ${{ github.event.inputs.environment || 'development' }}
    
    environment: ${{ matrix.environment }}
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
          
      - name: Install Ansible
        run: pip install ansible
        
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.7.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
          
      - name: Setup Vault Password
        run: echo "${{ secrets.VAULT_PASSWORD }}" > vault_pass.txt
        
      - name: Deploy
        run: |
          export ANSIBLE_VAULT_PASSWORD_FILE=vault_pass.txt
          DRY_RUN_FLAG=""
          if [ "${{ github.event.inputs.dry_run }}" = "true" ]; then
            DRY_RUN_FLAG="--check"
          fi
          
          ansible-playbook -i inventory/hosts.yml playbooks/site.yml \
            --limit ${{ matrix.environment }} \
            $DRY_RUN_FLAG \
            --extra-vars "deployment_id=${{ github.run_number }}-${{ github.sha }}"
            
      - name: Cleanup
        if: always()
        run: rm -f vault_pass.txt
```

---

## 🌍 Multi-Environment Management

### **Environment Configuration Strategy**

#### **1. Environment-Specific Inventory Structure**

```yaml
# inventory/environments/development/hosts.yml
all:
  children:
    webservers:
      hosts:
        dev-web-01:
          ansible_host: 10.0.1.10
          app_replicas: 1
        dev-web-02:
          ansible_host: 10.0.1.11
          app_replicas: 1
    databases:
      hosts:
        dev-db-01:
          ansible_host: 10.0.1.20
          mysql_max_connections: 100

# inventory/environments/production/hosts.yml
all:
  children:
    webservers:
      hosts:
        prod-web-01:
          ansible_host: 192.168.1.10
          app_replicas: 3
        prod-web-02:
          ansible_host: 192.168.1.11
          app_replicas: 3
        prod-web-03:
          ansible_host: 192.168.1.12
          app_replicas: 3
    databases:
      hosts:
        prod-db-01:
          ansible_host: 192.168.1.20
          mysql_max_connections: 500
        prod-db-02:
          ansible_host: 192.168.1.21
          mysql_max_connections: 500
```

#### **2. Environment Variables Management**

```yaml
# group_vars/environments/development/all.yml
---
environment_name: development
environment_tier: dev

# Database configuration
database_host: dev-db-01
database_name: myapp_dev
database_pool_size: 5
database_backup_enabled: false

# Application configuration
app_debug: true
app_log_level: debug
app_cache_enabled: false
app_session_timeout: 3600

# Security settings
ssl_enabled: false
cors_enabled: true
rate_limiting: false

# Resource limits
cpu_limit: 1
memory_limit: 512Mi
disk_space_alert_threshold: 70

# Monitoring
monitoring_enabled: true
log_retention_days: 7
metrics_collection_interval: 60

# Deployment settings
deployment_strategy: recreate
max_unavailable: 100%
health_check_timeout: 30
```

```yaml
# group_vars/environments/production/all.yml
---
environment_name: production
environment_tier: prod

# Database configuration
database_host: prod-db-cluster
database_name: myapp_prod
database_pool_size: 50
database_backup_enabled: true
database_backup_schedule: "0 2 * * *"

# Application configuration
app_debug: false
app_log_level: warn
app_cache_enabled: true
app_session_timeout: 1800

# Security settings
ssl_enabled: true
cors_enabled: false
rate_limiting: true
rate_limit_requests_per_minute: 1000

# Resource limits
cpu_limit: 4
memory_limit: 4Gi
disk_space_alert_threshold: 85

# Monitoring
monitoring_enabled: true
log_retention_days: 90
metrics_collection_interval: 10

# Deployment settings
deployment_strategy: rolling
max_unavailable: 25%
max_surge: 25%
health_check_timeout: 120
```

#### **3. Environment-Aware Deployment Playbook**

```yaml
# playbooks/multi-env-deploy.yml
---
- name: Multi-Environment Deployment
  hosts: all
  vars:
    environment: "{{ target_env | default('development') }}"
    deployment_timestamp: "{{ ansible_date_time.epoch }}"
    
  pre_tasks:
    - name: Validate environment
      assert:
        that:
          - environment in ['development', 'staging', 'production']
        fail_msg: "Invalid environment: {{ environment }}"
        
    - name: Load environment-specific variables
      include_vars: "group_vars/environments/{{ environment }}/all.yml"
      
    - name: Production deployment confirmation
      pause:
        prompt: |
          ⚠️  PRODUCTION DEPLOYMENT WARNING ⚠️
          
          You are about to deploy to PRODUCTION environment!
          
          Environment: {{ environment }}
          Timestamp: {{ ansible_date_time.iso8601 }}
          Target hosts: {{ groups['all'] | length }}
          
          Are you sure you want to continue? (yes/no)
      when: 
        - environment == 'production'
        - not (auto_approve | default(false) | bool)
      delegate_to: localhost
      run_once: true

  tasks:
    - name: Set deployment facts
      set_fact:
        deployment_id: "{{ environment }}-{{ deployment_timestamp }}"
        deployment_config:
          environment: "{{ environment }}"
          timestamp: "{{ ansible_date_time.iso8601 }}"
          user: "{{ ansible_user_id }}"
          hosts: "{{ groups['all'] }}"
          
    - name: Create deployment directory
      file:
        path: "/opt/deployments/{{ deployment_id }}"
        state: directory
        mode: '0755'
      become: yes
      
    - name: Environment-specific configuration
      template:
        src: "config/{{ environment }}/app.conf.j2"
        dest: "/opt/app/config/app.conf"
        backup: yes
      notify: restart application
      
    - name: Deploy based on environment strategy
      include_tasks: "tasks/deploy-{{ deployment_strategy }}.yml"
      
    - name: Environment-specific health checks
      uri:
        url: "http://{{ inventory_hostname }}:{{ app_port }}/health"
        method: GET
        status_code: 200
        timeout: "{{ health_check_timeout }}"
      retries: 5
      delay: 10
      
    - name: Record deployment
      copy:
        content: |
          {{ deployment_config | to_nice_json }}
        dest: "/opt/deployments/{{ deployment_id }}/deployment-info.json"
      become: yes

  post_tasks:
    - name: Environment-specific notifications
      include_tasks: "tasks/notify-{{ environment }}.yml"
      
    - name: Update monitoring dashboards
      uri:
        url: "{{ grafana_api_url }}/api/annotations"
        method: POST
        headers:
          Authorization: "Bearer {{ grafana_api_token }}"
        body_format: json
        body:
          text: "Deployment completed: {{ deployment_id }}"
          tags: ["deployment", "{{ environment }}"]
          time: "{{ ansible_date_time.epoch | int * 1000 }}"
      when: grafana_api_url is defined
```

---

## 💾 Backup e Disaster Recovery

### **Comprehensive Backup Strategy**

#### **1. Database Backup Automation**

```yaml
# playbooks/backup-databases.yml
---
- name: Database Backup Automation
  hosts: databases
  vars:
    backup_root: "/backup"
    backup_retention_days: 30
    compress_backups: true
    encrypt_backups: true
    
  tasks:
    - name: Create backup directories
      file:
        path: "{{ item }}"
        state: directory
        mode: '0750'
        owner: backup
        group: backup
      loop:
        - "{{ backup_root }}"
        - "{{ backup_root }}/mysql"
        - "{{ backup_root }}/postgresql"
        - "{{ backup_root }}/mongodb"
      become: yes
      
    - name: MySQL backup
      shell: |
        mysqldump --all-databases \
          --single-transaction \
          --triggers \
          --routines \
          --events \
          --user={{ mysql_backup_user }} \
          --password={{ mysql_backup_password }} \
          > {{ backup_root }}/mysql/mysql-backup-{{ ansible_date_time.date }}.sql
      when: mysql_enabled | default(false)
      become: yes
      become_user: backup
      
    - name: PostgreSQL backup
      postgresql_db:
        name: "{{ item }}"
        state: dump
        target: "{{ backup_root }}/postgresql/{{ item }}-{{ ansible_date_time.date }}.sql"
      loop: "{{ postgresql_databases }}"
      when: postgresql_enabled | default(false)
      become: yes
      become_user: postgres
      
    - name: MongoDB backup
      shell: |
        mongodump --host {{ mongodb_host }} \
          --port {{ mongodb_port }} \
          --out {{ backup_root }}/mongodb/mongodb-backup-{{ ansible_date_time.date }}
      when: mongodb_enabled | default(false)
      become: yes
      become_user: backup
      
    - name: Compress backups
      archive:
        path: "{{ backup_root }}/*/{{ item }}"
        dest: "{{ backup_root }}/compressed/{{ item }}.tar.gz"
        format: gz
        remove: yes
      with_fileglob:
        - "*-{{ ansible_date_time.date }}*"
      when: compress_backups | bool
      become: yes
      
    - name: Encrypt backups
      shell: |
        gpg --cipher-algo AES256 \
          --compress-algo 1 \
          --symmetric \
          --output {{ item }}.gpg \
          --passphrase {{ backup_encryption_key }} \
          {{ item }}
        rm {{ item }}
      with_fileglob:
        - "{{ backup_root }}/compressed/*.tar.gz"
      when: encrypt_backups | bool
      become: yes
      
    - name: Upload to S3
      aws_s3:
        bucket: "{{ s3_backup_bucket }}"
        object: "backups/{{ inventory_hostname }}/{{ ansible_date_time.date }}/{{ item | basename }}"
        src: "{{ item }}"
        mode: put
        encrypt: yes
      with_fileglob:
        - "{{ backup_root }}/compressed/*"
      when: s3_backup_enabled | default(false)
      
    - name: Clean old local backups
      find:
        paths: "{{ backup_root }}"
        age: "{{ backup_retention_days }}d"
        recurse: yes
      register: old_backups
      
    - name: Remove old backups
      file:
        path: "{{ item.path }}"
        state: absent
      loop: "{{ old_backups.files }}"
      become: yes
```

#### **2. System Backup and Configuration**

```yaml
# playbooks/system-backup.yml
---
- name: System Configuration Backup
  hosts: all
  vars:
    system_backup_root: "/backup/system"
    config_paths:
      - /etc
      - /var/log
      - /opt/app/config
      - /home/deploy/.ssh
    
  tasks:
    - name: Create system backup directory
      file:
        path: "{{ system_backup_root }}/{{ inventory_hostname }}"
        state: directory
        mode: '0750'
      become: yes
      
    - name: Backup system configurations
      archive:
        path: "{{ config_paths }}"
        dest: "{{ system_backup_root }}/{{ inventory_hostname }}/system-config-{{ ansible_date_time.date }}.tar.gz"
        format: gz
        exclude_path:
          - "*/tmp/*"
          - "*/cache/*"
          - "*/log/*.log"
      become: yes
      
    - name: Backup installed packages (Debian/Ubuntu)
      shell: |
        dpkg --get-selections > {{ system_backup_root }}/{{ inventory_hostname }}/packages-{{ ansible_date_time.date }}.list
        apt-mark showauto > {{ system_backup_root }}/{{ inventory_hostname }}/packages-auto-{{ ansible_date_time.date }}.list
      when: ansible_os_family == "Debian"
      become: yes
      
    - name: Backup installed packages (RHEL/CentOS)
      shell: |
        rpm -qa > {{ system_backup_root }}/{{ inventory_hostname }}/packages-{{ ansible_date_time.date }}.list
        yum history list > {{ system_backup_root }}/{{ inventory_hostname }}/yum-history-{{ ansible_date_time.date }}.list
      when: ansible_os_family == "RedHat"
      become: yes
      
    - name: Backup crontabs
      shell: |
        for user in $(cut -f1 -d: /etc/passwd); do
          crontab -u $user -l > {{ system_backup_root }}/{{ inventory_hostname }}/crontab-$user-{{ ansible_date_time.date }}.txt 2>/dev/null || true
        done
      become: yes
      
    - name: Generate system inventory
      copy:
        content: |
          # System Inventory - {{ ansible_date_time.iso8601 }}
          
          ## Hardware Info
          - Hostname: {{ ansible_hostname }}
          - FQDN: {{ ansible_fqdn }}
          - OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
          - Kernel: {{ ansible_kernel }}
          - Architecture: {{ ansible_architecture }}
          - CPU: {{ ansible_processor_count }} cores ({{ ansible_processor[1] }})
          - Memory: {{ ansible_memtotal_mb }}MB
          
          ## Network Configuration
          - Default IPv4: {{ ansible_default_ipv4.address }}
          - Gateway: {{ ansible_default_ipv4.gateway }}
          - DNS: {{ ansible_dns.nameservers | join(', ') }}
          
          ## Disk Information
          {% for mount in ansible_mounts %}
          - {{ mount.mount }}: {{ mount.size_total // 1024 // 1024 // 1024 }}GB ({{ mount.fstype }})
          {% endfor %}
          
          ## Services
          {% for service in ansible_facts.services.keys() | list | sort %}
          {% if ansible_facts.services[service].state == 'running' %}
          - {{ service }}: {{ ansible_facts.services[service].state }}
          {% endif %}
          {% endfor %}
        dest: "{{ system_backup_root }}/{{ inventory_hostname }}/system-inventory-{{ ansible_date_time.date }}.md"
      become: yes
```

#### **3. Disaster Recovery Playbook**

```yaml
# playbooks/disaster-recovery.yml
---
- name: Disaster Recovery Restoration
  hosts: "{{ recovery_target | default('all') }}"
  vars:
    recovery_mode: "{{ mode | default('partial') }}"  # partial, full, minimal
    backup_source: "{{ source | default('latest') }}"
    
  pre_tasks:
    - name: Disaster recovery confirmation
      pause:
        prompt: |
          ⚠️  DISASTER RECOVERY WARNING ⚠️
          
          This will restore system from backup!
          Target: {{ inventory_hostname }}
          Mode: {{ recovery_mode }}
          Source: {{ backup_source }}
          
          Continue? (yes/no)
      when: not (auto_confirm | default(false) | bool)
      
  tasks:
    - name: Stop all services
      systemd:
        name: "{{ item }}"
        state: stopped
      loop: "{{ services_to_stop }}"
      ignore_errors: yes
      become: yes
      
    - name: Download backup from S3
      aws_s3:
        bucket: "{{ s3_backup_bucket }}"
        object: "backups/{{ inventory_hostname }}/{{ backup_source }}/{{ item }}"
        dest: "/tmp/{{ item }}"
        mode: get
      loop: "{{ backup_files_to_restore }}"
      when: s3_restore_enabled | default(false)
      
    - name: Restore system configuration
      unarchive:
        src: "/tmp/system-config-{{ backup_source }}.tar.gz"
        dest: "/"
        remote_src: yes
        backup: yes
      when: recovery_mode in ['full', 'partial']
      become: yes
      
    - name: Restore database
      block:
        - name: Restore MySQL
          mysql_db:
            name: all
            state: import
            target: "/tmp/mysql-backup-{{ backup_source }}.sql"
          when: mysql_enabled | default(false)
          
        - name: Restore PostgreSQL
          postgresql_db:
            name: "{{ item.name }}"
            state: restore
            target: "/tmp/{{ item.name }}-{{ backup_source }}.sql"
          loop: "{{ postgresql_databases }}"
          when: postgresql_enabled | default(false)
      when: recovery_mode == 'full'
      become: yes
      
    - name: Restore application data
      unarchive:
        src: "/tmp/app-data-{{ backup_source }}.tar.gz"
        dest: "/opt/app"
        remote_src: yes
        owner: app
        group: app
      when: recovery_mode in ['full', 'partial']
      become: yes
      
    - name: Start services
      systemd:
        name: "{{ item }}"
        state: started
        enabled: yes
      loop: "{{ services_to_start }}"
      become: yes
      
    - name: Health check post-recovery
      uri:
        url: "http://{{ inventory_hostname }}:{{ app_port }}/health"
        method: GET
        status_code: 200
      retries: 10
      delay: 30
      
    - name: Recovery validation
      shell: |
        # Custom validation scripts
        /opt/scripts/validate-recovery.sh
      register: validation_result
      become: yes
      
    - name: Recovery report
      copy:
        content: |
          # Disaster Recovery Report
          
          ## Recovery Details
          - Target: {{ inventory_hostname }}
          - Mode: {{ recovery_mode }}
          - Source: {{ backup_source }}
          - Started: {{ ansible_date_time.iso8601 }}
          - Duration: {{ ansible_play_duration }}
          
          ## Validation Results
          {{ validation_result.stdout }}
          
          ## Services Status
          {% for service in services_to_start %}
          - {{ service }}: {{ 'OK' if ansible_facts.services[service].state == 'running' else 'FAILED' }}
          {% endfor %}
        dest: "/var/log/recovery-report-{{ ansible_date_time.epoch }}.md"
      become: yes
```

---

## ⚖️ Scaling e Load Balancing

### **Auto-Scaling Infrastructure**

#### **1. Dynamic Inventory with Cloud Providers**

```python
#!/usr/bin/env python3
# scripts/dynamic_inventory.py

import json
import boto3
import sys
from datetime import datetime

class DynamicInventory:
    def __init__(self):
        self.inventory = {'_meta': {'hostvars': {}}}
        
    def get_aws_instances(self):
        """Get AWS EC2 instances"""
        ec2 = boto3.client('ec2')
        
        response = ec2.describe_instances(
            Filters=[
                {'Name': 'instance-state-name', 'Values': ['running']},
                {'Name': 'tag:Environment', 'Values': ['production', 'staging']}
            ]
        )
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
                
                hostname = tags.get('Name', instance['InstanceId'])
                environment = tags.get('Environment', 'unknown')
                role = tags.get('Role', 'unknown')
                
                # Add to environment group
                if environment not in self.inventory:
                    self.inventory[environment] = {'hosts': []}
                self.inventory[environment]['hosts'].append(hostname)
                
                # Add to role group
                if role not in self.inventory:
                    self.inventory[role] = {'hosts': []}
                self.inventory[role]['hosts'].append(hostname)
                
                # Add host variables
                self.inventory['_meta']['hostvars'][hostname] = {
                    'ansible_host': instance['PublicIpAddress'],
                    'ansible_user': 'ec2-user',
                    'instance_id': instance['InstanceId'],
                    'instance_type': instance['InstanceType'],
                    'availability_zone': instance['Placement']['AvailabilityZone'],
                    'environment': environment,
                    'role': role,
                    'tags': tags
                }
    
    def get_azure_instances(self):
        """Get Azure VM instances"""
        try:
            from azure.identity import DefaultAzureCredential
            from azure.mgmt.compute import ComputeManagementClient
            
            credential = DefaultAzureCredential()
            compute_client = ComputeManagementClient(credential, subscription_id)
            
            for vm in compute_client.virtual_machines.list_all():
                # Process Azure VMs similar to AWS
                pass
        except ImportError:
            pass
    
    def generate_inventory(self):
        """Generate complete inventory"""
        self.get_aws_instances()
        self.get_azure_instances()
        
        # Add meta groups
        self.inventory['all'] = {'children': list(self.inventory.keys())}
        self.inventory['all']['children'].remove('_meta')
        
        return self.inventory

if __name__ == '__main__':
    inventory = DynamicInventory()
    
    if len(sys.argv) == 2 and sys.argv[1] == '--list':
        print(json.dumps(inventory.generate_inventory(), indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == '--host':
        # Return empty dict for host-specific vars (handled in --list)
        print(json.dumps({}))
    else:
        print("Usage: {} --list | --host <hostname>".format(sys.argv[0]))
```

#### **2. Load Balancer Configuration**

```yaml
# playbooks/setup-load-balancer.yml
---
- name: Setup HAProxy Load Balancer
  hosts: load_balancers
  vars:
    haproxy_stats_enabled: true
    haproxy_stats_port: 8404
    haproxy_stats_user: admin
    ssl_enabled: true
    
  tasks:
    - name: Install HAProxy
      package:
        name: haproxy
        state: present
      become: yes
      
    - name: Configure HAProxy
      template:
        src: haproxy.cfg.j2
        dest: /etc/haproxy/haproxy.cfg
        backup: yes
      notify: restart haproxy
      become: yes
      
    - name: Configure SSL certificates
      copy:
        src: "{{ ssl_cert_path }}"
        dest: /etc/ssl/certs/server.pem
        mode: '0600'
      when: ssl_enabled | bool
      notify: restart haproxy
      become: yes
      
    - name: Start and enable HAProxy
      systemd:
        name: haproxy
        state: started
        enabled: yes
      become: yes
      
    - name: Configure health check endpoint
      copy:
        content: |
          #!/bin/bash
          # HAProxy health check script
          
          STATS_URL="http://localhost:{{ haproxy_stats_port }}/stats"
          
          # Check HAProxy status
          if curl -s "$STATS_URL" >/dev/null; then
            echo "OK - HAProxy is running"
            exit 0
          else
            echo "CRITICAL - HAProxy is not responding"
            exit 2
          fi
        dest: /opt/scripts/check-haproxy.sh
        mode: '0755'
      become: yes

  handlers:
    - name: restart haproxy
      systemd:
        name: haproxy
        state: restarted
      become: yes
```

```jinja2
{# templates/haproxy.cfg.j2 #}
global
    daemon
    maxconn 4096
    log stdout local0
    
    # SSL Configuration
    ssl-default-bind-ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    option httplog
    option dontlognull
    option http-server-close
    option forwardfor except 127.0.0.0/8
    option redispatch
    retries 3

# Statistics interface
{% if haproxy_stats_enabled %}
listen stats
    bind *:{{ haproxy_stats_port }}
    stats enable
    stats uri /stats
    stats admin if TRUE
    stats auth {{ haproxy_stats_user }}:{{ haproxy_stats_password }}
{% endif %}

# Frontend configuration
frontend web_frontend
    bind *:80
{% if ssl_enabled %}
    bind *:443 ssl crt /etc/ssl/certs/server.pem
    redirect scheme https if !{ ssl_fc }
{% endif %}
    
    # ACLs for routing
    acl is_api path_beg /api
    acl is_static path_beg /static /css /js /images
    
    # Routing rules
    use_backend api_servers if is_api
    use_backend static_servers if is_static
    default_backend web_servers

# Backend configurations
backend web_servers
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    
{% for host in groups['webservers'] %}
    server {{ host }} {{ hostvars[host]['ansible_host'] }}:{{ app_port | default(8080) }} check
{% endfor %}

backend api_servers
    balance roundrobin
    option httpchk GET /api/health
    http-check expect status 200
    
{% for host in groups['api_servers'] %}
    server {{ host }} {{ hostvars[host]['ansible_host'] }}:{{ api_port | default(8000) }} check
{% endfor %}

{% if groups['static_servers'] is defined %}
backend static_servers
    balance roundrobin
    option httpchk GET /ping
    
{% for host in groups['static_servers'] %}
    server {{ host }} {{ hostvars[host]['ansible_host'] }}:{{ static_port | default(80) }} check
{% endfor %}
{% endif %}
```

#### **3. Auto-Scaling Playbook**

```yaml
# playbooks/auto-scaling.yml
---
- name: Auto-Scaling Management
  hosts: localhost
  vars:
    scale_action: "{{ action | default('check') }}"  # check, scale_up, scale_down
    target_group: "{{ group | default('webservers') }}"
    min_instances: "{{ min | default(2) }}"
    max_instances: "{{ max | default(10) }}"
    cpu_threshold_up: 70
    cpu_threshold_down: 30
    
  tasks:
    - name: Get current metrics
      uri:
        url: "{{ prometheus_url }}/api/v1/query"
        method: GET
        body_format: form-urlencoded
        body:
          query: "avg(100 - (avg by(instance) (irate(node_cpu_seconds_total{mode='idle'}[5m])) * 100))"
      register: cpu_metrics
      
    - name: Parse CPU utilization
      set_fact:
        current_cpu: "{{ cpu_metrics.json.data.result[0].value[1] | float }}"
        current_instances: "{{ groups[target_group] | length }}"
        
    - name: Determine scaling action
      set_fact:
        should_scale_up: "{{ current_cpu > cpu_threshold_up and current_instances < max_instances }}"
        should_scale_down: "{{ current_cpu < cpu_threshold_down and current_instances > min_instances }}"
        
    - name: Scale up decision
      debug:
        msg: |
          🔺 SCALE UP TRIGGERED:
          - Current CPU: {{ current_cpu }}%
          - Threshold: {{ cpu_threshold_up }}%
          - Current instances: {{ current_instances }}
          - Will scale to: {{ current_instances + 1 }}
      when: should_scale_up | bool
      
    - name: Scale down decision
      debug:
        msg: |
          🔻 SCALE DOWN TRIGGERED:
          - Current CPU: {{ current_cpu }}%
          - Threshold: {{ cpu_threshold_down }}%
          - Current instances: {{ current_instances }}
          - Will scale to: {{ current_instances - 1 }}
      when: should_scale_down | bool
      
    - name: Launch new instance (AWS)
      ec2_instance:
        name: "{{ target_group }}-{{ ansible_date_time.epoch }}"
        image_id: "{{ base_ami_id }}"
        instance_type: "{{ instance_type }}"
        key_name: "{{ ssh_key_name }}"
        vpc_subnet_id: "{{ subnet_id }}"
        security_groups: "{{ security_group_ids }}"
        tags:
          Environment: "{{ environment }}"
          Role: "{{ target_group }}"
          ScalingGroup: "{{ target_group }}"
        user_data: |
          #!/bin/bash
          # Bootstrap script for new instances
          yum update -y
          yum install -y python3
          
          # Install application
          aws s3 cp s3://{{ deployment_bucket }}/latest/app.tar.gz /tmp/
          cd /opt && tar -xzf /tmp/app.tar.gz
          
          # Start services
          systemctl enable app
          systemctl start app
        wait: yes
        wait_timeout: 300
      register: new_instance
      when: 
        - should_scale_up | bool
        - scale_action == 'scale_up'
        
    - name: Add new instance to inventory
      add_host:
        hostname: "{{ new_instance.instances[0].tags.Name }}"
        ansible_host: "{{ new_instance.instances[0].public_ip_address }}"
        groups: "{{ target_group }}"
      when: 
        - should_scale_up | bool
        - new_instance is succeeded
        
    - name: Wait for new instance to be ready
      wait_for:
        host: "{{ new_instance.instances[0].public_ip_address }}"
        port: 22
        timeout: 300
      when: 
        - should_scale_up | bool
        - new_instance is succeeded
        
    - name: Configure new instance
      include: playbooks/site.yml
      vars:
        target_hosts: "{{ new_instance.instances[0].tags.Name }}"
      when: 
        - should_scale_up | bool
        - new_instance is succeeded
        
    - name: Add to load balancer
      uri:
        url: "{{ load_balancer_api }}/servers"
        method: POST
        body_format: json
        body:
          name: "{{ new_instance.instances[0].tags.Name }}"
          address: "{{ new_instance.instances[0].private_ip_address }}"
          port: "{{ app_port }}"
      when: 
        - should_scale_up | bool
        - new_instance is succeeded
        
    - name: Terminate instance for scale down
      ec2_instance:
        instance_ids: "{{ instance_to_terminate }}"
        state: terminated
      when: 
        - should_scale_down | bool
        - scale_action == 'scale_down'
        
    - name: Send scaling notification
      uri:
        url: "{{ slack_webhook_url }}"
        method: POST
        body_format: json
        body:
          text: |
            {% if should_scale_up %}🔺 Scaled UP{% elif should_scale_down %}🔻 Scaled DOWN{% endif %} {{ target_group }}
            
            - CPU: {{ current_cpu }}%
            - Instances: {{ current_instances }} → {{ current_instances + 1 if should_scale_up else current_instances - 1 }}
            - Environment: {{ environment }}
      when: should_scale_up | bool or should_scale_down | bool
```

---

## ✅ Checkpoint Finale

Verifica che tutti i componenti avanzati funzionino:

```bash
# Test CI/CD integration
git push origin main  # Trigger pipeline

# Test multi-environment deployment
ansible-playbook playbooks/multi-env-deploy.yml -e "target_env=staging"

# Test backup system
ansible-playbook playbooks/backup-databases.yml

# Test disaster recovery (dry run)
ansible-playbook playbooks/disaster-recovery.yml -e "recovery_mode=minimal" --check

# Test auto-scaling
ansible-playbook playbooks/auto-scaling.yml -e "action=check"

# Test load balancer
curl -I http://your-load-balancer/health
```

> **🎉 COMPLETAMENTO GUIDA**: Hai completato con successo tutti i 10 capitoli della guida completa Ansible! Ora hai le competenze per gestire infrastrutture enterprise complesse.

---

## 🏆 Cosa Hai Imparato

Dopo aver completato questa guida di 10 capitoli, ora sei in grado di:

✅ **Installare e configurare** Ansible su qualsiasi piattaforma  
✅ **Gestire infrastrutture** Linux e Windows da un unico punto  
✅ **Creare playbook complessi** con roles, template e best practices  
✅ **Implementare deployment automatizzati** con rollback e health checks  
✅ **Configurare monitoraggio** completo con alerting  
✅ **Debuggare e risolvere** problemi complessi  
✅ **Integrare con CI/CD** pipeline enterprise  
✅ **Gestire multi-environment** con configurazioni dinamiche  
✅ **Implementare backup** e disaster recovery  
✅ **Configurare auto-scaling** e load balancing  

## 🔗 Prossimi Passi

### **Approfondimenti Consigliati**
- [**Ansible Galaxy**](https://galaxy.ansible.com/) - Roles e collections della community
- [**Ansible AWX/Tower**](https://github.com/ansible/awx) - Interface web enterprise
- [**Ansible Collections**](https://docs.ansible.com/ansible/latest/collections_guide/) - Moduli specializzati
- [**Red Hat Ansible Automation Platform**](https://www.redhat.com/en/technologies/management/ansible) - Versione enterprise

### **Certificazioni**
- **Red Hat Certified Specialist in Ansible Automation**
- **Red Hat Certified Engineer (RHCE)**

---

## 📚 Risorse Finali

- [Documentazione Ufficiale Ansible](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Community Forums](https://forum.ansible.com/)
- [GitHub Repository](https://github.com/ansible/ansible)
