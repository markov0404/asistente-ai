# Asistente AI - Instalador para Windows
# Uso: iwr https://raw.githubusercontent.com/markov0404/asistente-ai/main/install.ps1 -OutFile $env:TEMP\install.ps1; & $env:TEMP\install.ps1

# If running via irm | iex, re-launch as file to fix formatting
if (-not $MyInvocation.MyCommand.Path) {
    $tmpFile = "$env:TEMP\asistente-ai-install.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/markov0404/asistente-ai/main/install.ps1" -OutFile $tmpFile
    & $tmpFile
    Remove-Item $tmpFile -ErrorAction SilentlyContinue
    return
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ""
    Write-Host ">>> $msg" -ForegroundColor Cyan
}
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [ERROR] $msg" -ForegroundColor Red }

Clear-Host
Write-Host ""
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host "          Asistente AI - Instalador            " -ForegroundColor White
Write-Host "      Tu asistente personal con IA local       " -ForegroundColor Gray
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Este instalador va a configurar:" -ForegroundColor Gray
Write-Host "    1. WSL2 (Windows Subsystem for Linux)" -ForegroundColor Gray
Write-Host "    2. Ubuntu en WSL" -ForegroundColor Gray
Write-Host "    3. Docker dentro de WSL" -ForegroundColor Gray
Write-Host "    4. El asistente (setup interactivo)" -ForegroundColor Gray
Write-Host ""
Read-Host "  Presiona Enter para comenzar"

# -- Check admin --
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Err "Este script necesita ejecutarse como Administrador."
    Write-Host "  Clic derecho en PowerShell -> 'Ejecutar como administrador'" -ForegroundColor Gray
    Read-Host "  Presiona Enter para salir"
    exit 1
}

# -- Step 1: WSL2 --
Write-Step "1/4 - Verificando WSL2"

$wslInstalled = $false
try {
    $null = wsl --version 2>&1
    if ($LASTEXITCODE -eq 0) { $wslInstalled = $true }
} catch {}

if ($wslInstalled) {
    Write-Ok "WSL2 ya esta instalado"
} else {
    Write-Warn "WSL2 no encontrado. Instalando..."
    wsl --install --no-distribution 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
    }

    Write-Host ""
    Write-Host "  WSL2 instalado. NECESITAS REINICIAR WINDOWS." -ForegroundColor Yellow
    Write-Host "  Despues de reiniciar, volve a ejecutar este instalador." -ForegroundColor Yellow
    Write-Host ""
    $restart = Read-Host "  Reiniciar ahora? (S/n)"
    if ($restart -ne "n") { Restart-Computer -Force }
    exit 0
}

# -- Step 2: Ubuntu --
Write-Step "2/4 - Verificando Ubuntu en WSL"

$hasUbuntu = $false
try {
    $distroList = wsl -l -q 2>&1
    foreach ($line in $distroList) {
        if ($line -match "Ubuntu") { $hasUbuntu = $true; break }
    }
} catch {}

if ($hasUbuntu) {
    Write-Ok "Ubuntu ya esta instalado en WSL"
} else {
    Write-Warn "Instalando Ubuntu en WSL..."
    Write-Host "  Esto puede tardar unos minutos descargando..." -ForegroundColor Gray

    wsl --install -d Ubuntu --no-launch 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

    Write-Ok "Ubuntu descargado"
    Write-Host ""
    Write-Host "  Ahora necesitas crear tu usuario de Linux." -ForegroundColor White
    Write-Host "  Se va a abrir Ubuntu. Crea un nombre de usuario y contrasena." -ForegroundColor White
    Write-Host "  Cuando termine y veas el prompt (ej: dani@PC:~$), escribi 'exit' y Enter." -ForegroundColor White
    Write-Host ""
    Read-Host "  Presiona Enter para abrir Ubuntu"

    Start-Process -FilePath "wsl.exe" -ArgumentList "-d","Ubuntu" -Wait -NoNewWindow

    Write-Ok "Usuario de Ubuntu creado"
}

# -- Step 3: Docker --
Write-Step "3/4 - Verificando Docker en WSL"

$dockerOk = $false
try {
    $dockerOut = wsl -d Ubuntu -- bash -c "docker --version 2>/dev/null"
    if ($dockerOut -match "Docker version") { $dockerOk = $true }
} catch {}

if ($dockerOk) {
    Write-Ok "Docker ya esta instalado en WSL"
} else {
    Write-Warn "Instalando Docker en WSL (esto tarda 1-2 minutos)..."
    Write-Host ""
    Write-Host "  Necesito tu contrasena de Linux (la que creaste en Ubuntu)." -ForegroundColor White
    $linuxPass = Read-Host "  Contrasena de Linux" -AsSecureString
    $plainPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($linuxPass))

    Write-Host ""
    Write-Host "  Instalando paquetes..." -ForegroundColor Gray

    $installCmd = "echo '${plainPass}' | sudo -S apt-get update -qq 2>/dev/null && echo '${plainPass}' | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io curl git >/dev/null 2>&1 && echo '${plainPass}' | sudo -S usermod -aG docker `$USER && echo '${plainPass}' | sudo -S service docker start >/dev/null 2>&1 && mkdir -p ~/.docker/cli-plugins && curl -sSL 'https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64' -o ~/.docker/cli-plugins/docker-compose && chmod +x ~/.docker/cli-plugins/docker-compose && echo 'DOCKER_OK'"

    $ErrorActionPreference = "Continue"
    $result = wsl -d Ubuntu -- bash -c $installCmd 2>&1
    $ErrorActionPreference = "Stop"
    $resultStr = $result -join "`n"

    if ($resultStr -match "DOCKER_OK") {
        Write-Ok "Docker + Docker Compose instalados"
    } else {
        Write-Err "Hubo un problema instalando Docker."
        Write-Host "  Alternativa: instala Docker Desktop desde https://docker.com/products/docker-desktop/" -ForegroundColor Yellow
        Read-Host "  Presiona Enter para continuar de todas formas"
    }
}

# -- Step 4: Clone and run setup --
Write-Step "4/4 - Instalando Asistente AI"

Write-Host ""
Write-Host "  Descargando y lanzando el wizard de configuracion..." -ForegroundColor Gray
Write-Host ""
Read-Host "  Presiona Enter para continuar"

Write-Host "  Preparando..." -ForegroundColor Gray
$prepCmd = "echo '${plainPass}' | sudo -S service docker start 2>/dev/null; if [ ! -d ~/asistente-ai ]; then git clone https://github.com/markov0404/asistente-ai.git ~/asistente-ai 2>&1; fi; echo 'PREP_OK'"
$plainPass = $null

$ErrorActionPreference = "Continue"
$prepResult = wsl -d Ubuntu -- bash -c $prepCmd 2>&1
$ErrorActionPreference = "Stop"

# Run setup wizard interactively
wsl -d Ubuntu -- bash -c "cd ~/asistente-ai && sg docker -c './setup.sh'"

# -- Done --
Write-Host ""
Write-Host "  =============================================" -ForegroundColor Green
Write-Host "      Asistente AI - Instalacion completa!     " -ForegroundColor Green
Write-Host "  =============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Tu asistente esta corriendo. Enviale un mensaje por WhatsApp!" -ForegroundColor White
Write-Host ""
Write-Host "  Panel de control: http://127.0.0.1:18789/" -ForegroundColor Gray
Write-Host ""
Write-Host "  Comandos:" -ForegroundColor Gray
Write-Host "    Detener:     wsl -- bash -c 'cd ~/asistente-ai && docker compose down'" -ForegroundColor DarkGray
Write-Host "    Reanudar:    wsl -- bash -c 'cd ~/asistente-ai && docker compose up -d openclaw-gateway'" -ForegroundColor DarkGray
Write-Host "    Desinstalar: wsl -- bash -c 'cd ~/asistente-ai && ./uninstall.sh'" -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Presiona Enter para cerrar"
