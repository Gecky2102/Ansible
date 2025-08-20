# Makefile per automazione Ansible
# Uso: make <target>

.PHONY: help setup test deploy clean lint

# Variabili
INVENTORY := inventory/hosts.yml
PLAYBOOK := playbooks/site.yml
ENV := development

# Help - mostra tutti i target disponibili
help:
	@echo "Ansible Automation Makefile"
	@echo ""
	@echo "Target disponibili:"
	@echo "  help     - Mostra questo help"
	@echo "  setup    - Setup iniziale progetto"
	@echo "  test     - Test connettività host"
	@echo "  deploy   - Deploy completo (ENV=development)"
	@echo "  linux    - Deploy solo Linux"
	@echo "  windows  - Deploy solo Windows"
	@echo "  app      - Deploy applicazione"
	@echo "  check    - Dry run senza modifiche"
	@echo "  lint     - Verifica sintassi playbook"
	@echo "  vault    - Crea nuovo vault"
	@echo "  clean    - Pulizia file temporanei"
	@echo ""
	@echo "Variabili:"
	@echo "  ENV      - Environment target (default: development)"
	@echo ""
	@echo "Esempi:"
	@echo "  make deploy ENV=production"
	@echo "  make test"
	@echo "  make check ENV=staging"

# Setup iniziale del progetto
setup:
	@echo "🔧 Setup iniziale progetto Ansible..."
	pip install ansible pywinrm[kerberos]
	@echo "✅ Setup completato!"
	@echo ""
	@echo "Prossimi passi:"
	@echo "1. Configura inventory/hosts.yml con i tuoi server"
	@echo "2. Crea vault: make vault"
	@echo "3. Test connettività: make test"
	@echo "4. Deploy: make deploy"

# Test connettività
test:
	@echo "🔍 Test connettività host..."
	ansible all -i $(INVENTORY) -m ping --limit $(ENV)

# Test connettività Windows
test-windows:
	@echo "🔍 Test connettività Windows..."
	ansible windows_servers -i $(INVENTORY) -m win_ping --limit $(ENV)

# Deploy completo
deploy:
	@echo "🚀 Deploy completo environment: $(ENV)"
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --limit $(ENV)

# Deploy solo Linux
linux:
	@echo "🐧 Deploy Linux environment: $(ENV)"
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --limit $(ENV) --tags linux

# Deploy solo Windows
windows:
	@echo "🪟 Deploy Windows environment: $(ENV)"
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --limit $(ENV) --tags windows

# Deploy applicazione
app:
	@echo "📦 Deploy applicazione environment: $(ENV)"
	ansible-playbook -i $(INVENTORY) playbooks/deploy_app.yml --limit $(ENV)

# Dry run - verifica senza applicare modifiche
check:
	@echo "🧪 Dry run environment: $(ENV)"
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --limit $(ENV) --check

# Verifica sintassi playbook
lint:
	@echo "🔍 Verifica sintassi playbook..."
	ansible-playbook --syntax-check $(PLAYBOOK)
	ansible-playbook --syntax-check playbooks/linux_setup.yml
	ansible-playbook --syntax-check playbooks/windows_setup.yml
	ansible-playbook --syntax-check playbooks/deploy_app.yml
	@echo "✅ Sintassi corretta!"

# Crea nuovo vault
vault:
	@echo "🔐 Creazione nuovo vault..."
	ansible-vault create group_vars/all/vault.yml

# Modifica vault esistente
edit-vault:
	@echo "🔐 Modifica vault esistente..."
	ansible-vault edit group_vars/all/vault.yml

# Lista host inventory
list-hosts:
	@echo "📋 Lista host inventory:"
	ansible-inventory -i $(INVENTORY) --list

# Mostra fatti di un host
facts:
	@echo "📊 Raccolta fatti host..."
	ansible $(HOST) -i $(INVENTORY) -m setup

# Pulizia file temporanei
clean:
	@echo "🧹 Pulizia file temporanei..."
	find . -name "*.retry" -delete
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	rm -f ansible.log
	@echo "✅ Pulizia completata!"

# Backup configurazioni
backup:
	@echo "💾 Backup configurazioni..."
	tar -czf backup-$(shell date +%Y%m%d-%H%M%S).tar.gz \
		inventory/ group_vars/ host_vars/ playbooks/ roles/ \
		--exclude='group_vars/all/vault.yml'
	@echo "✅ Backup creato!"

# Validazione completa
validate: lint test
	@echo "✅ Validazione completa superata!"

# Install dependencies
deps:
	@echo "📦 Installazione dipendenze..."
	pip install -r requirements.txt

# Genera requirements.txt
requirements:
	@echo "📝 Generazione requirements.txt..."
	echo "ansible>=6.0.0" > requirements.txt
	echo "pywinrm[kerberos]>=0.4.3" >> requirements.txt
	echo "netaddr>=0.8.0" >> requirements.txt
	echo "jmespath>=1.0.1" >> requirements.txt

# Informazioni di debug
debug:
	@echo "🐛 Informazioni debug:"
	@echo "Ansible version: $(shell ansible --version | head -1)"
	@echo "Python version: $(shell python --version)"
	@echo "Current directory: $(shell pwd)"
	@echo "Inventory file: $(INVENTORY)"
	@echo "Environment: $(ENV)"
