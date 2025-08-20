# 📖 Appendice C - Glossario

> **Scopo**: Definizioni complete di termini, concetti e acronimi utilizzati in Ansible e nell'automazione dell'infrastruttura.

## 🔤 A-C

### **Ad-hoc Commands**
Comandi Ansible eseguiti direttamente dalla command line senza utilizzare un playbook. Utilizzati per operazioni rapide come `ansible all -m ping`.

### **Ansible**
Piattaforma open-source di automazione IT che consente di gestire configurazioni, deployments e orchestrazione attraverso SSH (Linux) e WinRM (Windows).

### **Ansible Collections**
Formato di distribuzione per moduli, plugin, roles e playbook Ansible. Le collections organizzano contenuti correlati in un package distribuibile.

### **Ansible Galaxy**
Repository online della community per condividere roles e collections Ansible. Accessibile tramite `ansible-galaxy` command.

### **Ansible Playbook**
File YAML che definisce una serie di tasks da eseguire su host target. Rappresenta il "cosa fare" nell'automazione.

### **Ansible Vault**
Sistema di crittografia integrato in Ansible per proteggere dati sensibili come password e chiavi API all'interno dei file di configurazione.

### **AWX**
Versione open-source di Ansible Tower, fornisce un'interfaccia web per gestire playbook, inventory e scheduling.

### **Become**
Meccanismo di privilege escalation in Ansible, equivalente a `sudo` su Linux o `runas` su Windows.

### **Block**
Struttura logica che raggruppa tasks correlati, permettendo gestione unificata di errori e conditions.

### **Callback Plugin**
Plugin che estende il comportamento di output di Ansible, utile per logging customizzato o integrazioni con sistemi esterni.

### **Check Mode**
Modalità "dry run" di Ansible (`--check`) che simula l'esecuzione senza apportare modifiche reali al sistema.

### **Collections**
Vedi *Ansible Collections*.

### **Conditionals**
Istruzioni `when` che determinano se una task deve essere eseguita basandosi su variabili o facts.

### **Control Node**
Sistema da cui si eseguono comandi e playbook Ansible. Deve avere Ansible installato.

## 🔤 D-F

### **Delegate**
Meccanismo per eseguire una task su un host diverso da quello target (`delegate_to`).

### **Dynamic Inventory**
Script o plugin che genera automaticamente l'inventory da fonti esterne come cloud providers o CMDB.

### **Facts**
Informazioni di sistema automaticamente raccolte da Ansible sui managed nodes (OS, network, hardware, etc.).

### **Facts Caching**
Memorizzazione dei facts per evitare raccolta ripetuta, migliorando le performance.

### **Forks**
Numero di connessioni parallele che Ansible può stabilire contemporaneamente (configurabile in `ansible.cfg`).

### **Handlers**
Tasks speciali eseguite solo quando notificate da altre tasks, tipicamente per restart di servizi.

## 🔤 G-I

### **Gather Facts**
Processo automatico di raccolta informazioni sui managed nodes all'inizio dell'esecuzione del playbook.

### **Group Variables (group_vars)**
Variabili applicate a tutti gli host appartenenti a un gruppo specifico nell'inventory.

### **Host Variables (host_vars)**
Variabili specifiche per un singolo host nell'inventory.

### **Idempotency**
Caratteristica per cui l'esecuzione ripetuta di un'operazione produce sempre lo stesso risultato senza effetti collaterali.

### **Includes**
Meccanismo per includere contenuto da file esterni nei playbook (`include_tasks`, `include_vars`).

### **Inventory**
File o script che definisce gli host gestiti da Ansible e la loro organizzazione in gruppi.

## 🔤 J-L

### **Jinja2**
Template engine utilizzato da Ansible per generare configurazioni dinamiche basate su variabili.

### **Jump Host/Bastion Host**
Server intermedio attraverso cui Ansible si connette ad altri host, utile per reti segmentate.

### **Limit**
Opzione per restringere l'esecuzione di un playbook a un subset di host (`--limit`).

### **Loops**
Costrutti per ripetere una task su una lista di elementi (`loop`, `with_items`).

## 🔤 M-O

### **Managed Nodes**
Host target su cui Ansible esegue tasks. Non richiedono software Ansible installato.

### **Meta Tasks**
Tasks speciali che controllano il comportamento del playbook (`meta: flush_handlers`).

### **Modules**
Componenti che eseguono azioni specifiche sui managed nodes (copy file, install packages, etc.).

### **Notify**
Meccanismo per triggering handlers quando una task apporta modifiche.

### **Operations (Ops)**
Termine generale per attività di gestione e manutenzione dell'infrastruttura IT.

## 🔤 P-R

### **Playbook**
Vedi *Ansible Playbook*.

### **Plugins**
Componenti che estendono le funzionalità di Ansible (callback, inventory, filter, etc.).

### **Pre/Post Tasks**
Tasks eseguite prima o dopo i roles in un playbook.

### **Register**
Meccanismo per catturare l'output di una task in una variabile per uso successivo.

### **Roles**
Struttura organizzativa che raggruppa tasks, variables, files e templates correlati per riutilizzo.

### **Rolling Updates**
Strategia di deployment che aggiorna host gradualmente per mantenere disponibilità del servizio.

### **Run Once**
Opzione per eseguire una task solo su un host del gruppo (`run_once: true`).

## 🔤 S-T

### **Serial**
Controllo del numero di host processati contemporaneamente in un playbook.

### **SSH**
Secure Shell - protocollo per connessioni sicure a sistemi Linux/Unix.

### **Strategy**
Metodo di esecuzione del playbook (linear, free, debug).

### **Tags**
Etichette per eseguire subset specifici di tasks (`--tags`, `--skip-tags`).

### **Tasks**
Singole azioni eseguite da Ansible sui managed nodes.

### **Templates**
File Jinja2 che generano configurazioni dinamiche basate su variabili.

### **Tower**
Versione enterprise di Ansible (ora "Automation Platform") con interfaccia web e funzionalità avanzate.

## 🔤 U-Z

### **Variables**
Valori dinamici utilizzati nei playbook per personalizzare comportamenti e configurazioni.

### **Vault**
Vedi *Ansible Vault*.

### **WinRM**
Windows Remote Management - protocollo per connessioni remote a sistemi Windows.

### **YAML**
Yet Another Markup Language - formato per file di configurazione Ansible.

---

## 🏗️ Architettura e Componenti

### **Ansible Architecture**
Architettura agentless dove il control node si connette ai managed nodes via SSH/WinRM per eseguire tasks.

### **Control Plane**
Insieme di componenti che gestiscono e orchestrano l'automazione (control node, inventory, playbooks).

### **Data Plane**
I managed nodes dove vengono eseguite le operazioni automatizzate.

### **Push Model**
Modello architetturale dove il control node "spinge" configurazioni ai managed nodes (opposto di pull model).

---

## 🔧 Concetti Tecnici

### **Agentless**
Caratteristica di Ansible di non richiedere software dedicato sui managed nodes, utilizzando SSH/WinRM nativi.

### **Convergence**
Processo di portare un sistema dallo stato attuale al stato desiderato definito nei playbook.

### **Desired State Configuration**
Paradigma dove si definisce lo stato finale desiderato piuttosto che i passaggi per raggiungerlo.

### **Infrastructure as Code (IaC)**
Pratica di gestire infrastruttura IT attraverso codice versioning e automatizzazione.

### **Orchestration**
Coordinamento di processi automatizzati complessi attraverso più sistemi.

### **State Management**
Gestione e mantenimento dello stato desiderato dei sistemi attraverso automazione.

---

## 🌐 Networking e Connettività

### **Connection Plugins**
Plugin che definiscono come Ansible si connette ai managed nodes (ssh, winrm, docker, etc.).

### **Host Key Checking**
Verifica delle chiavi SSH dei host per sicurezza (spesso disabilitata in ambiente automation).

### **ControlMaster/ControlPersist**
Funzionalità SSH per riutilizzare connessioni esistenti, migliorando performance.

### **Pipelining**
Ottimizzazione SSH che riduce il numero di connessioni necessarie per eseguire tasks.

---

## 🔒 Sicurezza

### **Privilege Escalation**
Processo di ottenere permessi elevati (sudo, runas) per eseguire operazioni amministrative.

### **Secrets Management**
Gestione sicura di credenziali e informazioni sensibili attraverso vault e sistemi esterni.

### **Trust Relationship**
Relazione di fiducia stabilita tra control node e managed nodes tramite chiavi SSH o certificati.

---

## 📊 Performance e Scalabilità

### **Batching**
Divisione di operazioni su grandi gruppi di host in lotti più piccoli per gestibilità.

### **Fact Gathering Optimization**
Ottimizzazioni per ridurre tempo di raccolta facts (smart gathering, caching).

### **Parallel Execution**
Esecuzione simultanea di tasks su più host per ridurre tempo totale.

### **Resource Limits**
Limitazioni su CPU, memoria e connessioni per evitare sovraccarico del control node.

---

## 🔄 DevOps e CI/CD

### **Blue-Green Deployment**
Strategia di deployment con due ambienti identici per deployment a zero downtime.

### **Canary Deployment**
Deployment graduale su subset di utenti/server per validare modifiche.

### **Continuous Deployment (CD)**
Automazione completa del pipeline di release fino alla produzione.

### **Continuous Integration (CI)**
Pratica di integrare frequentemente modifiche al codice con testing automatizzato.

### **GitOps**
Metodologia di gestione infrastruttura utilizzando Git come source of truth.

### **Pipeline as Code**
Definizione di pipeline CI/CD attraverso codice versionato.

---

## 🎯 Best Practices Terminology

### **DRY (Don't Repeat Yourself)**
Principio di evitare duplicazione di codice attraverso riutilizzo di roles e includes.

### **Fail Fast**
Filosofia di identificare e fermare errori il prima possibile nell'esecuzione.

### **Graceful Degradation**
Capacità di continuare operazioni anche quando alcuni componenti falliscono.

### **Health Checks**
Verifiche automatiche dello stato e funzionalità dei servizi.

### **Rollback Strategy**
Piano per ritornare a una versione precedente in caso di problemi con deployment.

### **Testing Strategy**
Approccio sistematico per validare automazione (unit, integration, acceptance testing).

---

## 📚 Acronimi Comuni

- **API**: Application Programming Interface
- **CIDR**: Classless Inter-Domain Routing
- **CLI**: Command Line Interface
- **CMDB**: Configuration Management Database
- **DNS**: Domain Name System
- **FQDN**: Fully Qualified Domain Name
- **GUI**: Graphical User Interface
- **HTTP/HTTPS**: HyperText Transfer Protocol (Secure)
- **IaC**: Infrastructure as Code
- **JSON**: JavaScript Object Notation
- **LDAP**: Lightweight Directory Access Protocol
- **NFS**: Network File System
- **REST**: Representational State Transfer
- **SCP**: Secure Copy Protocol
- **SFTP**: SSH File Transfer Protocol
- **SSL/TLS**: Secure Sockets Layer/Transport Layer Security
- **URL**: Uniform Resource Locator
- **VPN**: Virtual Private Network
- **XML**: eXtensible Markup Language

---

Questo glossario fornisce definizioni complete per comprendere tutti i concetti e terminologie utilizzati nell'ecosistema Ansible e nell'automazione dell'infrastruttura moderna.
