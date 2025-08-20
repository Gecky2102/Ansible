# 🐛 Capitolo 9 - Troubleshooting e Debug

> **Obiettivo**: Imparerai come diagnosticare, debuggare e risolvere i problemi più comuni che possono verificarsi durante l'uso di Ansible, con tecniche avanzate di troubleshooting.

## 📋 Indice del Capitolo

1. [Metodologia di Troubleshooting](#metodologia-di-troubleshooting)
2. [Errori Comuni e Soluzioni](#errori-comuni-e-soluzioni)
3. [Debug Avanzato](#debug-avanzato)
4. [Performance Tuning](#performance-tuning)
5. [Problemi di Connettività](#problemi-di-connettivita)
6. [Debugging Playbook](#debugging-playbook)
7. [Tools e Utility](#tools-e-utility)
8. [Best Practices di Sicurezza](#best-practices-di-sicurezza)

---

## 🔍 Metodologia di Troubleshooting

### **Approccio Sistematico**

#### **1. Framework PEAR (Problem, Evidence, Analysis, Resolution)**

```yaml
# playbooks/troubleshooting-framework.yml
---
- name: Troubleshooting Framework
  hosts: localhost
  vars:
    problem_description: "{{ problem | default('Undefined') }}"
    debug_level: "{{ debug | default(2) }}"
  
  tasks:
    - name: "PROBLEM: Define the issue"
      debug:
        msg: |
          🔍 PROBLEM DEFINITION:
          - Description: {{ problem_description }}
          - Severity: {{ severity | default('medium') }}
          - Impact: {{ impact | default('unknown') }}
          - First Occurrence: {{ first_seen | default('unknown') }}
      tags: [problem]

    - name: "EVIDENCE: Collect system information"
      setup:
      register: system_facts
      tags: [evidence]

    - name: "EVIDENCE: Check Ansible version"
      command: ansible --version
      register: ansible_version
      tags: [evidence]

    - name: "EVIDENCE: Collect recent logs"
      shell: |
        tail -50 /var/log/ansible/ansible.log 2>/dev/null || echo "No log file found"
      register: recent_logs
      tags: [evidence]

    - name: "ANALYSIS: System state analysis"
      debug:
        msg: |
          📊 SYSTEM ANALYSIS:
          - OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
          - Ansible: {{ ansible_version.stdout_lines[0] }}
          - Python: {{ ansible_python_version }}
          - Memory: {{ ansible_memtotal_mb }}MB
          - CPU: {{ ansible_processor_count }} cores
          - Load: {{ ansible_loadavg if ansible_loadavg is defined else 'N/A' }}
      tags: [analysis]

    - name: "RESOLUTION: Suggested actions"
      debug:
        msg: |
          🔧 RESOLUTION STEPS:
          1. Check connectivity to target hosts
          2. Verify credentials and permissions
          3. Validate playbook syntax
          4. Review error messages in detail
          5. Enable verbose mode for more info
      tags: [resolution]
```

#### **2. Checklist di Troubleshooting**

```bash
#!/bin/bash
# scripts/troubleshooting-checklist.sh

echo "🔍 Ansible Troubleshooting Checklist"
echo "=================================="

# Function to check and report status
check_status() {
    local description="$1"
    local command="$2"
    
    printf "%-40s " "$description:"
    
    if eval "$command" >/dev/null 2>&1; then
        echo "✅ OK"
        return 0
    else
        echo "❌ FAIL"
        return 1
    fi
}

# Basic checks
echo ""
echo "📋 Basic System Checks:"
check_status "Ansible installed" "which ansible"
check_status "Python available" "which python3"
check_status "SSH client available" "which ssh"
check_status "Current user has sudo" "sudo -n true"

# Configuration checks
echo ""
echo "⚙️ Configuration Checks:"
check_status "ansible.cfg exists" "test -f ansible.cfg"
check_status "Inventory file exists" "test -f inventory/hosts.yml"
check_status "SSH key exists" "test -f ~/.ssh/id_rsa"

# Connectivity checks
echo ""
echo "🌐 Connectivity Checks:"
if [ -f "inventory/hosts.yml" ]; then
    # Extract hostnames from inventory
    hosts=$(grep -E "^\s*[a-zA-Z0-9].*:" inventory/hosts.yml | cut -d: -f1 | tr -d ' ')
    
    for host in $hosts; do
        if [[ "$host" != *"group"* ]] && [[ "$host" != "all" ]]; then
            check_status "Ping $host" "ping -c 1 -W 1 $host"
            check_status "SSH to $host" "ssh -o ConnectTimeout=5 -o BatchMode=yes $host 'echo test'"
        fi
    done
fi

# Log analysis
echo ""
echo "📝 Log Analysis:"
if [ -f "/var/log/ansible/ansible.log" ]; then
    error_count=$(grep -c -i "error\|failed\|fatal" /var/log/ansible/ansible.log | tail -100)
    echo "Recent errors in log: $error_count"
    
    if [ "$error_count" -gt 0 ]; then
        echo "Latest errors:"
        grep -i "error\|failed\|fatal" /var/log/ansible/ansible.log | tail -5
    fi
else
    echo "No Ansible log file found"
fi

echo ""
echo "🏁 Troubleshooting checklist completed!"
```

---

## ⚠️ Errori Comuni e Soluzioni

### **SSH e Connettività**

#### **1. Errori SSH più Comuni**

```yaml
# troubleshooting/ssh-issues.yml
---
- name: SSH Troubleshooting Guide
  hosts: localhost
  tasks:
    - name: Diagnose SSH connection issues
      debug:
        msg: |
          🔑 SSH CONNECTION ISSUES:
          
          PROBLEM: "Permission denied (publickey)"
          CAUSES:
          - SSH key not added to target host
          - Wrong SSH key permissions
          - SSH agent not running
          
          SOLUTIONS:
          1. ssh-copy-id user@host
          2. chmod 600 ~/.ssh/id_rsa
          3. eval $(ssh-agent) && ssh-add
          
          PROBLEM: "Host key verification failed"
          SOLUTIONS:
          1. ssh-keyscan -H hostname >> ~/.ssh/known_hosts
          2. Set host_key_checking = False in ansible.cfg
          
          PROBLEM: "Connection timeout"
          SOLUTIONS:
          1. Check firewall rules
          2. Verify SSH service is running
          3. Check network connectivity
          
          DEBUG COMMANDS:
          - ssh -vvv user@host
          - ansible all -m ping -vvv
          - ansible-inventory --list

- name: Automated SSH diagnostics
  hosts: all
  gather_facts: no
  ignore_errors: yes
  tasks:
    - name: Test raw connection
      raw: echo "Connection successful"
      register: raw_test
      
    - name: Test Python availability
      raw: python3 --version || python --version
      register: python_test
      
    - name: Report connection status
      debug:
        msg: |
          Host: {{ inventory_hostname }}
          Raw connection: {{ 'OK' if raw_test is succeeded else 'FAILED' }}
          Python available: {{ 'OK' if python_test is succeeded else 'FAILED' }}
      delegate_to: localhost
```

#### **2. Script di Fix Automatico SSH**

```bash
#!/bin/bash
# scripts/fix-ssh-issues.sh

HOST="$1"
USER="$2"

if [ -z "$HOST" ] || [ -z "$USER" ]; then
    echo "Usage: $0 <hostname> <username>"
    exit 1
fi

echo "🔧 Fixing SSH issues for $USER@$HOST"

# Generate SSH key if not exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
fi

# Fix SSH key permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Start SSH agent
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa

# Copy key to remote host
echo "Copying SSH key to remote host..."
ssh-copy-id -i ~/.ssh/id_rsa.pub "$USER@$HOST"

# Add to known hosts
ssh-keyscan -H "$HOST" >> ~/.ssh/known_hosts

# Test connection
echo "Testing connection..."
if ssh -o ConnectTimeout=5 "$USER@$HOST" 'echo "SSH connection successful"'; then
    echo "✅ SSH connection fixed successfully!"
else
    echo "❌ SSH connection still failing"
    echo "Manual debugging required:"
    echo "ssh -vvv $USER@$HOST"
fi
```

### **WinRM e Windows**

#### **1. Problemi WinRM Comuni**

```yaml
# troubleshooting/winrm-issues.yml
---
- name: WinRM Troubleshooting
  hosts: localhost
  tasks:
    - name: WinRM diagnostic guide
      debug:
        msg: |
          🖥️ WINRM CONNECTION ISSUES:
          
          PROBLEM: "WinRM/HTTP connection error"
          SOLUTIONS:
          1. Enable WinRM on target Windows host:
             winrm quickconfig -y
             winrm set winrm/config/service/auth @{Basic="true"}
          
          2. Configure firewall:
             netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow
          
          3. Check Ansible WinRM setup:
             pip install pywinrm[credssp]
          
          PROBLEM: "Authentication failed"
          SOLUTIONS:
          1. Verify credentials in inventory
          2. Use domain authentication:
             ansible_user: DOMAIN\\username
          3. Enable basic auth if needed
          
          PROBLEM: "Connection timeout"
          SOLUTIONS:
          1. Check Windows firewall
          2. Verify WinRM service status
          3. Test with: winrs -r:hostname -u:user cmd

- name: Windows connectivity test
  hosts: windows
  gather_facts: no
  tasks:
    - name: Test WinRM connection
      win_ping:
      register: winrm_test
      ignore_errors: yes
      
    - name: Test PowerShell execution
      win_shell: Get-ComputerInfo | Select-Object WindowsProductName, TotalPhysicalMemory
      register: ps_test
      ignore_errors: yes
      
    - name: Report Windows status
      debug:
        msg: |
          Host: {{ inventory_hostname }}
          WinRM ping: {{ 'OK' if winrm_test is succeeded else 'FAILED' }}
          PowerShell: {{ 'OK' if ps_test is succeeded else 'FAILED' }}
      delegate_to: localhost
```

#### **2. Windows Setup Automation**

```powershell
# scripts/setup-winrm.ps1
# Script da eseguire sui server Windows per configurare WinRM

param(
    [string]$Username = "ansible",
    [string]$Password = ""
)

Write-Host "🔧 Setting up WinRM for Ansible..." -ForegroundColor Green

try {
    # Enable WinRM
    Write-Host "Enabling WinRM service..."
    winrm quickconfig -y -force
    
    # Configure WinRM settings
    Write-Host "Configuring WinRM settings..."
    winrm set winrm/config/service/auth '@{Basic="true"}'
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}'
    winrm set winrm/config '@{MaxTimeoutms="1800000"}'
    
    # Configure firewall
    Write-Host "Configuring firewall..."
    netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow
    netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow
    
    # Create local user if specified
    if ($Username -and $Password) {
        Write-Host "Creating Ansible user..."
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        New-LocalUser -Name $Username -Password $SecurePassword -Description "Ansible automation user"
        Add-LocalGroupMember -Group "Administrators" -Member $Username
    }
    
    # Test WinRM
    Write-Host "Testing WinRM configuration..."
    $result = winrm enumerate winrm/config/listener
    Write-Host $result
    
    Write-Host "✅ WinRM setup completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error setting up WinRM: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

### **Problemi di Sintassi YAML**

#### **1. Validator YAML Automatico**

```python
#!/usr/bin/env python3
# scripts/yaml-validator.py

import yaml
import sys
import os
from pathlib import Path

def validate_yaml_file(file_path):
    """Validate a single YAML file"""
    try:
        with open(file_path, 'r') as file:
            yaml.safe_load(file)
        return True, None
    except yaml.YAMLError as e:
        return False, str(e)
    except Exception as e:
        return False, f"File error: {str(e)}"

def find_yaml_files(directory):
    """Find all YAML files in directory"""
    yaml_files = []
    for ext in ['*.yml', '*.yaml']:
        yaml_files.extend(Path(directory).rglob(ext))
    return yaml_files

def main():
    if len(sys.argv) < 2:
        directory = "."
    else:
        directory = sys.argv[1]
    
    print(f"🔍 Validating YAML files in: {directory}")
    print("=" * 50)
    
    yaml_files = find_yaml_files(directory)
    total_files = len(yaml_files)
    valid_files = 0
    
    for file_path in yaml_files:
        is_valid, error = validate_yaml_file(file_path)
        
        if is_valid:
            print(f"✅ {file_path}")
            valid_files += 1
        else:
            print(f"❌ {file_path}")
            print(f"   Error: {error}")
            print()
    
    print("=" * 50)
    print(f"📊 Summary: {valid_files}/{total_files} files valid")
    
    if valid_files == total_files:
        print("🎉 All YAML files are valid!")
        sys.exit(0)
    else:
        print("💥 Some YAML files have errors!")
        sys.exit(1)

if __name__ == "__main__":
    main()
```

#### **2. Lint Ansible Playbooks**

```yaml
# .ansible-lint.yml
---
# Ansible Lint configuration

exclude_paths:
  - .cache/
  - .github/
  - test/fixtures/

use_default_rules: true

# Custom rules
rules:
  # Line length
  line-too-long:
    max: 120
  
  # Avoid bare variables in loops
  no-jinja-when: enable
  
  # Use shell only when necessary
  command-instead-of-shell: enable
  
  # Use specific modules instead of command
  command-instead-of-module: enable

# Skip specific rules for specific files
skip_list:
  - yaml[line-too-long]  # Allow long lines in some cases
  - name[template]       # Allow templated names
```

```bash
#!/bin/bash
# scripts/lint-playbooks.sh

echo "🔍 Linting Ansible playbooks..."

# Install ansible-lint if not available
if ! command -v ansible-lint &> /dev/null; then
    echo "Installing ansible-lint..."
    pip3 install ansible-lint
fi

# Lint all playbooks
echo "Checking playbook syntax..."
for playbook in playbooks/*.yml; do
    if [ -f "$playbook" ]; then
        echo "Checking: $playbook"
        ansible-playbook --syntax-check "$playbook"
        
        if [ $? -eq 0 ]; then
            echo "✅ Syntax OK: $playbook"
        else
            echo "❌ Syntax Error: $playbook"
        fi
    fi
done

# Run ansible-lint
echo ""
echo "Running ansible-lint..."
ansible-lint playbooks/ || echo "⚠️  Lint warnings found"

echo ""
echo "🏁 Playbook linting completed!"
```

---

## 🔧 Debug Avanzato

### **Verbose Modes e Debug Output**

#### **1. Configurazione Debug Avanzato**

```yaml
# playbooks/debug-advanced.yml
---
- name: Advanced Debugging Techniques
  hosts: all
  vars:
    debug_mode: "{{ debug | default(false) }}"
    verbose_level: "{{ verbosity | default(1) }}"
  
  tasks:
    - name: Debug environment variables
      debug:
        msg: |
          🔍 ENVIRONMENT DEBUG:
          - Ansible version: {{ ansible_version.full }}
          - Python version: {{ ansible_python_version }}
          - Current user: {{ ansible_user_id }}
          - Home directory: {{ ansible_user_dir }}
          - Temporary directory: {{ ansible_user_temp }}
      when: debug_mode | bool
      
    - name: Debug host facts
      debug:
        var: ansible_facts
      when: 
        - debug_mode | bool
        - verbose_level | int >= 2
        
    - name: Debug inventory variables
      debug:
        msg: |
          📊 INVENTORY VARIABLES:
          - Group: {{ group_names }}
          - Host variables: {{ hostvars[inventory_hostname] }}
      when: 
        - debug_mode | bool
        - verbose_level | int >= 3
        
    - name: Custom debug with conditional
      debug:
        msg: "Task executed on {{ ansible_date_time.date }} at {{ ansible_date_time.time }}"
      when: debug_mode | bool

    - name: Debug failed condition
      debug:
        msg: "This will show why a condition failed"
      failed_when: false  # Never actually fail
      when: 
        - debug_mode | bool
        - some_condition is defined
        - some_condition | bool
```

#### **2. Custom Debug Module**

```python
#!/usr/bin/env python3
# library/custom_debug.py

DOCUMENTATION = '''
---
module: custom_debug
short_description: Enhanced debug module with structured output
description:
    - Provides enhanced debugging capabilities
    - Structured output for better readability
    - Conditional debugging levels
version_added: "1.0"
options:
    msg:
        description: Debug message to display
        required: false
        type: str
    var:
        description: Variable to debug
        required: false
        type: str
    level:
        description: Debug level (1-5)
        required: false
        default: 1
        type: int
'''

from ansible.module_utils.basic import AnsibleModule
import json
import datetime

def main():
    module = AnsibleModule(
        argument_spec=dict(
            msg=dict(type='str', required=False),
            var=dict(type='str', required=False),
            level=dict(type='int', default=1)
        )
    )
    
    msg = module.params['msg']
    var = module.params['var']
    level = module.params['level']
    
    # Create structured debug output
    debug_info = {
        'timestamp': datetime.datetime.now().isoformat(),
        'level': level,
        'host': module.params.get('ansible_hostname', 'unknown'),
        'message': msg,
        'variable': var
    }
    
    result = {
        'changed': False,
        'debug_info': debug_info,
        'msg': f"[DEBUG-L{level}] {msg}" if msg else f"[DEBUG-L{level}] Variable: {var}"
    }
    
    module.exit_json(**result)

if __name__ == '__main__':
    main()
```

### **Step-by-Step Debugging**

#### **1. Interactive Debugging Playbook**

```yaml
# playbooks/interactive-debug.yml
---
- name: Interactive Debugging Session
  hosts: "{{ target_host | default('localhost') }}"
  vars:
    step_mode: "{{ step | default(false) }}"
    
  tasks:
    - name: Step 1 - Gather system information
      setup:
      register: system_info
      
    - name: Debug - Show system info
      debug:
        msg: |
          💻 SYSTEM INFO:
          - OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
          - Kernel: {{ ansible_kernel }}
          - Architecture: {{ ansible_architecture }}
          - CPU: {{ ansible_processor_count }} cores
          - Memory: {{ ansible_memtotal_mb }}MB
      when: step_mode | bool
      
    - name: Step 2 - Check disk space
      shell: df -h
      register: disk_info
      
    - name: Debug - Show disk space
      debug:
        var: disk_info.stdout_lines
      when: step_mode | bool
      
    - name: Interactive pause
      pause:
        prompt: "Press Enter to continue to next step..."
      when: step_mode | bool
      
    - name: Step 3 - Check running processes
      shell: ps aux --sort=-%cpu | head -10
      register: top_processes
      
    - name: Debug - Show top processes
      debug:
        var: top_processes.stdout_lines
      when: step_mode | bool
      
    - name: Final summary
      debug:
        msg: |
          📋 DEBUG SESSION SUMMARY:
          - Host: {{ inventory_hostname }}
          - OS: {{ ansible_distribution }}
          - Memory: {{ ansible_memtotal_mb }}MB
          - Debug completed at: {{ ansible_date_time.iso8601 }}
```

#### **2. Conditional Debug Strategy**

```yaml
# tasks/conditional-debug.yml
---
- name: Set debug flags based on environment
  set_fact:
    debug_enabled: "{{ 
      ansible_hostname in debug_hosts | default([]) or
      environment_name in ['development', 'testing'] or
      force_debug | default(false) | bool
    }}"
    
- name: Debug only in development
  debug:
    msg: "Development environment debugging enabled"
  when: 
    - debug_enabled | bool
    - environment_name == 'development'
    
- name: Debug with variable inspection
  debug:
    msg: |
      🔍 VARIABLE INSPECTION:
      {% for key, value in vars.items() %}
      {% if not key.startswith('ansible_') %}
      - {{ key }}: {{ value }}
      {% endif %}
      {% endfor %}
  when: 
    - debug_enabled | bool
    - inspect_vars | default(false) | bool
    
- name: Conditional fact debugging
  debug:
    msg: |
      📊 FACTS DEBUG:
      - Hostname: {{ ansible_hostname }}
      - FQDN: {{ ansible_fqdn }}
      - Domain: {{ ansible_domain }}
      - IP: {{ ansible_default_ipv4.address }}
  when: 
    - debug_enabled | bool
    - debug_facts | default(false) | bool
```

---

## ⚡ Performance Tuning

### **Ottimizzazione Performance**

#### **1. ansible.cfg Ottimizzato per Performance**

```ini
# ansible.cfg - Performance Optimized
[defaults]
# Connessioni parallele
forks = 50

# Cache facts per velocizzare esecuzioni successive
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_fact_cache
fact_caching_timeout = 86400

# SSH ottimizzazioni
ssh_args = -o ControlMaster=auto -o ControlPersist=3600s -o ControlPath=/tmp/ansible-ssh-%h-%p-%r
pipelining = True
host_key_checking = False

# Callback plugins per monitoring performance
callback_whitelist = timer, profile_tasks, profile_roles

# Timeout ottimizzati
timeout = 30
gather_timeout = 30

# Riduci verbosity di default
display_skipped_hosts = False
display_ok_hosts = False

# Usa SSH multiplexing
[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=3600s
control_path_dir = /tmp/.ansible-cp
control_path = %(directory)s/%%C
pipelining = True
retries = 3
```

#### **2. Performance Monitoring Playbook**

```yaml
# playbooks/performance-monitor.yml
---
- name: Performance Monitoring and Optimization
  hosts: all
  vars:
    performance_test: true
    
  tasks:
    - name: Record start time
      set_fact:
        start_time: "{{ ansible_date_time.epoch }}"
        
    - name: Test task performance - Simple command
      command: echo "Performance test"
      register: simple_task
      
    - name: Test task performance - File operations
      copy:
        content: "Performance test content"
        dest: /tmp/perf_test.txt
      register: file_task
      
    - name: Test task performance - Package query
      package_facts:
      register: package_task
      
    - name: Calculate execution times
      set_fact:
        end_time: "{{ ansible_date_time.epoch }}"
        total_time: "{{ ansible_date_time.epoch | int - start_time | int }}"
        
    - name: Performance report
      debug:
        msg: |
          ⚡ PERFORMANCE REPORT:
          - Host: {{ inventory_hostname }}
          - Total execution time: {{ total_time }}s
          - Simple command: {{ simple_task.delta if simple_task.delta is defined else 'N/A' }}
          - File operations: {{ file_task.delta if file_task.delta is defined else 'N/A' }}
          - Package facts: {{ package_task.delta if package_task.delta is defined else 'N/A' }}
          
    - name: Cleanup test files
      file:
        path: /tmp/perf_test.txt
        state: absent
```

#### **3. Parallel Execution Optimization**

```yaml
# playbooks/parallel-optimization.yml
---
- name: Parallel Execution Strategies
  hosts: all
  strategy: "{{ execution_strategy | default('linear') }}"
  serial: "{{ batch_size | default('100%') }}"
  
  vars:
    parallel_tasks: true
    
  tasks:
    - name: Parallel fact gathering
      setup:
      async: 300
      poll: 0
      register: fact_gathering
      when: parallel_tasks | bool
      
    - name: Wait for fact gathering completion
      async_status:
        jid: "{{ fact_gathering.ansible_job_id }}"
      register: fact_result
      until: fact_result.finished
      retries: 30
      delay: 10
      when: 
        - parallel_tasks | bool
        - fact_gathering is defined
        
    - name: Batch process with dynamic groups
      include_tasks: tasks/batch-process.yml
      vars:
        batch_hosts: "{{ groups['all'][item*batch_size:(item+1)*batch_size] }}"
      loop: "{{ range(0, (groups['all']|length / batch_size)|round|int + 1) | list }}"
      when: 
        - batch_hosts | length > 0
        - batch_processing | default(false) | bool
```

### **Caching e Ottimizzazioni**

#### **1. Facts Caching Setup**

```yaml
# tasks/setup-facts-caching.yml
---
- name: Setup facts caching
  block:
    - name: Create fact cache directory
      file:
        path: "{{ fact_cache_dir | default('/tmp/ansible_fact_cache') }}"
        state: directory
        mode: '0755'
      delegate_to: localhost
      run_once: true
      
    - name: Configure Redis fact caching (alternative)
      pip:
        name: redis
      when: fact_cache_backend == 'redis'
      delegate_to: localhost
      run_once: true
      
    - name: Test fact caching
      setup:
        filter: "ansible_distribution*"
      register: cached_facts
      
    - name: Verify fact cache
      stat:
        path: "{{ fact_cache_dir }}/{{ inventory_hostname }}"
      register: cache_file
      delegate_to: localhost
      
    - name: Report caching status
      debug:
        msg: |
          💾 FACTS CACHING STATUS:
          - Cache directory: {{ fact_cache_dir }}
          - Cache file exists: {{ cache_file.stat.exists }}
          - Cache backend: {{ fact_cache_backend | default('jsonfile') }}
          - Facts cached: {{ cached_facts.ansible_facts.keys() | length }}
```

#### **2. Inventory Caching**

```python
#!/usr/bin/env python3
# scripts/inventory-cache.py

import json
import time
import hashlib
import os
from pathlib import Path

class InventoryCache:
    def __init__(self, cache_dir="/tmp/ansible_inventory_cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)
        self.cache_ttl = 3600  # 1 hour
    
    def get_cache_file(self, inventory_source):
        """Generate cache filename based on inventory source"""
        source_hash = hashlib.md5(inventory_source.encode()).hexdigest()
        return self.cache_dir / f"inventory_{source_hash}.json"
    
    def is_cache_valid(self, cache_file):
        """Check if cache file is still valid"""
        if not cache_file.exists():
            return False
        
        cache_age = time.time() - cache_file.stat().st_mtime
        return cache_age < self.cache_ttl
    
    def get_cached_inventory(self, inventory_source):
        """Get inventory from cache if valid"""
        cache_file = self.get_cache_file(inventory_source)
        
        if self.is_cache_valid(cache_file):
            with open(cache_file, 'r') as f:
                return json.load(f)
        
        return None
    
    def cache_inventory(self, inventory_source, inventory_data):
        """Cache inventory data"""
        cache_file = self.get_cache_file(inventory_source)
        
        with open(cache_file, 'w') as f:
            json.dump(inventory_data, f, indent=2)
    
    def clear_cache(self):
        """Clear all cached inventory files"""
        for cache_file in self.cache_dir.glob("inventory_*.json"):
            cache_file.unlink()

if __name__ == "__main__":
    cache = InventoryCache()
    print("Inventory cache system initialized")
    print(f"Cache directory: {cache.cache_dir}")
    print(f"Cache TTL: {cache.cache_ttl} seconds")
```

---

## 🌐 Problemi di Connettività

### **Network Diagnostics**

#### **1. Comprehensive Network Testing**

```yaml
# playbooks/network-diagnostics.yml
---
- name: Network Connectivity Diagnostics
  hosts: all
  gather_facts: yes
  vars:
    test_ports: [22, 80, 443, 3389, 5985, 5986]
    test_hosts: 
      - google.com
      - github.com
      - "{{ ansible_default_ipv4.gateway }}"
    
  tasks:
    - name: Test basic connectivity
      wait_for:
        host: "{{ item }}"
        port: 443
        timeout: 5
      loop: "{{ test_hosts }}"
      register: connectivity_test
      ignore_errors: yes
      
    - name: Test port connectivity
      wait_for:
        host: "{{ inventory_hostname }}"
        port: "{{ item }}"
        timeout: 5
      loop: "{{ test_ports }}"
      register: port_test
      ignore_errors: yes
      delegate_to: localhost
      
    - name: DNS resolution test
      shell: nslookup {{ item }} || dig {{ item }}
      loop: "{{ test_hosts }}"
      register: dns_test
      ignore_errors: yes
      
    - name: Network interface information
      setup:
        filter: "ansible_*"
      register: network_facts
      
    - name: Generate network report
      debug:
        msg: |
          🌐 NETWORK DIAGNOSTICS REPORT:
          Host: {{ inventory_hostname }}
          IP Address: {{ ansible_default_ipv4.address }}
          Gateway: {{ ansible_default_ipv4.gateway }}
          DNS: {{ ansible_dns.nameservers | join(', ') }}
          
          Connectivity Tests:
          {% for result in connectivity_test.results %}
          - {{ test_hosts[loop.index0] }}: {{ 'OK' if result is succeeded else 'FAILED' }}
          {% endfor %}
          
          Port Tests:
          {% for result in port_test.results %}
          - Port {{ test_ports[loop.index0] }}: {{ 'OPEN' if result is succeeded else 'CLOSED' }}
          {% endfor %}
```

#### **2. Firewall Diagnostics**

```bash
#!/bin/bash
# scripts/firewall-diagnostics.sh

echo "🔥 Firewall Diagnostics"
echo "====================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This script should be run as root for complete diagnostics"
fi

# Function to check firewall status
check_firewall() {
    local fw_type="$1"
    
    case "$fw_type" in
        "iptables")
            if command -v iptables >/dev/null; then
                echo "📋 IPTables Rules:"
                iptables -L -n -v 2>/dev/null || echo "Cannot read iptables rules"
            fi
            ;;
        "ufw")
            if command -v ufw >/dev/null; then
                echo "📋 UFW Status:"
                ufw status verbose 2>/dev/null || echo "UFW not configured"
            fi
            ;;
        "firewalld")
            if command -v firewall-cmd >/dev/null; then
                echo "📋 FirewallD Status:"
                firewall-cmd --state 2>/dev/null || echo "FirewallD not running"
                firewall-cmd --list-all 2>/dev/null || echo "Cannot list firewall rules"
            fi
            ;;
        "windows")
            if command -v netsh >/dev/null; then
                echo "📋 Windows Firewall:"
                netsh advfirewall show allprofiles state 2>/dev/null || echo "Cannot check Windows firewall"
            fi
            ;;
    esac
}

# Detect and check firewall
echo "🔍 Detecting firewall type..."

if [ -f /etc/debian_version ]; then
    check_firewall "ufw"
    check_firewall "iptables"
elif [ -f /etc/redhat-release ]; then
    check_firewall "firewalld"
    check_firewall "iptables"
elif [ "$OS" = "Windows_NT" ]; then
    check_firewall "windows"
else
    check_firewall "iptables"
fi

# Check common ports
echo ""
echo "🔌 Common Port Status:"
common_ports=(22 80 443 3389 5985 5986)

for port in "${common_ports[@]}"; do
    if command -v netstat >/dev/null; then
        if netstat -an | grep ":$port " >/dev/null; then
            echo "Port $port: LISTENING"
        else
            echo "Port $port: NOT LISTENING"
        fi
    elif command -v ss >/dev/null; then
        if ss -an | grep ":$port " >/dev/null; then
            echo "Port $port: LISTENING"
        else
            echo "Port $port: NOT LISTENING"
        fi
    fi
done

echo ""
echo "🏁 Firewall diagnostics completed!"
```

---

## 📝 Debugging Playbook

### **Advanced Debugging Techniques**

#### **1. Debug Tags and Conditions**

```yaml
# playbooks/debug-tags.yml
---
- name: Advanced Debugging with Tags
  hosts: all
  vars:
    debug_level: "{{ debug | default(0) }}"
    
  tasks:
    - name: Debug level 1 - Basic info
      debug:
        msg: |
          🔍 BASIC DEBUG INFO:
          - Host: {{ inventory_hostname }}
          - User: {{ ansible_user }}
          - Time: {{ ansible_date_time.iso8601 }}
      tags: [debug, debug-1, always]
      when: debug_level | int >= 1
      
    - name: Debug level 2 - System info
      debug:
        msg: |
          💻 SYSTEM DEBUG INFO:
          - OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
          - Kernel: {{ ansible_kernel }}
          - Python: {{ ansible_python_version }}
          - Memory: {{ ansible_memtotal_mb }}MB
      tags: [debug, debug-2]
      when: debug_level | int >= 2
      
    - name: Debug level 3 - Network info
      debug:
        msg: |
          🌐 NETWORK DEBUG INFO:
          - IP: {{ ansible_default_ipv4.address }}
          - Gateway: {{ ansible_default_ipv4.gateway }}
          - DNS: {{ ansible_dns.nameservers }}
          - Interfaces: {{ ansible_interfaces }}
      tags: [debug, debug-3]
      when: debug_level | int >= 3
      
    - name: Debug level 4 - All variables
      debug:
        var: hostvars[inventory_hostname]
      tags: [debug, debug-4, debug-vars]
      when: debug_level | int >= 4
      
    - name: Debug specific variable
      debug:
        var: "{{ debug_var }}"
      tags: [debug, debug-specific]
      when: 
        - debug_var is defined
        - debug_level | int >= 1
```

#### **2. Error Handling e Recovery**

```yaml
# playbooks/error-handling.yml
---
- name: Advanced Error Handling and Recovery
  hosts: all
  vars:
    max_retries: 3
    retry_delay: 5
    
  tasks:
    - name: Task with retry logic
      block:
        - name: Attempt risky operation
          shell: |
            # Simulate operation that might fail
            if [ $((RANDOM % 3)) -eq 0 ]; then
              echo "Operation successful"
            else
              echo "Operation failed" >&2
              exit 1
            fi
          register: risky_operation
          retries: "{{ max_retries }}"
          delay: "{{ retry_delay }}"
          until: risky_operation.rc == 0
          
      rescue:
        - name: Log failure details
          debug:
            msg: |
              ❌ OPERATION FAILED:
              - Host: {{ inventory_hostname }}
              - Task: Risky operation
              - Attempts: {{ max_retries + 1 }}
              - Error: {{ risky_operation.stderr | default('Unknown error') }}
              
        - name: Attempt recovery
          shell: echo "Executing recovery procedure"
          register: recovery_attempt
          
        - name: Recovery success
          debug:
            msg: "✅ Recovery completed successfully"
          when: recovery_attempt.rc == 0
          
        - name: Recovery failure
          fail:
            msg: "💥 Recovery failed, manual intervention required"
          when: recovery_attempt.rc != 0
          
      always:
        - name: Cleanup operations
          debug:
            msg: "🧹 Performing cleanup operations"
            
        - name: Log completion
          lineinfile:
            path: /tmp/ansible-operations.log
            line: "{{ ansible_date_time.iso8601 }} - {{ inventory_hostname }} - Operation completed"
            create: yes
          ignore_errors: yes
```

---

## 🛠️ Tools e Utility

### **Utility Scripts**

#### **1. Ansible Health Check Script**

```bash
#!/bin/bash
# scripts/ansible-health-check.sh

HEALTH_REPORT="/tmp/ansible-health-$(date +%Y%m%d-%H%M%S).txt"

exec > >(tee -a "$HEALTH_REPORT")
exec 2>&1

echo "🏥 Ansible Health Check Report"
echo "=============================="
echo "Timestamp: $(date)"
echo "User: $(whoami)"
echo "Hostname: $(hostname)"
echo ""

# Check Ansible installation
echo "📦 Ansible Installation:"
echo "-----------------------"
if command -v ansible >/dev/null; then
    ansible --version
    echo "✅ Ansible is installed"
else
    echo "❌ Ansible is not installed"
fi
echo ""

# Check Python dependencies
echo "🐍 Python Dependencies:"
echo "----------------------"
python3 -c "
import sys
packages = ['yaml', 'jinja2', 'cryptography', 'requests']
for pkg in packages:
    try:
        __import__(pkg)
        print(f'✅ {pkg}')
    except ImportError:
        print(f'❌ {pkg} - not installed')
"
echo ""

# Check configuration files
echo "⚙️ Configuration Files:"
echo "----------------------"
files=("ansible.cfg" "inventory/hosts.yml" "inventory/group_vars/all.yml")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - not found"
    fi
done
echo ""

# Check SSH configuration
echo "🔑 SSH Configuration:"
echo "--------------------"
if [ -f ~/.ssh/id_rsa ]; then
    echo "✅ SSH private key exists"
    ssh-keygen -l -f ~/.ssh/id_rsa 2>/dev/null && echo "✅ SSH key is valid"
else
    echo "❌ SSH private key not found"
fi

if [ -f ~/.ssh/known_hosts ]; then
    echo "✅ known_hosts file exists ($(wc -l < ~/.ssh/known_hosts) entries)"
else
    echo "⚠️  known_hosts file not found"
fi
echo ""

# Test inventory connectivity
echo "🌐 Inventory Connectivity:"
echo "-------------------------"
if [ -f "inventory/hosts.yml" ]; then
    echo "Testing connectivity to inventory hosts..."
    ansible all -m ping --one-line 2>/dev/null | head -10
else
    echo "⚠️  Cannot test - inventory file not found"
fi
echo ""

# Check log files
echo "📝 Log Files:"
echo "------------"
log_files=("/var/log/ansible/ansible.log" "./ansible.log")
for log_file in "${log_files[@]}"; do
    if [ -f "$log_file" ]; then
        echo "✅ $log_file ($(wc -l < "$log_file") lines)"
        echo "   Latest entry: $(tail -1 "$log_file" 2>/dev/null)"
    else
        echo "❌ $log_file - not found"
    fi
done
echo ""

# Disk space check
echo "💾 Disk Space:"
echo "-------------"
df -h . | tail -1 | awk '{print "Available space: " $4 " (" $5 " used)"}'
echo ""

# Memory usage
echo "🧠 Memory Usage:"
echo "---------------"
free -h | grep "Mem:" | awk '{print "Memory: " $3 "/" $2 " (" $3/$2*100 "% used)"}'
echo ""

echo "🏁 Health check completed!"
echo "Report saved to: $HEALTH_REPORT"
```

#### **2. Performance Profiler**

```python
#!/usr/bin/env python3
# scripts/ansible-profiler.py

import time
import psutil
import json
import sys
from datetime import datetime
from pathlib import Path

class AnsibleProfiler:
    def __init__(self):
        self.start_time = time.time()
        self.process = psutil.Process()
        self.measurements = []
        
    def measure(self, phase_name):
        """Record performance measurement"""
        current_time = time.time()
        cpu_percent = self.process.cpu_percent()
        memory_info = self.process.memory_info()
        
        measurement = {
            'timestamp': datetime.now().isoformat(),
            'phase': phase_name,
            'elapsed_time': current_time - self.start_time,
            'cpu_percent': cpu_percent,
            'memory_rss': memory_info.rss,
            'memory_vms': memory_info.vms
        }
        
        self.measurements.append(measurement)
        print(f"📊 {phase_name}: {measurement['elapsed_time']:.2f}s, "
              f"CPU: {cpu_percent:.1f}%, "
              f"Memory: {memory_info.rss / 1024 / 1024:.1f}MB")
        
    def generate_report(self, output_file=None):
        """Generate performance report"""
        if not output_file:
            output_file = f"ansible-profile-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
            
        total_time = time.time() - self.start_time
        
        report = {
            'summary': {
                'total_execution_time': total_time,
                'total_phases': len(self.measurements),
                'average_cpu': sum(m['cpu_percent'] for m in self.measurements) / len(self.measurements),
                'peak_memory': max(m['memory_rss'] for m in self.measurements)
            },
            'measurements': self.measurements
        }
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
            
        print(f"\n📈 Performance report saved to: {output_file}")
        return report

# Usage example
if __name__ == "__main__":
    profiler = AnsibleProfiler()
    
    # Simulate Ansible phases
    profiler.measure("Initialization")
    time.sleep(0.5)
    
    profiler.measure("Inventory Loading")
    time.sleep(0.3)
    
    profiler.measure("Fact Gathering")
    time.sleep(1.0)
    
    profiler.measure("Task Execution")
    time.sleep(2.0)
    
    profiler.measure("Cleanup")
    
    report = profiler.generate_report()
```

---

## 🔒 Best Practices di Sicurezza

### **Security Troubleshooting**

#### **1. Security Audit Playbook**

```yaml
# playbooks/security-audit.yml
---
- name: Security Audit and Troubleshooting
  hosts: all
  become: yes
  vars:
    audit_report: "/tmp/security-audit-{{ inventory_hostname }}.json"
    
  tasks:
    - name: Check SSH configuration
      slurp:
        src: /etc/ssh/sshd_config
      register: ssh_config
      
    - name: Analyze SSH security
      set_fact:
        ssh_security_issues: []
        
    - name: Check for root login
      set_fact:
        ssh_security_issues: "{{ ssh_security_issues + ['Root login enabled'] }}"
      when: "'PermitRootLogin yes' in (ssh_config.content | b64decode)"
      
    - name: Check for password authentication
      set_fact:
        ssh_security_issues: "{{ ssh_security_issues + ['Password authentication enabled'] }}"
      when: "'PasswordAuthentication yes' in (ssh_config.content | b64decode)"
      
    - name: Check sudo configuration
      shell: sudo -l -U {{ ansible_user }}
      register: sudo_config
      ignore_errors: yes
      
    - name: Check file permissions
      find:
        paths: ['/etc', '/var/log']
        patterns: ['passwd', 'shadow', 'sudoers']
        recurse: no
      register: sensitive_files
      
    - name: Check for SUID files
      shell: find /usr /bin /sbin -perm -4000 -type f 2>/dev/null
      register: suid_files
      
    - name: Check running services
      service_facts:
      
    - name: Generate security report
      copy:
        content: |
          {
            "timestamp": "{{ ansible_date_time.iso8601 }}",
            "host": "{{ inventory_hostname }}",
            "ssh_security_issues": {{ ssh_security_issues | to_json }},
            "sudo_access": "{{ sudo_config.stdout if sudo_config.rc == 0 else 'Access denied' }}",
            "suid_files_count": {{ suid_files.stdout_lines | length }},
            "running_services": {{ ansible_facts.services.keys() | list | length }},
            "sensitive_files": {{ sensitive_files.files | length }}
          }
        dest: "{{ audit_report }}"
        
    - name: Display security summary
      debug:
        msg: |
          🔒 SECURITY AUDIT SUMMARY:
          - Host: {{ inventory_hostname }}
          - SSH Issues: {{ ssh_security_issues | length }}
          {% for issue in ssh_security_issues %}
          - {{ issue }}
          {% endfor %}
          - SUID Files: {{ suid_files.stdout_lines | length }}
          - Running Services: {{ ansible_facts.services.keys() | list | length }}
          - Report: {{ audit_report }}
```

#### **2. Vault Security Check**

```bash
#!/bin/bash
# scripts/vault-security-check.sh

echo "🔐 Ansible Vault Security Check"
echo "==============================="

# Check for unencrypted sensitive files
echo "🔍 Checking for unencrypted sensitive files..."
find . -name "*.yml" -o -name "*.yaml" | while read -r file; do
    if grep -qi "password\|secret\|key\|token" "$file" && ! grep -q "\$ANSIBLE_VAULT" "$file"; then
        echo "⚠️  Potentially unencrypted sensitive data in: $file"
        grep -n -i "password\|secret\|key\|token" "$file" | head -3
    fi
done

# Check vault file encryption
echo ""
echo "🔒 Checking vault file encryption..."
find . -name "vault.yml" -o -name "*vault*" | while read -r file; do
    if [ -f "$file" ]; then
        if grep -q "\$ANSIBLE_VAULT" "$file"; then
            echo "✅ $file is properly encrypted"
        else
            echo "❌ $file is not encrypted!"
        fi
    fi
done

# Check for weak permissions
echo ""
echo "🔑 Checking file permissions..."
find . -name "*.yml" -o -name "*.yaml" | while read -r file; do
    perms=$(stat -f "%A" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null)
    if [ "$perms" != "600" ] && [ "$perms" != "644" ]; then
        echo "⚠️  Weak permissions on $file: $perms"
    fi
done

# Check SSH key permissions
echo ""
echo "🗝️  Checking SSH key permissions..."
if [ -f ~/.ssh/id_rsa ]; then
    key_perms=$(stat -f "%A" ~/.ssh/id_rsa 2>/dev/null || stat -c "%a" ~/.ssh/id_rsa 2>/dev/null)
    if [ "$key_perms" = "600" ]; then
        echo "✅ SSH private key has correct permissions"
    else
        echo "❌ SSH private key has weak permissions: $key_perms"
    fi
fi

echo ""
echo "🏁 Security check completed!"
```

---

## ✅ Checkpoint - Verifica Troubleshooting

Per verificare che le tue competenze di troubleshooting siano complete:

```bash
# Esegui il framework di troubleshooting
ansible-playbook playbooks/troubleshooting-framework.yml -e "problem='Test issue'"

# Testa la checklist automatica
./scripts/troubleshooting-checklist.sh

# Verifica la configurazione
python3 scripts/yaml-validator.py .

# Esegui il health check
./scripts/ansible-health-check.sh

# Testa le performance
ansible-playbook playbooks/performance-monitor.yml

# Verifica la sicurezza
ansible-playbook playbooks/security-audit.yml
./scripts/vault-security-check.sh
```

> **✅ VERIFICA COMPLETATA**: Ora hai tutti gli strumenti per diagnosticare e risolvere problemi con Ansible!

---

## 🔗 Prossimo Capitolo

Nel [**Capitolo 10 - Scenari Avanzati**](10-scenari-avanzati.md) esploreremo integrazione CI/CD, multi-environment, backup e scaling per scenari enterprise complessi.

---

## 📚 Risorse Aggiuntive

- [Ansible Troubleshooting Guide](https://docs.ansible.com/ansible/latest/user_guide/playbooks_debugger.html)
- [Performance Tuning Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_strategies.html)
- [Security Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html#best-practices-for-security)
