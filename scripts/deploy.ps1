# Script PowerShell per deployment Ansible
# Uso: .\deploy.ps1 -Environment "development" -Tags "all"

param(
    [string]$Environment = "development",
    [string]$Tags = "all",
    [string]$InventoryFile = "inventory\hosts.yml",
    [string]$Playbook = "playbooks\site.yml",
    [switch]$DryRun = $false,
    [switch]$Verbose = $false
)

# Colori per output
$Green = [System.ConsoleColor]::Green
$Red = [System.ConsoleColor]::Red
$Yellow = [System.ConsoleColor]::Yellow
$Blue = [System.ConsoleColor]::Blue

function Write-ColorOutput {
    param([string]$Message, [System.ConsoleColor]$Color = [System.ConsoleColor]::White)
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "🚀 Avvio deployment Ansible" $Blue
Write-ColorOutput "Environment: $Environment" $Green
Write-ColorOutput "Tags: $Tags" $Green
Write-ColorOutput "Inventory: $InventoryFile" $Green
Write-ColorOutput "Playbook: $Playbook" $Green
Write-Host ""

# Verifica che i file esistano
if (-not (Test-Path $InventoryFile)) {
    Write-ColorOutput "❌ File inventory non trovato: $InventoryFile" $Red
    exit 1
}

if (-not (Test-Path $Playbook)) {
    Write-ColorOutput "❌ Playbook non trovato: $Playbook" $Red
    exit 1
}

# Verifica che Ansible sia installato
try {
    $ansibleVersion = ansible --version
    Write-ColorOutput "✅ Ansible trovato" $Green
} catch {
    Write-ColorOutput "❌ Ansible non installato. Installare con: pip install ansible" $Red
    exit 1
}

# Verifica connettività
Write-ColorOutput "🔍 Verifica connettività hosts..." $Yellow
$pingResult = ansible all -i $InventoryFile -m ping --limit $Environment

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Problemi di connettività rilevati" $Red
    $continue = Read-Host "Continuare comunque? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

# Costruisci comando ansible-playbook
$ansibleCommand = "ansible-playbook -i `"$InventoryFile`" `"$Playbook`" --limit `"$Environment`""

if ($Tags -ne "all") {
    $ansibleCommand += " --tags `"$Tags`""
}

if ($DryRun) {
    $ansibleCommand += " --check"
    Write-ColorOutput "🧪 Modalità DRY RUN attivata" $Yellow
}

if ($Verbose) {
    $ansibleCommand += " -v"
}

# Esegui il playbook
Write-Host ""
Write-ColorOutput "🎬 Esecuzione playbook..." $Blue
Write-ColorOutput "Comando: $ansibleCommand" $Yellow

Invoke-Expression $ansibleCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-ColorOutput "✅ Deployment completato con successo!" $Green
} else {
    Write-Host ""
    Write-ColorOutput "❌ Deployment fallito con errori" $Red
    exit $LASTEXITCODE
}
