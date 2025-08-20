#!/bin/bash

# Script per eseguire deployment Ansible
# Uso: ./deploy.sh [environment] [tags]

set -e

ENVIRONMENT=${1:-development}
TAGS=${2:-all}
INVENTORY_FILE="inventory/hosts.yml"
PLAYBOOK="playbooks/site.yml"

echo "🚀 Avvio deployment Ansible"
echo "Environment: $ENVIRONMENT"
echo "Tags: $TAGS"
echo "Inventory: $INVENTORY_FILE"
echo "Playbook: $PLAYBOOK"
echo ""

# Verifica che i file esistano
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "❌ File inventory non trovato: $INVENTORY_FILE"
    exit 1
fi

if [ ! -f "$PLAYBOOK" ]; then
    echo "❌ Playbook non trovato: $PLAYBOOK"
    exit 1
fi

# Verifica connettività
echo "🔍 Verifica connettività hosts..."
ansible all -i "$INVENTORY_FILE" -m ping --limit "$ENVIRONMENT"

if [ $? -ne 0 ]; then
    echo "❌ Problemi di connettività rilevati"
    read -p "Continuare comunque? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Esegui il playbook
echo ""
echo "🎬 Esecuzione playbook..."
if [ "$TAGS" == "all" ]; then
    ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK" --limit "$ENVIRONMENT"
else
    ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK" --limit "$ENVIRONMENT" --tags "$TAGS"
fi

echo ""
echo "✅ Deployment completato!"
