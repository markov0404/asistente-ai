# ═══════════════════════════════════════════════════════════════════
#  Asistente AI — Instalador para Windows
#  Ejecutar en PowerShell como Administrador:
#    irm https://raw.githubusercontent.com/markov0404/asistente-ai/main/install.ps1 | iex
#  O:
#    .\install.ps1
# ═══════════════════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [ERROR] $msg" -ForegroundColor Red }

Clear-Host
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor White
Write-Host "  ║         Asistente AI — Instalador         ║" -ForegroundColor White
Write-Host "  ║     Tu asistente personal con IA local    ║" -ForegroundColor White
Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor White
Write-Host ""
Write-Host "  Este instalador va a configurar todo lo necesario:" -ForegroundColor Gray
Write-Host ""
Write-Host "  1. WSL2 (Windows Subsystem for Linux)" -ForegroundColor Gray
Write-Host "  2. Ubuntu en WSL" -ForegroundColor Gray
Write-Host "  3. Docker dentro de WSL" -ForegroundColor Gray
Write-Host "  4. El asistente (setup interactivo)" -ForegroundColor Gray
Write-Host ""
Read-Host "  Presiona Enter para comenzar"

# ── Check admin ──────────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Err "Este script necesita ejecutarse como Administrador."
    Write-Host "  Hace clic derecho en PowerShell -> 'Ejecutar como administrador'" -ForegroundColor Gray
    Read-Host "  Presiona Enter para salir"
    exit 1
}

# ── Step 1: WSL2 ─────────────────────────────────────────────────
Write-Step "1/4 — Verificando WSL2"

$wslInstalled = $false
try {
    $wslVersion = wsl --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $wslInstalled = $true
        Write-Ok "WSL2 ya esta instalado"
    }
} catch {}

if (-not $wslInstalled) {
    Write-Warn "WSL2 no encontrado. Instalando..."
    Write-Host "  Esto puede tomar unos minutos y requiere reiniciar." -ForegroundColor Gray

    wsl --install --no-distribution

    if ($LASTEXITCODE -ne 0) {
        # Fallback: enable features manually
        Write-Warn "Habilitando componentes de Windows..."
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    }

    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║  WSL2 instalado. NECESITAS REINICIAR WINDOWS.    ║" -ForegroundColor Yellow
    Write-Host "  ║                                                   ║" -ForegroundColor Yellow
    Write-Host "  ║  Despues de reiniciar, volve a correr:           ║" -ForegroundColor Yellow
    Write-Host "  ║    .\install.ps1                                  ║" -ForegroundColor Yellow
    Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Presiona Enter para reiniciar"
    Restart-Computer -Force
    exit 0
}

# ── Step 2: Ubuntu ───────────────────────────────────────────────
Write-Step "2/4 — Verificando Ubuntu en WSL"

$distros = wsl -l -q 2>&1 | Where-Object { $_ -match "Ubuntu" }

if ($distros) {
    Write-Ok "Ubuntu ya esta instalado en WSL"
} else {
    Write-Warn "Instalando Ubuntu en WSL..."
    wsl --install -d Ubuntu
    Write-Ok "Ubuntu instalado"
    Write-Host ""
    Write-Host "  Se va a abrir una ventana de Ubuntu para crear tu usuario." -ForegroundColor Gray
    Write-Host "  Cuando termines, volve aca y presiona Enter." -ForegroundColor Gray
    Read-Host "  Presiona Enter para continuar"
}

# ── Step 3: Docker ───────────────────────────────────────────────
Write-Step "3/4 — Verificando Docker en WSL"

$dockerCheck = wsl -d Ubuntu -- bash -c "docker --version 2>/dev/null" 2>&1

if ($dockerCheck -match "Docker version") {
    Write-Ok "Docker ya esta instalado en WSL"
} else {
    Write-Warn "Instalando Docker en WSL..."

    $dockerScript = @'
set -e
# Install Docker
curl -fsSL https://get.docker.com | sh
# Add user to docker group
sudo usermod -aG docker $USER
# Start Docker
sudo service docker start
# Install Docker Compose v2 plugin
mkdir -p ~/.docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
echo "Docker instalado OK"
'@

    $dockerScript | wsl -d Ubuntu -- bash

    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Docker instalado en WSL"
    } else {
        Write-Err "Error instalando Docker. Intenta instalar Docker Desktop desde https://docker.com/products/docker-desktop/"
        Read-Host "Presiona Enter para continuar de todas formas"
    }
}

# ── Step 4: Clone and setup ─────────────────────────────────────
Write-Step "4/4 — Instalando Asistente AI"

$repoUrl = "https://github.com/markov0404/asistente-ai.git"
$installDir = "~/asistente-ai"

$setupScript = @"
set -e
# Ensure docker is running
sudo service docker start 2>/dev/null || true
# Clone repo if not exists
if [ ! -d "$installDir" ]; then
    git clone $repoUrl $installDir
fi
cd $installDir
# Make sure docker service is running
sudo service docker start
# Run the interactive setup wizard
./setup.sh
"@

Write-Host ""
Write-Host "  Ahora se va a abrir el wizard de instalacion en WSL." -ForegroundColor Gray
Write-Host "  Segui las instrucciones interactivas." -ForegroundColor Gray
Write-Host ""
Read-Host "  Presiona Enter para comenzar el setup"

wsl -d Ubuntu -- bash -c $setupScript

# ── Done ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║         Asistente AI — Instalacion completa!      ║" -ForegroundColor Green
Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Tu asistente esta corriendo. Enviale un mensaje por WhatsApp!" -ForegroundColor White
Write-Host ""
Write-Host "  Panel de control: http://127.0.0.1:18789/" -ForegroundColor Gray
Write-Host ""
Write-Host "  Comandos utiles (en WSL/Ubuntu):" -ForegroundColor Gray
Write-Host "    cd ~/asistente-ai && docker compose logs -f    # Ver logs" -ForegroundColor DarkGray
Write-Host "    cd ~/asistente-ai && docker compose restart    # Reiniciar" -ForegroundColor DarkGray
Write-Host "    cd ~/asistente-ai && ./uninstall.sh            # Desinstalar" -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Presiona Enter para cerrar"
