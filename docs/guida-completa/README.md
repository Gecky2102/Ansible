# 📖 Guida Completa Ansible - Automazione Infrastructure

> **🎯 Obiettivo**: Questa guida ti accompagnerà passo-passo dalla configurazione iniziale al deployment automatizzato di applicazioni su server Linux e Windows, senza assumere conoscenze pregresse di Ansible.

## 📋 Indice della Guida

### **Parte I - Fondamenti e Setup**
1. [**01 - Introduzione e Prerequisiti**](01-introduzione.md)
   - Cos'è Ansible e perché usarlo
   - Architettura e concetti base
   - Prerequisiti hardware e software
   - Preparazione dell'ambiente

2. [**02 - Installazione e Configurazione**](02-installazione.md)
   - Installazione su Windows, Linux e macOS
   - Configurazione SSH per Linux
   - Configurazione WinRM per Windows
   - Test della connettività

3. [**03 - Primo Progetto**](03-primo-progetto.md)
   - Struttura del progetto
   - Creazione inventory
   - Prime configurazioni
   - Primo comando Ansible

### **Parte II - Configurazione e Deployment**
4. [**04 - Gestione Inventory e Variabili**](04-inventory-variabili.md)
   - Inventory avanzato
   - Group vars e host vars
   - Ansible Vault per password
   - Variabili dinamiche

5. [**05 - Playbook e Tasks**](05-playbook-tasks.md)
   - Creazione playbook
   - Tasks Linux e Windows
   - Handlers e notifiche
   - Conditionals e loops

6. [**06 - Roles e Template**](06-roles-template.md)
   - Creazione e uso dei roles
   - Template Jinja2
   - Organizzazione del codice
   - Best practices

### **Parte III - Deployment e Automazione**
7. [**07 - Deployment Applicazioni**](07-deployment.md)
   - Deploy su Linux
   - Deploy su Windows
   - Rolling updates
   - Rollback automatico

8. [**08 - Monitoraggio e Logging**](08-monitoraggio.md)
   - Configurazione logging
   - Health checks
   - Notifiche automatiche
   - Dashboard e reporting

### **Parte IV - Troubleshooting e Ottimizzazione**
9. [**09 - Troubleshooting**](09-troubleshooting.md)
   - Errori comuni e soluzioni
   - Debug avanzato
   - Performance tuning
   - Best practices di sicurezza

10. [**10 - Scenari Avanzati**](10-scenari-avanzati.md)
    - Integrazione CI/CD
    - Multi-environment
    - Backup e restore
    - Scaling e load balancing

### **Appendici**
- [**A - Riferimenti Rapidi**](appendice-a-riferimenti.md)
- [**B - Template e Esempi**](appendice-b-template.md)
- [**C - Glossario**](appendice-c-glossario.md)
- [**D - Checklist Operative**](appendice-d-checklist.md)

---

## 🎯 Come Usare Questa Guida

### **👶 Se sei nuovo ad Ansible**
Inizia dal **Capitolo 1** e procedi in ordine. Ogni capitolo assume che tu abbia completato i precedenti.

### **🔄 Se hai già esperienza**
Puoi saltare direttamente ai capitoli che ti interessano:
- **Deployment**: Capitoli 7-8
- **Troubleshooting**: Capitolo 9
- **Scenari Avanzati**: Capitolo 10

### **⚡ Ricerca Rapida**
Usa l'**Appendice A** per trovare rapidamente comandi e configurazioni.

---

## 💡 Convenzioni Usate

### **Icone**
- 🔧 **Setup/Configurazione**
- ⚠️  **Attenzione/Warning**
- 💡 **Suggerimento/Tip**
- 🐛 **Debug/Troubleshooting**
- ✅ **Checkpoint/Verifica**
- 🚀 **Deployment/Automazione**

### **Codice**
```bash
# Comandi da eseguire nel terminal
comando --opzione
```

```yaml
# Configurazioni YAML
chiave: valore
```

```powershell
# Comandi PowerShell
Get-Service
```

### **Note Importanti**
> **⚠️ ATTENZIONE**: Informazioni critiche
> 
> **💡 SUGGERIMENTO**: Consigli utili
> 
> **✅ CHECKPOINT**: Punti di verifica

---

## 🏁 Cosa Imparerai

Al termine di questa guida sarai in grado di:

✅ **Installare e configurare** Ansible su qualsiasi sistema operativo  
✅ **Gestire server Linux e Windows** da un unico controller  
✅ **Creare playbook** per automatizzare deployment  
✅ **Implementare sicurezza** con vault e chiavi SSH  
✅ **Debuggare e risolvere** problemi comuni  
✅ **Scalare** l'automazione per ambienti enterprise  
✅ **Integrare** Ansible in pipeline CI/CD  

---


🚀 **Pronto per iniziare?** Vai al [**Capitolo 1 - Introduzione**](01-introduzione.md)!
