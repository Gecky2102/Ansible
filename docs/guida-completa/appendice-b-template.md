# 📋 Appendice B - Template e Esempi

> **Scopo**: Raccolta di template pronti all'uso, configurazioni avanzate ed esempi pratici per scenari comuni.

## 🌐 Template Configurazione Web Server

### **Nginx Configuration Template**
```nginx
# templates/nginx/site.conf.j2
server {
    listen {{ http_port | default(80) }};
    server_name {{ server_name | default(ansible_fqdn) }};
    
    {% if ssl_enabled | default(false) %}
    # HTTP to HTTPS redirect
    return 301 https://$server_name$request_uri;
}

server {
    listen {{ https_port | default(443) }} ssl http2;
    server_name {{ server_name | default(ansible_fqdn) }};
    
    # SSL Configuration
    ssl_certificate {{ ssl_cert_path }};
    ssl_certificate_key {{ ssl_key_path }};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    {% endif %}
    
    # Document root
    root {{ document_root | default('/var/www/html') }};
    index index.html index.htm index.php;
    
    # Logging
    access_log {{ nginx_log_dir }}/{{ server_name }}_access.log;
    error_log {{ nginx_log_dir }}/{{ server_name }}_error.log;
    
    # Main location
    location / {
        {% if backend_servers is defined %}
        # Proxy to backend
        proxy_pass http://{{ backend_name | default('backend') }};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout {{ proxy_timeout | default(30) }}s;
        proxy_send_timeout {{ proxy_timeout | default(30) }}s;
        proxy_read_timeout {{ proxy_timeout | default(30) }}s;
        {% else %}
        # Static files
        try_files $uri $uri/ =404;
        {% endif %}
    }
    
    # Static assets caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    {% if php_enabled | default(false) %}
    # PHP-FPM configuration
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php{{ php_version }}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    {% endif %}
    
    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
    
    {% if rate_limiting | default(false) %}
    # Rate limiting
    limit_req zone=api burst={{ rate_limit_burst | default(20) }} nodelay;
    limit_req_status 429;
    {% endif %}
}

{% if backend_servers is defined %}
# Backend upstream
upstream {{ backend_name | default('backend') }} {
    {% for server in backend_servers %}
    server {{ server.host }}:{{ server.port | default(8080) }}{% if server.weight is defined %} weight={{ server.weight }}{% endif %}{% if server.backup | default(false) %} backup{% endif %};
    {% endfor %}
    
    # Load balancing method
    {{ load_balance_method | default('least_conn') }};
    
    # Health checks
    keepalive {{ keepalive_connections | default(32) }};
}
{% endif %}

{% if rate_limiting | default(false) %}
# Rate limiting zone
limit_req_zone $binary_remote_addr zone=api:10m rate={{ rate_limit_rpm | default(60) }}r/m;
{% endif %}
```

### **Apache VirtualHost Template**
```apache
# templates/apache/vhost.conf.j2
<VirtualHost *:{{ http_port | default(80) }}>
    ServerName {{ server_name | default(ansible_fqdn) }}
    {% if server_aliases is defined %}
    {% for alias in server_aliases %}
    ServerAlias {{ alias }}
    {% endfor %}
    {% endif %}
    
    DocumentRoot {{ document_root | default('/var/www/html') }}
    
    # Logging
    CustomLog {{ apache_log_dir }}/{{ server_name }}_access.log combined
    ErrorLog {{ apache_log_dir }}/{{ server_name }}_error.log
    LogLevel {{ log_level | default('warn') }}
    
    {% if ssl_enabled | default(false) %}
    # Redirect to HTTPS
    Redirect permanent / https://{{ server_name }}/
</VirtualHost>

<VirtualHost *:{{ https_port | default(443) }}>
    ServerName {{ server_name | default(ansible_fqdn) }}
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile {{ ssl_cert_path }}
    SSLCertificateKeyFile {{ ssl_key_path }}
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305
    SSLHonorCipherOrder off
    SSLSessionTickets off
    
    # Security headers
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    {% endif %}
    
    DocumentRoot {{ document_root | default('/var/www/html') }}
    
    <Directory {{ document_root | default('/var/www/html') }}>
        Options {{ directory_options | default('Indexes FollowSymLinks') }}
        AllowOverride {{ allow_override | default('All') }}
        Require all granted
    </Directory>
    
    {% if backend_servers is defined %}
    # Proxy configuration
    ProxyPreserveHost On
    ProxyRequests Off
    
    {% for backend in backend_servers %}
    ProxyPass /{{ backend.path | default('') }} http://{{ backend.host }}:{{ backend.port }}/
    ProxyPassReverse /{{ backend.path | default('') }} http://{{ backend.host }}:{{ backend.port }}/
    {% endfor %}
    {% endif %}
    
    # Static content caching
    <LocationMatch "\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2)$">
        ExpiresActive On
        ExpiresDefault "access plus 1 year"
        Header append Cache-Control "public"
    </LocationMatch>
    
    {% if php_enabled | default(false) %}
    # PHP configuration
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php{{ php_version }}-fpm.sock|fcgi://localhost"
    </FilesMatch>
    {% endif %}
</VirtualHost>
```

---

## 🗄️ Template Database

### **MySQL Configuration Template**
```ini
# templates/mysql/my.cnf.j2
[mysqld]
# Basic settings
user = mysql
pid-file = /var/run/mysqld/mysqld.pid
socket = /var/run/mysqld/mysqld.sock
port = {{ mysql_port | default(3306) }}
basedir = /usr
datadir = {{ mysql_datadir | default('/var/lib/mysql') }}
tmpdir = /tmp
lc-messages-dir = /usr/share/mysql

# Networking
bind-address = {{ mysql_bind_address | default('127.0.0.1') }}
max_connections = {{ mysql_max_connections | default(151) }}
connect_timeout = {{ mysql_connect_timeout | default(5) }}
wait_timeout = {{ mysql_wait_timeout | default(600) }}
max_allowed_packet = {{ mysql_max_allowed_packet | default('16M') }}
thread_cache_size = {{ mysql_thread_cache_size | default(128) }}
sort_buffer_size = {{ mysql_sort_buffer_size | default('4M') }}
bulk_insert_buffer_size = {{ mysql_bulk_insert_buffer_size | default('16M') }}
tmp_table_size = {{ mysql_tmp_table_size | default('32M') }}
max_heap_table_size = {{ mysql_max_heap_table_size | default('32M') }}

# MyISAM settings
myisam_recover_options = BACKUP
key_buffer_size = {{ mysql_key_buffer_size | default('128M') }}
table_open_cache = {{ mysql_table_open_cache | default(400) }}
myisam_sort_buffer_size = {{ mysql_myisam_sort_buffer_size | default('512M') }}
concurrent_insert = 2
read_buffer_size = {{ mysql_read_buffer_size | default('2M') }}
read_rnd_buffer_size = {{ mysql_read_rnd_buffer_size | default('1M') }}

# InnoDB settings
innodb_buffer_pool_size = {{ mysql_innodb_buffer_pool_size | default('256M') }}
innodb_log_file_size = {{ mysql_innodb_log_file_size | default('64M') }}
innodb_file_per_table = {{ mysql_innodb_file_per_table | default(1) }}
innodb_open_files = {{ mysql_innodb_open_files | default(400) }}
innodb_io_capacity = {{ mysql_innodb_io_capacity | default(400) }}
innodb_flush_method = {{ mysql_innodb_flush_method | default('O_DIRECT') }}
innodb_log_buffer_size = {{ mysql_innodb_log_buffer_size | default('8M') }}

# Logging
{% if mysql_slow_query_log | default(true) %}
slow_query_log = 1
slow_query_log_file = {{ mysql_slow_query_log_file | default('/var/log/mysql/slow.log') }}
long_query_time = {{ mysql_long_query_time | default(2) }}
log_queries_not_using_indexes = {{ mysql_log_queries_not_using_indexes | default(1) }}
{% endif %}

general_log = {{ mysql_general_log | default(0) }}
{% if mysql_general_log | default(false) %}
general_log_file = {{ mysql_general_log_file | default('/var/log/mysql/general.log') }}
{% endif %}

# Binary logging
{% if mysql_binlog_enabled | default(true) %}
server-id = {{ mysql_server_id | default(1) }}
log_bin = {{ mysql_binlog_dir | default('/var/log/mysql') }}/mysql-bin.log
expire_logs_days = {{ mysql_expire_logs_days | default(10) }}
max_binlog_size = {{ mysql_max_binlog_size | default('100M') }}
binlog_format = {{ mysql_binlog_format | default('ROW') }}
{% endif %}

# Replication (if slave)
{% if mysql_replication_role == 'slave' %}
read_only = 1
relay-log = {{ mysql_relay_log | default('/var/log/mysql/relay-bin') }}
relay-log-index = {{ mysql_relay_log_index | default('/var/log/mysql/relay-bin.index') }}
{% endif %}

[mysql]
default-character-set = {{ mysql_character_set | default('utf8mb4') }}

[mysqldump]
quick
quote-names
max_allowed_packet = {{ mysql_max_allowed_packet | default('16M') }}

[isamchk]
key_buffer = 16M
```

### **PostgreSQL Configuration Template**
```ini
# templates/postgresql/postgresql.conf.j2
# PostgreSQL Configuration File

# Connection Settings
listen_addresses = '{{ postgresql_listen_addresses | default("localhost") }}'
port = {{ postgresql_port | default(5432) }}
max_connections = {{ postgresql_max_connections | default(100) }}
superuser_reserved_connections = {{ postgresql_superuser_reserved_connections | default(3) }}

# Memory Settings
shared_buffers = {{ postgresql_shared_buffers | default('256MB') }}
huge_pages = {{ postgresql_huge_pages | default('try') }}
temp_buffers = {{ postgresql_temp_buffers | default('8MB') }}
max_prepared_transactions = {{ postgresql_max_prepared_transactions | default(0) }}
work_mem = {{ postgresql_work_mem | default('4MB') }}
maintenance_work_mem = {{ postgresql_maintenance_work_mem | default('64MB') }}
max_stack_depth = {{ postgresql_max_stack_depth | default('2MB') }}
dynamic_shared_memory_type = {{ postgresql_dynamic_shared_memory_type | default('posix') }}

# Disk
temp_file_limit = {{ postgresql_temp_file_limit | default('-1') }}

# Kernel Resource Usage
max_files_per_process = {{ postgresql_max_files_per_process | default(1000) }}

# Write Ahead Log
wal_level = {{ postgresql_wal_level | default('replica') }}
fsync = {{ postgresql_fsync | default('on') }}
synchronous_commit = {{ postgresql_synchronous_commit | default('on') }}
wal_sync_method = {{ postgresql_wal_sync_method | default('fsync') }}
full_page_writes = {{ postgresql_full_page_writes | default('on') }}
wal_compression = {{ postgresql_wal_compression | default('off') }}
wal_buffers = {{ postgresql_wal_buffers | default('-1') }}
wal_writer_delay = {{ postgresql_wal_writer_delay | default('200ms') }}
checkpoint_timeout = {{ postgresql_checkpoint_timeout | default('5min') }}
max_wal_size = {{ postgresql_max_wal_size | default('1GB') }}
min_wal_size = {{ postgresql_min_wal_size | default('80MB') }}
checkpoint_completion_target = {{ postgresql_checkpoint_completion_target | default(0.5) }}

# Replication
{% if postgresql_replication_enabled | default(false) %}
max_wal_senders = {{ postgresql_max_wal_senders | default(10) }}
wal_keep_segments = {{ postgresql_wal_keep_segments | default(32) }}
hot_standby = {{ postgresql_hot_standby | default('on') }}
max_standby_archive_delay = {{ postgresql_max_standby_archive_delay | default('30s') }}
max_standby_streaming_delay = {{ postgresql_max_standby_streaming_delay | default('30s') }}
wal_receiver_status_interval = {{ postgresql_wal_receiver_status_interval | default('10s') }}
hot_standby_feedback = {{ postgresql_hot_standby_feedback | default('off') }}
{% endif %}

# Query Tuning
random_page_cost = {{ postgresql_random_page_cost | default(1.1) }}
cpu_tuple_cost = {{ postgresql_cpu_tuple_cost | default(0.01) }}
cpu_index_tuple_cost = {{ postgresql_cpu_index_tuple_cost | default(0.005) }}
cpu_operator_cost = {{ postgresql_cpu_operator_cost | default(0.0025) }}
effective_cache_size = {{ postgresql_effective_cache_size | default('4GB') }}
default_statistics_target = {{ postgresql_default_statistics_target | default(100) }}

# Error Reporting and Logging
log_destination = '{{ postgresql_log_destination | default("stderr") }}'
logging_collector = {{ postgresql_logging_collector | default('off') }}
log_directory = '{{ postgresql_log_directory | default("log") }}'
log_filename = '{{ postgresql_log_filename | default("postgresql-%Y-%m-%d_%H%M%S.log") }}'
log_file_mode = {{ postgresql_log_file_mode | default('0600') }}
log_truncate_on_rotation = {{ postgresql_log_truncate_on_rotation | default('off') }}
log_rotation_age = {{ postgresql_log_rotation_age | default('1d') }}
log_rotation_size = {{ postgresql_log_rotation_size | default('10MB') }}
log_min_duration_statement = {{ postgresql_log_min_duration_statement | default(-1) }}
log_checkpoints = {{ postgresql_log_checkpoints | default('off') }}
log_connections = {{ postgresql_log_connections | default('off') }}
log_disconnections = {{ postgresql_log_disconnections | default('off') }}
log_lock_waits = {{ postgresql_log_lock_waits | default('off') }}
log_statement = '{{ postgresql_log_statement | default("none") }}'
log_temp_files = {{ postgresql_log_temp_files | default(-1) }}

# Locale and Formatting
datestyle = '{{ postgresql_datestyle | default("iso, mdy") }}'
timezone = '{{ postgresql_timezone | default("UTC") }}'
lc_messages = '{{ postgresql_lc_messages | default("en_US.UTF-8") }}'
lc_monetary = '{{ postgresql_lc_monetary | default("en_US.UTF-8") }}'
lc_numeric = '{{ postgresql_lc_numeric | default("en_US.UTF-8") }}'
lc_time = '{{ postgresql_lc_time | default("en_US.UTF-8") }}'
default_text_search_config = '{{ postgresql_default_text_search_config | default("pg_catalog.english") }}'
```

---

## 🐳 Template Docker e Container

### **Docker Compose Template**
```yaml
# templates/docker/docker-compose.yml.j2
version: '{{ docker_compose_version | default("3.8") }}'

services:
  {% if web_service_enabled | default(true) %}
  web:
    image: {{ web_image | default('nginx:alpine') }}
    container_name: {{ app_name }}-web
    restart: {{ restart_policy | default('unless-stopped') }}
    ports:
      - "{{ web_port | default(80) }}:80"
      {% if ssl_enabled | default(false) %}
      - "{{ ssl_port | default(443) }}:443"
      {% endif %}
    volumes:
      - {{ web_config_path | default('./nginx.conf') }}:/etc/nginx/nginx.conf:ro
      - {{ web_content_path | default('./html') }}:/usr/share/nginx/html:ro
      {% if ssl_enabled | default(false) %}
      - {{ ssl_cert_path }}:/etc/ssl/certs/server.crt:ro
      - {{ ssl_key_path }}:/etc/ssl/private/server.key:ro
      {% endif %}
    networks:
      - {{ network_name | default('app-network') }}
    depends_on:
      - app
    environment:
      - NGINX_ENV={{ environment | default('production') }}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    {% if resource_limits_enabled | default(false) %}
    deploy:
      resources:
        limits:
          cpus: '{{ web_cpu_limit | default("0.5") }}'
          memory: {{ web_memory_limit | default('512M') }}
        reservations:
          cpus: '{{ web_cpu_reservation | default("0.25") }}'
          memory: {{ web_memory_reservation | default('256M') }}
    {% endif %}
  {% endif %}

  app:
    image: {{ app_image }}
    container_name: {{ app_name }}-app
    restart: {{ restart_policy | default('unless-stopped') }}
    {% if app_port_exposed | default(false) %}
    ports:
      - "{{ app_port | default(8080) }}:{{ app_port | default(8080) }}"
    {% endif %}
    volumes:
      - {{ app_config_path | default('./config') }}:/app/config:ro
      - {{ app_data_path | default('./data') }}:/app/data
      - {{ app_logs_path | default('./logs') }}:/app/logs
    networks:
      - {{ network_name | default('app-network') }}
    environment:
      - NODE_ENV={{ environment | default('production') }}
      - PORT={{ app_port | default(8080) }}
      - DATABASE_URL={{ database_url }}
      {% for key, value in app_environment_vars.items() %}
      - {{ key }}={{ value }}
      {% endfor %}
    {% if database_service_enabled | default(true) %}
    depends_on:
      - database
    {% endif %}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:{{ app_port | default(8080) }}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    {% if resource_limits_enabled | default(false) %}
    deploy:
      resources:
        limits:
          cpus: '{{ app_cpu_limit | default("1.0") }}'
          memory: {{ app_memory_limit | default('1G') }}
        reservations:
          cpus: '{{ app_cpu_reservation | default("0.5") }}'
          memory: {{ app_memory_reservation | default('512M') }}
    {% endif %}

  {% if database_service_enabled | default(true) %}
  database:
    image: {{ database_image | default('postgres:13-alpine') }}
    container_name: {{ app_name }}-db
    restart: {{ restart_policy | default('unless-stopped') }}
    ports:
      - "{{ database_port | default(5432) }}:{{ database_port | default(5432) }}"
    volumes:
      - {{ database_data_path | default('./postgres-data') }}:/var/lib/postgresql/data
      - {{ database_backup_path | default('./backups') }}:/backups
      {% if database_init_scripts | default([]) | length > 0 %}
      {% for script in database_init_scripts %}
      - {{ script }}:/docker-entrypoint-initdb.d/{{ script | basename }}
      {% endfor %}
      {% endif %}
    networks:
      - {{ network_name | default('app-network') }}
    environment:
      - POSTGRES_DB={{ database_name }}
      - POSTGRES_USER={{ database_user }}
      - POSTGRES_PASSWORD={{ database_password }}
      {% if database_environment_vars is defined %}
      {% for key, value in database_environment_vars.items() %}
      - {{ key }}={{ value }}
      {% endfor %}
      {% endif %}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U {{ database_user }} -d {{ database_name }}"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    {% if resource_limits_enabled | default(false) %}
    deploy:
      resources:
        limits:
          cpus: '{{ db_cpu_limit | default("1.0") }}'
          memory: {{ db_memory_limit | default('1G') }}
        reservations:
          cpus: '{{ db_cpu_reservation | default("0.5") }}'
          memory: {{ db_memory_reservation | default('512M') }}
    {% endif %}
  {% endif %}

  {% if redis_enabled | default(false) %}
  redis:
    image: {{ redis_image | default('redis:6-alpine') }}
    container_name: {{ app_name }}-redis
    restart: {{ restart_policy | default('unless-stopped') }}
    ports:
      - "{{ redis_port | default(6379) }}:6379"
    volumes:
      - {{ redis_data_path | default('./redis-data') }}:/data
      {% if redis_config_path is defined %}
      - {{ redis_config_path }}:/usr/local/etc/redis/redis.conf
      {% endif %}
    networks:
      - {{ network_name | default('app-network') }}
    {% if redis_config_path is defined %}
    command: redis-server /usr/local/etc/redis/redis.conf
    {% endif %}
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    {% if resource_limits_enabled | default(false) %}
    deploy:
      resources:
        limits:
          cpus: '{{ redis_cpu_limit | default("0.5") }}'
          memory: {{ redis_memory_limit | default('512M') }}
    {% endif %}
  {% endif %}

  {% if monitoring_enabled | default(false) %}
  prometheus:
    image: {{ prometheus_image | default('prom/prometheus:latest') }}
    container_name: {{ app_name }}-prometheus
    restart: {{ restart_policy | default('unless-stopped') }}
    ports:
      - "{{ prometheus_port | default(9090) }}:9090"
    volumes:
      - {{ prometheus_config_path | default('./prometheus.yml') }}:/etc/prometheus/prometheus.yml:ro
      - {{ prometheus_data_path | default('./prometheus-data') }}:/prometheus
    networks:
      - {{ network_name | default('app-network') }}
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time={{ prometheus_retention | default("15d") }}'
      - '--web.enable-lifecycle'

  grafana:
    image: {{ grafana_image | default('grafana/grafana:latest') }}
    container_name: {{ app_name }}-grafana
    restart: {{ restart_policy | default('unless-stopped') }}
    ports:
      - "{{ grafana_port | default(3000) }}:3000"
    volumes:
      - {{ grafana_data_path | default('./grafana-data') }}:/var/lib/grafana
      {% if grafana_config_path is defined %}
      - {{ grafana_config_path }}:/etc/grafana/grafana.ini
      {% endif %}
    networks:
      - {{ network_name | default('app-network') }}
    environment:
      - GF_SECURITY_ADMIN_PASSWORD={{ grafana_admin_password | default('admin') }}
      - GF_USERS_ALLOW_SIGN_UP=false
    depends_on:
      - prometheus
  {% endif %}

networks:
  {{ network_name | default('app-network') }}:
    driver: bridge
    {% if network_subnet is defined %}
    ipam:
      config:
        - subnet: {{ network_subnet }}
    {% endif %}

{% if volumes_defined | default(false) %}
volumes:
  {% if database_service_enabled | default(true) %}
  {{ database_data_path | default('postgres-data') | basename }}:
    driver: local
  {% endif %}
  {% if redis_enabled | default(false) %}
  {{ redis_data_path | default('redis-data') | basename }}:
    driver: local
  {% endif %}
  {% if monitoring_enabled | default(false) %}
  {{ prometheus_data_path | default('prometheus-data') | basename }}:
    driver: local
  {{ grafana_data_path | default('grafana-data') | basename }}:
    driver: local
  {% endif %}
{% endif %}
```

### **Dockerfile Template**
```dockerfile
# templates/docker/Dockerfile.j2
# {{ app_name }} Dockerfile
# Build stage
FROM {{ base_image | default('node:16-alpine') }} AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
{% if app_type == 'node' %}
RUN npm ci --only=production
{% elif app_type == 'python' %}
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
{% endif %}

# Copy source code
COPY . .

{% if build_command is defined %}
# Build application
RUN {{ build_command }}
{% endif %}

# Production stage
FROM {{ runtime_image | default(base_image) }}

# Set environment
ENV NODE_ENV={{ environment | default('production') }}
ENV PORT={{ app_port | default(8080) }}

# Create app user
RUN addgroup -g {{ app_gid | default(1001) }} -S {{ app_user | default('app') }} && \
    adduser -u {{ app_uid | default(1001) }} -S {{ app_user | default('app') }} -G {{ app_user | default('app') }}

WORKDIR /app

# Copy built application
COPY --from=builder --chown={{ app_user | default('app') }}:{{ app_user | default('app') }} /app .

# Install additional packages if needed
{% if additional_packages is defined %}
RUN apk add --no-cache {{ additional_packages | join(' ') }}
{% endif %}

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD {{ health_check_command | default('curl -f http://localhost:$PORT/health || exit 1') }}

# Switch to app user
USER {{ app_user | default('app') }}

# Expose port
EXPOSE {{ app_port | default(8080) }}

# Start command
CMD ["{{ start_command | default('npm start') }}"]
```

---

## 🔧 Template Systemd Services

### **Application Service Template**
```ini
# templates/systemd/app.service.j2
[Unit]
Description={{ app_description | default(app_name + ' Application') }}
Documentation={{ app_documentation | default('') }}
After=network.target{% if database_dependency | default(false) %} {{ database_service | default('postgresql.service') }}{% endif %}

Wants=network.target
{% if database_dependency | default(false) %}
Requires={{ database_service | default('postgresql.service') }}
{% endif %}

[Service]
Type={{ service_type | default('simple') }}
User={{ app_user | default('app') }}
Group={{ app_group | default('app') }}
WorkingDirectory={{ app_directory }}

# Environment
Environment=NODE_ENV={{ environment | default('production') }}
Environment=PORT={{ app_port | default(8080) }}
{% for key, value in service_environment.items() %}
Environment={{ key }}={{ value }}
{% endfor %}

# Environment file
{% if environment_file is defined %}
EnvironmentFile={{ environment_file }}
{% endif %}

# Execution
ExecStart={{ app_executable }} {{ app_args | default('') }}
{% if pre_start_command is defined %}
ExecStartPre={{ pre_start_command }}
{% endif %}
{% if post_start_command is defined %}
ExecStartPost={{ post_start_command }}
{% endif %}
{% if reload_command is defined %}
ExecReload={{ reload_command }}
{% endif %}

# Process management
Restart={{ restart_policy | default('on-failure') }}
RestartSec={{ restart_delay | default(5) }}
TimeoutStartSec={{ start_timeout | default(60) }}
TimeoutStopSec={{ stop_timeout | default(30) }}

# Resource limits
{% if memory_limit is defined %}
MemoryLimit={{ memory_limit }}
{% endif %}
{% if cpu_quota is defined %}
CPUQuota={{ cpu_quota }}%
{% endif %}
{% if file_limit is defined %}
LimitNOFILE={{ file_limit }}
{% endif %}

# Security
{% if security_enabled | default(true) %}
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths={{ app_directory }}{% if additional_rw_paths is defined %}{% for path in additional_rw_paths %} {{ path }}{% endfor %}{% endif %}

{% endif %}

# Logging
StandardOutput={{ log_output | default('journal') }}
StandardError={{ log_error | default('journal') }}
SyslogIdentifier={{ app_name }}

[Install]
WantedBy=multi-user.target
```

### **Timer Service Template**
```ini
# templates/systemd/app-backup.timer.j2
[Unit]
Description={{ timer_description | default('Application backup timer') }}
Requires={{ timer_service_name }}.service

[Timer]
OnCalendar={{ schedule | default('daily') }}
{% if random_delay is defined %}
RandomizedDelaySec={{ random_delay }}
{% endif %}
Persistent={{ persistent | default('true') }}

[Install]
WantedBy=timers.target
```

```ini
# templates/systemd/app-backup.service.j2
[Unit]
Description={{ service_description | default('Application backup service') }}
{% if service_dependencies is defined %}
{% for dep in service_dependencies %}
After={{ dep }}
{% endfor %}
{% endif %}

[Service]
Type=oneshot
User={{ backup_user | default('backup') }}
Group={{ backup_group | default('backup') }}

# Environment
{% for key, value in backup_environment.items() %}
Environment={{ key }}={{ value }}
{% endfor %}

# Execution
ExecStart={{ backup_script_path }}
{% if backup_args is defined %}
ExecStartPost={{ backup_post_command }}
{% endif %}

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier={{ service_name | default('app-backup') }}

# Timeout
TimeoutStartSec={{ backup_timeout | default(3600) }}
```

---

## 📊 Template Monitoring

### **Prometheus Configuration Template**
```yaml
# templates/prometheus/prometheus.yml.j2
global:
  scrape_interval: {{ scrape_interval | default('15s') }}
  evaluation_interval: {{ evaluation_interval | default('15s') }}
  external_labels:
    cluster: '{{ cluster_name | default('production') }}'
    region: '{{ region | default('us-east-1') }}'

rule_files:
  {% for rule_file in rule_files | default(['rules/*.yml']) %}
  - "{{ rule_file }}"
  {% endfor %}

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          {% for alertmanager in alertmanagers | default(['localhost:9093']) %}
          - '{{ alertmanager }}'
          {% endfor %}

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node exporter
  - job_name: 'node-exporter'
    static_configs:
      - targets:
        {% for host in groups['all'] %}
        - '{{ hostvars[host]['ansible_default_ipv4']['address'] }}:9100'
        {% endfor %}
    scrape_interval: {{ node_exporter_interval | default('30s') }}

  # Application metrics
  - job_name: '{{ app_name }}'
    static_configs:
      - targets:
        {% for host in groups['webservers'] | default([]) %}
        - '{{ hostvars[host]['ansible_default_ipv4']['address'] }}:{{ metrics_port | default(8080) }}'
        {% endfor %}
    metrics_path: {{ metrics_path | default('/metrics') }}
    scrape_interval: {{ app_scrape_interval | default('30s') }}

  {% if database_monitoring | default(false) %}
  # Database exporter
  - job_name: 'database'
    static_configs:
      - targets:
        {% for host in groups['databases'] | default([]) %}
        - '{{ hostvars[host]['ansible_default_ipv4']['address'] }}:{{ db_exporter_port | default(9187) }}'
        {% endfor %}
    scrape_interval: {{ db_scrape_interval | default('60s') }}
  {% endif %}

  {% if nginx_monitoring | default(false) %}
  # Nginx exporter
  - job_name: 'nginx'
    static_configs:
      - targets:
        {% for host in groups['webservers'] | default([]) %}
        - '{{ hostvars[host]['ansible_default_ipv4']['address'] }}:{{ nginx_exporter_port | default(9113) }}'
        {% endfor %}
  {% endif %}

  {% if custom_exporters is defined %}
  # Custom exporters
  {% for exporter in custom_exporters %}
  - job_name: '{{ exporter.name }}'
    static_configs:
      - targets: {{ exporter.targets }}
    {% if exporter.scrape_interval is defined %}
    scrape_interval: {{ exporter.scrape_interval }}
    {% endif %}
    {% if exporter.metrics_path is defined %}
    metrics_path: {{ exporter.metrics_path }}
    {% endif %}
  {% endfor %}
  {% endif %}
```

### **Grafana Dashboard JSON Template**
```json
{
  "dashboard": {
    "id": null,
    "title": "{{ dashboard_title | default('Application Dashboard') }}",
    "tags": {{ dashboard_tags | default(['ansible', 'monitoring']) | to_json }},
    "timezone": "{{ timezone | default('browser') }}",
    "refresh": "{{ refresh_interval | default('30s') }}",
    "time": {
      "from": "now-{{ time_range | default('1h') }}",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "System Overview",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"node-exporter\"}",
            "legendFormat": "Hosts Up"
          }
        ],
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{ "{{" }}instance{{ "}}" }}"
          }
        ],
        "yAxes": [
          {"min": 0, "max": 100, "unit": "percent"}
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4}
      },
      {
        "id": 3,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100",
            "legendFormat": "{{ "{{" }}instance{{ "}}" }}"
          }
        ],
        "yAxes": [
          {"min": 0, "max": 100, "unit": "percent"}
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4}
      }
    ]
  }
}
```

---

Questi template forniscono una base solida per configurazioni complesse e possono essere personalizzati secondo le specifiche esigenze del tuo ambiente!
