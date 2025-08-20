# 📊 Capitolo 8 - Monitoraggio e Logging

> **Obiettivo**: Implementare sistemi completi di monitoraggio, logging e alerting per mantenere sotto controllo l'infrastruttura e le applicazioni gestite con Ansible.

## 📋 Indice del Capitolo

1. [Configurazione Logging Ansible](#configurazione-logging-ansible)
2. [Monitoring dell'Infrastruttura](#monitoring-dellinfrastruttura)
3. [Application Performance Monitoring](#application-performance-monitoring)
4. [Alerting e Notifiche](#alerting-e-notifiche)
5. [Dashboard e Reporting](#dashboard-e-reporting)
6. [Log Aggregation](#log-aggregation)
7. [Troubleshooting con i Log](#troubleshooting-con-i-log)

---

## 📝 Configurazione Logging Ansible

### **Configurazione Base Logging**

#### **1. ansible.cfg - Logging Avanzato**
```ini
# ansible.cfg
[defaults]
# Log file principale
log_path = /var/log/ansible/ansible.log

# Callback plugins per logging esteso
callback_plugins = /usr/share/ansible/plugins/callback
stdout_callback = yaml
callback_whitelist = timer, profile_tasks, log_plays

# Verbose logging
display_skipped_hosts = True
display_ok_hosts = True
host_key_checking = False

# Performance monitoring
gather_timeout = 30
timeout = 60

[callback_profile_tasks]
# Mostra timing delle task
task_output_limit = 100
sort_order = none

[callback_timer]
# Mostra tempo totale di esecuzione
```

#### **2. Custom Callback Plugin per Logging**
```python
# callback_plugins/custom_logger.py
import json
import datetime
from ansible.plugins.callback import CallbackBase

class CallbackModule(CallbackBase):
    """
    Custom callback plugin per logging avanzato
    """
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'aggregate'
    CALLBACK_NAME = 'custom_logger'

    def __init__(self):
        super(CallbackModule, self).__init__()
        self.start_time = datetime.datetime.now()
        self.log_file = '/var/log/ansible/detailed.log'

    def log_event(self, event_type, data):
        timestamp = datetime.datetime.now().isoformat()
        log_entry = {
            'timestamp': timestamp,
            'event_type': event_type,
            'data': data
        }
        
        with open(self.log_file, 'a') as f:
            f.write(json.dumps(log_entry) + '\n')

    def v2_playbook_on_start(self, playbook):
        self.log_event('playbook_start', {
            'playbook': playbook._file_name,
            'start_time': self.start_time.isoformat()
        })

    def v2_runner_on_ok(self, result):
        self.log_event('task_success', {
            'host': result._host.get_name(),
            'task': result._task.get_name(),
            'duration': str(datetime.datetime.now() - self.start_time)
        })

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self.log_event('task_failed', {
            'host': result._host.get_name(),
            'task': result._task.get_name(),
            'error': result._result.get('msg', 'Unknown error'),
            'duration': str(datetime.datetime.now() - self.start_time)
        })
```

#### **3. Structured Logging con JSON**
```yaml
# playbooks/logging-example.yml
---
- name: Esempio Structured Logging
  hosts: all
  vars:
    log_format: json
    log_level: info
  
  tasks:
    - name: Log structured event
      debug:
        msg: |
          {
            "event": "deployment_start",
            "timestamp": "{{ ansible_date_time.iso8601 }}",
            "host": "{{ inventory_hostname }}",
            "user": "{{ ansible_user_id }}",
            "playbook": "{{ ansible_play_name }}",
            "version": "{{ app_version | default('unknown') }}"
          }
      tags: [logging]

    - name: Custom logging task
      shell: |
        echo "{
          \"timestamp\": \"$(date -Iseconds)\",
          \"level\": \"INFO\",
          \"message\": \"Task completed\",
          \"host\": \"{{ inventory_hostname }}\",
          \"task\": \"{{ ansible_task_name }}\"
        }" >> /var/log/ansible/structured.log
      become: yes
```

---

## 📈 Monitoring dell'Infrastruttura

### **Setup Prometheus + Grafana**

#### **1. Installazione Prometheus**
```yaml
# playbooks/setup-prometheus.yml
---
- name: Setup Prometheus Monitoring
  hosts: monitoring
  become: yes
  
  tasks:
    - name: Create prometheus user
      user:
        name: prometheus
        system: yes
        shell: /bin/false
        home: /var/lib/prometheus
        create_home: yes

    - name: Download Prometheus
      get_url:
        url: "https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz"
        dest: /tmp/prometheus.tar.gz

    - name: Extract Prometheus
      unarchive:
        src: /tmp/prometheus.tar.gz
        dest: /opt/
        remote_src: yes
        creates: /opt/prometheus-2.45.0.linux-amd64

    - name: Create symlink
      file:
        src: /opt/prometheus-2.45.0.linux-amd64
        dest: /opt/prometheus
        state: link

    - name: Copy Prometheus binary
      copy:
        src: /opt/prometheus/prometheus
        dest: /usr/local/bin/prometheus
        mode: '0755'
        remote_src: yes

    - name: Create Prometheus directories
      file:
        path: "{{ item }}"
        state: directory
        owner: prometheus
        group: prometheus
        mode: '0755'
      loop:
        - /etc/prometheus
        - /var/lib/prometheus

    - name: Configure Prometheus
      template:
        src: prometheus.yml.j2
        dest: /etc/prometheus/prometheus.yml
        owner: prometheus
        group: prometheus
        mode: '0644'
      notify: restart prometheus

    - name: Create Prometheus service
      template:
        src: prometheus.service.j2
        dest: /etc/systemd/system/prometheus.service
      notify:
        - reload systemd
        - restart prometheus

    - name: Start Prometheus
      systemd:
        name: prometheus
        state: started
        enabled: yes

  handlers:
    - name: reload systemd
      systemd:
        daemon_reload: yes

    - name: restart prometheus
      systemd:
        name: prometheus
        state: restarted
```

#### **2. Configurazione Prometheus**
```yaml
# templates/prometheus.yml.j2
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets:
{% for host in groups['all'] %}
        - '{{ hostvars[host]['ansible_default_ipv4']['address'] }}:9100'
{% endfor %}

  - job_name: 'ansible-exporter'
    static_configs:
      - targets: ['localhost:9419']

  - job_name: 'application'
    static_configs:
      - targets:
{% for host in groups['webservers'] %}
        - '{{ hostvars[host]['ansible_default_ipv4']['address'] }}:{{ app_metrics_port | default(8080) }}'
{% endfor %}

  - job_name: 'windows-exporter'
    static_configs:
      - targets:
{% for host in groups['windows'] %}
        - '{{ hostvars[host]['ansible_default_ipv4']['address'] }}:9182'
{% endfor %}
```

#### **3. Node Exporter Installation**
```yaml
# tasks/install-node-exporter.yml
---
- name: Install Node Exporter
  block:
    - name: Download Node Exporter
      get_url:
        url: "https://github.com/prometheus/node_exporter/releases/download/v1.6.0/node_exporter-1.6.0.linux-amd64.tar.gz"
        dest: /tmp/node_exporter.tar.gz

    - name: Extract Node Exporter
      unarchive:
        src: /tmp/node_exporter.tar.gz
        dest: /opt/
        remote_src: yes
        creates: /opt/node_exporter-1.6.0.linux-amd64

    - name: Copy Node Exporter binary
      copy:
        src: /opt/node_exporter-1.6.0.linux-amd64/node_exporter
        dest: /usr/local/bin/node_exporter
        mode: '0755'
        remote_src: yes

    - name: Create node_exporter user
      user:
        name: node_exporter
        system: yes
        shell: /bin/false

    - name: Create Node Exporter service
      copy:
        content: |
          [Unit]
          Description=Node Exporter
          After=network.target

          [Service]
          User=node_exporter
          Group=node_exporter
          Type=simple
          ExecStart=/usr/local/bin/node_exporter
          Restart=on-failure

          [Install]
          WantedBy=multi-user.target
        dest: /etc/systemd/system/node_exporter.service

    - name: Start Node Exporter
      systemd:
        name: node_exporter
        state: started
        enabled: yes
        daemon_reload: yes
  when: ansible_os_family != "Windows"
```

#### **4. Windows Monitoring**
```yaml
# tasks/install-windows-exporter.yml
---
- name: Install Windows Exporter
  block:
    - name: Download Windows Exporter
      win_get_url:
        url: "https://github.com/prometheus-community/windows_exporter/releases/download/v0.23.1/windows_exporter-0.23.1-amd64.msi"
        dest: "C:\\temp\\windows_exporter.msi"

    - name: Install Windows Exporter
      win_package:
        path: "C:\\temp\\windows_exporter.msi"
        state: present
        arguments: 'ENABLED_COLLECTORS="cpu,cs,logical_disk,net,os,service,system,textfile,memory"'

    - name: Configure Windows Exporter service
      win_service:
        name: windows_exporter
        state: started
        start_mode: auto

    - name: Open firewall for metrics
      win_firewall_rule:
        name: "Windows Exporter"
        localport: 9182
        action: allow
        direction: in
        protocol: tcp
        state: present
  when: ansible_os_family == "Windows"
```

### **Alert Rules**

#### **1. Alert Rules Configuration**
```yaml
# templates/alert_rules.yml.j2
groups:
  - name: infrastructure
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% for more than 5 minutes"

      - alert: DiskSpaceLow
        expr: (node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk usage is above 90% on {{ $labels.mountpoint }}"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} down"
          description: "{{ $labels.job }} on {{ $labels.instance }} has been down for more than 1 minute"

  - name: ansible
    rules:
      - alert: AnsiblePlaybookFailed
        expr: increase(ansible_playbook_failures_total[1h]) > 0
        labels:
          severity: warning
        annotations:
          summary: "Ansible playbook failures detected"
          description: "{{ $value }} playbook failures in the last hour"
```

---

## 🖥️ Application Performance Monitoring

### **APM Setup**

#### **1. Application Metrics Collection**
```yaml
# tasks/setup-app-monitoring.yml
---
- name: Setup Application Monitoring
  block:
    - name: Install application metrics dependencies
      package:
        name: "{{ item }}"
        state: present
      loop:
        - python3-pip
        - python3-prometheus-client
      when: ansible_os_family != "Windows"

    - name: Install metrics endpoint
      template:
        src: metrics_endpoint.py.j2
        dest: "{{ app_root }}/metrics/server.py"
        mode: '0644'

    - name: Create metrics service
      template:
        src: metrics.service.j2
        dest: /etc/systemd/system/app-metrics.service
      when: ansible_os_family != "Windows"

    - name: Start metrics service
      systemd:
        name: app-metrics
        state: started
        enabled: yes
        daemon_reload: yes
      when: ansible_os_family != "Windows"
```

#### **2. Custom Metrics Endpoint**
```python
# templates/metrics_endpoint.py.j2
#!/usr/bin/env python3
"""
Custom metrics endpoint for application monitoring
"""
import time
import psutil
import sqlite3
from prometheus_client import start_http_server, Gauge, Counter, Histogram
from flask import Flask

app = Flask(__name__)

# Metrics definitions
REQUEST_COUNT = Counter('app_requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('app_request_duration_seconds', 'Request latency')
ACTIVE_USERS = Gauge('app_active_users', 'Number of active users')
DB_CONNECTIONS = Gauge('app_db_connections', 'Number of database connections')
ERROR_RATE = Gauge('app_error_rate', 'Application error rate')

def collect_app_metrics():
    """Collect custom application metrics"""
    try:
        # Database connections
        with sqlite3.connect('{{ app_database }}') as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM active_connections")
            db_conn_count = cursor.fetchone()[0]
            DB_CONNECTIONS.set(db_conn_count)

        # System metrics
        cpu_percent = psutil.cpu_percent()
        memory_percent = psutil.virtual_memory().percent
        
        # Active users (example)
        with sqlite3.connect('{{ app_database }}') as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(DISTINCT user_id) FROM sessions WHERE last_activity > datetime('now', '-5 minutes')")
            active_users = cursor.fetchone()[0]
            ACTIVE_USERS.set(active_users)

    except Exception as e:
        print(f"Error collecting metrics: {e}")

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    collect_app_metrics()
    return generate_latest()

@app.route('/health')
def health():
    """Health check endpoint"""
    return {'status': 'healthy', 'timestamp': time.time()}

if __name__ == '__main__':
    # Start metrics server
    start_http_server({{ app_metrics_port | default(8080) }})
    app.run(host='0.0.0.0', port={{ app_health_port | default(5000) }})
```

#### **3. Database Monitoring**
```yaml
# tasks/setup-db-monitoring.yml
---
- name: Setup Database Monitoring
  block:
    - name: Install PostgreSQL Exporter
      get_url:
        url: "https://github.com/prometheus-community/postgres_exporter/releases/download/v0.13.2/postgres_exporter-0.13.2.linux-amd64.tar.gz"
        dest: /tmp/postgres_exporter.tar.gz
      when: database_type == "postgresql"

    - name: Extract PostgreSQL Exporter
      unarchive:
        src: /tmp/postgres_exporter.tar.gz
        dest: /opt/
        remote_src: yes
      when: database_type == "postgresql"

    - name: Configure PostgreSQL Exporter
      template:
        src: postgres_exporter.service.j2
        dest: /etc/systemd/system/postgres_exporter.service
      when: database_type == "postgresql"

    - name: Create database monitoring queries
      copy:
        content: |
          pg_replication:
            query: "SELECT CASE WHEN NOT pg_is_in_recovery() THEN 0 ELSE GREATEST (0, EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))) END AS lag"
            metrics:
              - lag:
                  usage: "GAUGE"
                  description: "Replication lag behind master in seconds"

          pg_postmaster:
            query: "SELECT pg_postmaster_start_time as start_time_seconds from pg_postmaster_start_time()"
            metrics:
              - start_time_seconds:
                  usage: "GAUGE"
                  description: "Time at which postmaster started"

          pg_stat_user_tables:
            query: "SELECT current_database() datname, schemaname, tablename, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch, n_tup_ins, n_tup_upd, n_tup_del, n_tup_hot_upd, n_live_tup, n_dead_tup, n_mod_since_analyze, COALESCE(last_vacuum, '1970-01-01Z'), COALESCE(last_autovacuum, '1970-01-01Z'), COALESCE(last_analyze, '1970-01-01Z'), COALESCE(last_autoanalyze, '1970-01-01Z'), vacuum_count, autovacuum_count, analyze_count, autoanalyze_count FROM pg_stat_user_tables"
            metrics:
              - datname:
                  usage: "LABEL"
                  description: "Name of current database"
              - schemaname:
                  usage: "LABEL"
                  description: "Name of the schema that this table is in"
              - tablename:
                  usage: "LABEL"
                  description: "Name of this table"
        dest: /etc/postgres_exporter/queries.yaml
      when: database_type == "postgresql"
```

---

## 🚨 Alerting e Notifiche

### **Alertmanager Configuration**

#### **1. Alertmanager Setup**
```yaml
# playbooks/setup-alertmanager.yml
---
- name: Setup Alertmanager
  hosts: monitoring
  become: yes
  
  tasks:
    - name: Download Alertmanager
      get_url:
        url: "https://github.com/prometheus/alertmanager/releases/download/v0.25.0/alertmanager-0.25.0.linux-amd64.tar.gz"
        dest: /tmp/alertmanager.tar.gz

    - name: Extract Alertmanager
      unarchive:
        src: /tmp/alertmanager.tar.gz
        dest: /opt/
        remote_src: yes

    - name: Create alertmanager user
      user:
        name: alertmanager
        system: yes
        shell: /bin/false

    - name: Create Alertmanager directories
      file:
        path: "{{ item }}"
        state: directory
        owner: alertmanager
        group: alertmanager
      loop:
        - /etc/alertmanager
        - /var/lib/alertmanager

    - name: Configure Alertmanager
      template:
        src: alertmanager.yml.j2
        dest: /etc/alertmanager/alertmanager.yml
        owner: alertmanager
        group: alertmanager
      notify: restart alertmanager

    - name: Create Alertmanager service
      template:
        src: alertmanager.service.j2
        dest: /etc/systemd/system/alertmanager.service
      notify:
        - reload systemd
        - restart alertmanager

  handlers:
    - name: reload systemd
      systemd:
        daemon_reload: yes

    - name: restart alertmanager
      systemd:
        name: alertmanager
        state: restarted
```

#### **2. Alertmanager Configuration**
```yaml
# templates/alertmanager.yml.j2
global:
  smtp_smarthost: '{{ smtp_server }}:{{ smtp_port }}'
  smtp_from: '{{ alert_sender_email }}'
  slack_api_url: '{{ slack_webhook_url }}'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
      group_wait: 5s
    - match:
        severity: warning
      receiver: 'warning-alerts'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://127.0.0.1:5001/'

  - name: 'critical-alerts'
    email_configs:
      - to: '{{ critical_alert_email }}'
        subject: '🚨 CRITICAL: {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Host: {{ .Labels.instance }}
          Severity: {{ .Labels.severity }}
          {{ end }}
    slack_configs:
      - channel: '{{ slack_critical_channel }}'
        title: '🚨 Critical Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
        color: 'danger'

  - name: 'warning-alerts'
    slack_configs:
      - channel: '{{ slack_warning_channel }}'
        title: '⚠️ Warning Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
        color: 'warning'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

#### **3. Custom Notification Scripts**
```bash
#!/bin/bash
# scripts/notification-handler.sh

ALERT_TYPE="$1"
ALERT_MESSAGE="$2"
ALERT_SEVERITY="$3"
ALERT_HOST="$4"

send_teams_notification() {
    local webhook_url="{{ teams_webhook_url }}"
    local color="warning"
    
    case "$ALERT_SEVERITY" in
        "critical") color="attention" ;;
        "warning") color="warning" ;;
        *) color="good" ;;
    esac
    
    curl -H "Content-Type: application/json" -d '{
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": "Infrastructure Alert",
        "themeColor": "'$color'",
        "sections": [{
            "activityTitle": "🚨 Infrastructure Alert",
            "activitySubtitle": "'$ALERT_TYPE'",
            "facts": [{
                "name": "Severity",
                "value": "'$ALERT_SEVERITY'"
            }, {
                "name": "Host",
                "value": "'$ALERT_HOST'"
            }, {
                "name": "Message",
                "value": "'$ALERT_MESSAGE'"
            }]
        }]
    }' "$webhook_url"
}

send_telegram_notification() {
    local bot_token="{{ telegram_bot_token }}"
    local chat_id="{{ telegram_chat_id }}"
    local emoji="⚠️"
    
    case "$ALERT_SEVERITY" in
        "critical") emoji="🚨" ;;
        "warning") emoji="⚠️" ;;
        *) emoji="ℹ️" ;;
    esac
    
    local message="$emoji *$ALERT_TYPE*
    
Severity: $ALERT_SEVERITY
Host: $ALERT_HOST
Message: $ALERT_MESSAGE

Time: $(date)"
    
    curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
        -d chat_id="$chat_id" \
        -d text="$message" \
        -d parse_mode="Markdown"
}

# Send notifications based on configuration
if [[ -n "{{ teams_webhook_url }}" ]]; then
    send_teams_notification
fi

if [[ -n "{{ telegram_bot_token }}" ]] && [[ -n "{{ telegram_chat_id }}" ]]; then
    send_telegram_notification
fi

# Log to file
echo "$(date): $ALERT_SEVERITY - $ALERT_TYPE - $ALERT_HOST - $ALERT_MESSAGE" >> /var/log/ansible/alerts.log
```

---

## 📊 Dashboard e Reporting

### **Grafana Setup**

#### **1. Grafana Installation**
```yaml
# playbooks/setup-grafana.yml
---
- name: Setup Grafana
  hosts: monitoring
  become: yes
  
  tasks:
    - name: Add Grafana repository key
      apt_key:
        url: https://packages.grafana.com/gpg.key
        state: present
      when: ansible_os_family == "Debian"

    - name: Add Grafana repository
      apt_repository:
        repo: "deb https://packages.grafana.com/oss/deb stable main"
        state: present
      when: ansible_os_family == "Debian"

    - name: Install Grafana
      package:
        name: grafana
        state: present

    - name: Configure Grafana
      template:
        src: grafana.ini.j2
        dest: /etc/grafana/grafana.ini
        backup: yes
      notify: restart grafana

    - name: Start Grafana
      systemd:
        name: grafana-server
        state: started
        enabled: yes

    - name: Wait for Grafana to start
      wait_for:
        port: 3000
        delay: 10

    - name: Create Grafana datasources
      uri:
        url: "http://localhost:3000/api/datasources"
        method: POST
        user: admin
        password: "{{ grafana_admin_password }}"
        body_format: json
        body:
          name: "Prometheus"
          type: "prometheus"
          url: "http://localhost:9090"
          access: "proxy"
          isDefault: true

  handlers:
    - name: restart grafana
      systemd:
        name: grafana-server
        state: restarted
```

#### **2. Automated Dashboard Import**
```yaml
# tasks/import-dashboards.yml
---
- name: Import Infrastructure Dashboard
  uri:
    url: "http://localhost:3000/api/dashboards/db"
    method: POST
    user: admin
    password: "{{ grafana_admin_password }}"
    body_format: json
    body:
      dashboard:
        id: null
        title: "Infrastructure Overview"
        uid: "infrastructure"
        panels:
          - title: "CPU Usage"
            type: "graph"
            targets:
              - expr: "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
          - title: "Memory Usage"
            type: "graph"
            targets:
              - expr: "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100"
          - title: "Disk Usage"
            type: "graph"
            targets:
              - expr: "(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100"
      overwrite: true

- name: Import Ansible Dashboard
  uri:
    url: "http://localhost:3000/api/dashboards/db"
    method: POST
    user: admin
    password: "{{ grafana_admin_password }}"
    body_format: json
    body:
      dashboard:
        id: null
        title: "Ansible Operations"
        uid: "ansible-ops"
        panels:
          - title: "Playbook Executions"
            type: "graph"
            targets:
              - expr: "rate(ansible_playbook_runs_total[5m])"
          - title: "Task Success Rate"
            type: "stat"
            targets:
              - expr: "ansible_task_success_rate"
          - title: "Failed Tasks"
            type: "table"
            targets:
              - expr: "ansible_task_failures_total"
      overwrite: true
```

### **Automated Reporting**

#### **1. Daily Report Generator**
```python
#!/usr/bin/env python3
# scripts/generate-daily-report.py

import requests
import json
import datetime
from jinja2 import Template

def get_prometheus_data(query, start_time, end_time):
    """Query Prometheus for metrics data"""
    url = "http://localhost:9090/api/v1/query_range"
    params = {
        'query': query,
        'start': start_time,
        'end': end_time,
        'step': '1h'
    }
    
    response = requests.get(url, params=params)
    return response.json()

def generate_report():
    """Generate daily infrastructure report"""
    end_time = datetime.datetime.now()
    start_time = end_time - datetime.timedelta(days=1)
    
    # Query metrics
    cpu_data = get_prometheus_data(
        '100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)',
        start_time.timestamp(),
        end_time.timestamp()
    )
    
    memory_data = get_prometheus_data(
        '(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100',
        start_time.timestamp(),
        end_time.timestamp()
    )
    
    ansible_runs = get_prometheus_data(
        'ansible_playbook_runs_total',
        start_time.timestamp(),
        end_time.timestamp()
    )
    
    # Generate report
    template = Template("""
    # Daily Infrastructure Report - {{ date }}
    
    ## Summary
    - Report Period: {{ start_time }} to {{ end_time }}
    - Total Ansible Runs: {{ total_ansible_runs }}
    
    ## Infrastructure Metrics
    
    ### CPU Usage
    - Average: {{ avg_cpu }}%
    - Peak: {{ peak_cpu }}%
    
    ### Memory Usage
    - Average: {{ avg_memory }}%
    - Peak: {{ peak_memory }}%
    
    ## Ansible Operations
    - Successful Playbooks: {{ successful_playbooks }}
    - Failed Playbooks: {{ failed_playbooks }}
    - Success Rate: {{ success_rate }}%
    
    ## Alerts
    {{ alerts_summary }}
    
    Generated at: {{ generated_at }}
    """)
    
    report = template.render(
        date=end_time.strftime('%Y-%m-%d'),
        start_time=start_time.strftime('%Y-%m-%d %H:%M'),
        end_time=end_time.strftime('%Y-%m-%d %H:%M'),
        generated_at=datetime.datetime.now().isoformat()
    )
    
    # Save report
    with open(f'/var/log/ansible/daily-report-{end_time.strftime("%Y%m%d")}.md', 'w') as f:
        f.write(report)
    
    return report

if __name__ == "__main__":
    report = generate_report()
    print("Daily report generated successfully")
```

---

## 📋 Log Aggregation

### **ELK Stack Setup**

#### **1. Elasticsearch Installation**
```yaml
# playbooks/setup-elasticsearch.yml
---
- name: Setup Elasticsearch
  hosts: logging
  become: yes
  
  tasks:
    - name: Install Java
      package:
        name: openjdk-11-jdk
        state: present

    - name: Add Elasticsearch repository key
      apt_key:
        url: https://artifacts.elastic.co/GPG-KEY-elasticsearch
        state: present

    - name: Add Elasticsearch repository
      apt_repository:
        repo: "deb https://artifacts.elastic.co/packages/8.x/apt stable main"
        state: present

    - name: Install Elasticsearch
      package:
        name: elasticsearch
        state: present

    - name: Configure Elasticsearch
      template:
        src: elasticsearch.yml.j2
        dest: /etc/elasticsearch/elasticsearch.yml
        backup: yes
      notify: restart elasticsearch

    - name: Start Elasticsearch
      systemd:
        name: elasticsearch
        state: started
        enabled: yes

  handlers:
    - name: restart elasticsearch
      systemd:
        name: elasticsearch
        state: restarted
```

#### **2. Logstash Configuration**
```yaml
# templates/logstash-ansible.conf.j2
input {
  file {
    path => "/var/log/ansible/ansible.log"
    start_position => "beginning"
    type => "ansible"
  }
  
  file {
    path => "/var/log/ansible/detailed.log"
    start_position => "beginning"
    type => "ansible-detailed"
    codec => "json"
  }
}

filter {
  if [type] == "ansible" {
    grok {
      match => { 
        "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" 
      }
    }
    
    date {
      match => [ "timestamp", "ISO8601" ]
    }
  }
  
  if [type] == "ansible-detailed" {
    date {
      match => [ "timestamp", "ISO8601" ]
    }
  }
}

output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "ansible-logs-%{+YYYY.MM.dd}"
  }
  
  stdout {
    codec => rubydebug
  }
}
```

#### **3. Filebeat Configuration**
```yaml
# templates/filebeat.yml.j2
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/ansible/*.log
  fields:
    service: ansible
    environment: "{{ environment }}"
  fields_under_root: true

- type: log
  enabled: true
  paths:
    - "{{ app_root }}/current/logs/*.log"
  fields:
    service: application
    environment: "{{ environment }}"
  fields_under_root: true

processors:
- add_host_metadata:
    when.not.contains.tags: forwarded

output.elasticsearch:
  hosts: ["{{ elasticsearch_host }}:9200"]
  template.settings:
    index.number_of_shards: 1
    index.codec: best_compression

setup.kibana:
  host: "{{ kibana_host }}:5601"

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
```

---

## 🔍 Troubleshooting con i Log

### **Log Analysis Tools**

#### **1. Log Analysis Playbook**
```yaml
# playbooks/analyze-logs.yml
---
- name: Analyze Ansible Logs
  hosts: localhost
  vars:
    log_file: "{{ log_path | default('/var/log/ansible/ansible.log') }}"
    analysis_period: "{{ period | default('1h') }}"
  
  tasks:
    - name: Get recent errors
      shell: |
        grep -i "error\|failed\|fatal" {{ log_file }} | tail -20
      register: recent_errors
      
    - name: Get deployment statistics
      shell: |
        grep "PLAY RECAP" {{ log_file }} | tail -10
      register: deployment_stats
      
    - name: Analyze performance
      shell: |
        grep "elapsed:" {{ log_file }} | awk '{print $NF}' | sort -n | tail -10
      register: performance_data
      
    - name: Generate analysis report
      template:
        src: log-analysis-report.j2
        dest: "/tmp/log-analysis-{{ ansible_date_time.epoch }}.txt"
      vars:
        errors: "{{ recent_errors.stdout_lines }}"
        stats: "{{ deployment_stats.stdout_lines }}"
        performance: "{{ performance_data.stdout_lines }}"
```

#### **2. Automated Log Rotation**
```yaml
# tasks/setup-log-rotation.yml
---
- name: Configure log rotation for Ansible
  copy:
    content: |
      /var/log/ansible/*.log {
          daily
          missingok
          rotate 30
          compress
          delaycompress
          notifempty
          create 644 ansible ansible
          postrotate
              systemctl reload rsyslog > /dev/null 2>&1 || true
          endscript
      }
    dest: /etc/logrotate.d/ansible
    mode: '0644'

- name: Create log analysis cron job
  cron:
    name: "Daily log analysis"
    minute: "0"
    hour: "1"
    job: "/usr/local/bin/analyze-ansible-logs.sh"
    user: root
```

---

## ✅ Checkpoint - Verifica Monitoring

Verifica che tutto funzioni correttamente:

```bash
# Test Prometheus
curl http://localhost:9090/api/v1/query?query=up

# Test Node Exporter
curl http://localhost:9100/metrics

# Test Grafana
curl -u admin:password http://localhost:3000/api/health

# Test Alertmanager
curl http://localhost:9093/api/v1/status

# Verifica log aggregation
tail -f /var/log/ansible/ansible.log
```

> **✅ VERIFICA COMPLETATA**: Il tuo sistema di monitoring e logging è operativo!

---

## 🔗 Prossimo Capitolo

Nel [**Capitolo 9 - Troubleshooting**](09-troubleshooting.md) imparerai come diagnosticare e risolvere i problemi più comuni di Ansible.

---

## 📚 Risorse Aggiuntive

- [Prometheus Monitoring Guide](https://prometheus.io/docs/guides/basic-auth/)
- [Grafana Dashboard Examples](https://grafana.com/grafana/dashboards/)
- [ELK Stack Documentation](https://www.elastic.co/guide/)
- [Ansible Callback Plugins](https://docs.ansible.com/ansible/latest/plugins/callback.html)
