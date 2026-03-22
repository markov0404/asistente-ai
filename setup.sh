#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════
#  Asistente AI — Wizard de Instalacion Interactivo
#  Configura y levanta tu asistente personal en Docker/WSL2
# ═══════════════════════════════════════════════════════════════════

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$REPO_DIR/.env"
CONFIG_FILE="$HOME/.openclaw/openclaw.json"
TEMPLATE="$REPO_DIR/config/openclaw.json.template"
MEMORY_TEMPLATE="$REPO_DIR/workspace/MEMORY.md"
MEMORY_FILE="$HOME/.openclaw/workspace/MEMORY.md"

ok()    { echo -e "  ${GREEN}✔${NC} $1"; }
warn()  { echo -e "  ${YELLOW}!${NC} $1"; }
fail()  { echo -e "  ${RED}✘${NC} $1"; exit 1; }
banner() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}
ask() {
    local prompt="$1" var="$2" default="${3:-}"
    if [ -n "$default" ]; then
        echo -ne "  ${BOLD}$prompt${NC} ${DIM}[$default]${NC}: "
        read -r input
        eval "$var=\"${input:-$default}\""
    else
        echo -ne "  ${BOLD}$prompt${NC}: "
        read -r input
        eval "$var=\"$input\""
    fi
}
ask_secret() {
    local prompt="$1" var="$2"
    echo -ne "  ${BOLD}$prompt${NC}: "
    read -rs input
    echo ""
    eval "$var=\"$input\""
}
confirm() {
    echo -ne "  ${BOLD}$1${NC} ${DIM}[S/n]${NC}: "
    read -r yn
    case "$yn" in [nN]*) return 1 ;; *) return 0 ;; esac
}
pause() {
    echo ""
    echo -ne "  ${DIM}Presiona Enter para continuar...${NC}"
    read -r
}

# ═══════════════════════════════════════════════════════════════════
clear
echo ""
echo -e "${BOLD}  ╔═══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}  ║         🤖 Asistente AI — Setup           ║${NC}"
echo -e "${BOLD}  ║   Tu asistente personal con IA local      ║${NC}"
echo -e "${BOLD}  ╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Este wizard te guia paso a paso para configurar tu"
echo -e "  asistente. Vamos a necesitar configurar:"
echo ""
echo -e "  ${CYAN}1.${NC} Tu perfil (nombre, profesion)"
echo -e "  ${CYAN}2.${NC} Claude (tu cerebro de IA)"
echo -e "  ${CYAN}3.${NC} WhatsApp (canal principal)"
echo -e "  ${CYAN}4.${NC} Herramientas (email, GitHub, busqueda web, calendario)"
echo -e "  ${CYAN}5.${NC} Build y arranque"
echo ""
pause

# ═══════════════════════════════════════════════════════════════════
#  STEP 0: Prerequisites
# ═══════════════════════════════════════════════════════════════════
banner "Verificando prerequisitos"

command -v docker >/dev/null 2>&1 || fail "Docker no encontrado. Instala Docker Desktop o Docker Engine primero."
ok "Docker $(docker --version | grep -oP '\d+\.\d+\.\d+')"

if docker compose version >/dev/null 2>&1; then
    ok "Docker Compose $(docker compose version --short 2>/dev/null || echo 'v2')"
else
    warn "Docker Compose v2 no encontrado. Instalando..."
    mkdir -p ~/.docker/cli-plugins
    curl -sSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
        -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
    ok "Docker Compose instalado"
fi

mkdir -p ~/.openclaw/{workspace,credentials,identity,agents/main/{agent,sessions}}
mkdir -p ~/.config/himalaya
ok "Directorios creados"

# ═══════════════════════════════════════════════════════════════════
#  STEP 1: Perfil del usuario
# ═══════════════════════════════════════════════════════════════════
banner "1/5 — Tu perfil"
echo ""
echo -e "  Para darte la mejor asistencia, necesito conocerte."
echo ""

ask "Tu nombre" USER_NAME
ask "Tu profesion (ej: ingeniero, abogado, medico)" USER_PROFESSION
ask "Tu zona horaria" USER_TZ "America/Montevideo"
ask "Idioma principal" USER_LANG "es"

ok "Perfil: $USER_NAME, $USER_PROFESSION"

# ═══════════════════════════════════════════════════════════════════
#  STEP 2: Claude (cerebro de IA)
# ═══════════════════════════════════════════════════════════════════
banner "2/5 — Configurar Claude (cerebro de IA)"
echo ""
echo -e "  Claude es el modelo de IA que usa tu asistente para pensar."
echo -e "  Necesitas una forma de conectarte. Elige una opcion:"
echo ""
echo -e "  ${CYAN}1.${NC} Claude via sesion web ${DIM}(usa tu cuenta Pro/Team existente, gratis)${NC}"
echo -e "  ${CYAN}2.${NC} Claude via API key ${DIM}(de pago por uso, mas estable)${NC}"
echo -e "  ${CYAN}3.${NC} Saltar ${DIM}(configurar despues)${NC}"
echo ""
echo -ne "  ${BOLD}Opcion${NC} ${DIM}[1]${NC}: "
read -r CLAUDE_CHOICE
CLAUDE_CHOICE="${CLAUDE_CHOICE:-1}"

CLAUDE_SESSION_KEY=""
ANTHROPIC_API_KEY=""

case "$CLAUDE_CHOICE" in
    1)
        echo ""
        echo -e "  ${BOLD}Como obtener tu Session Key:${NC}"
        echo ""
        echo -e "  1. Abre ${CYAN}https://claude.ai${NC} en tu navegador e inicia sesion"
        echo -e "  2. Presiona ${BOLD}F12${NC} para abrir DevTools"
        echo -e "  3. Ve a la pestana ${BOLD}Application${NC} (o ${BOLD}Almacenamiento${NC})"
        echo -e "  4. En el panel izquierdo: ${BOLD}Cookies → https://claude.ai${NC}"
        echo -e "  5. Busca la cookie llamada ${BOLD}sessionKey${NC}"
        echo -e "  6. Copia el valor completo (empieza con ${DIM}sk-ant-sid01-...${NC})"
        echo ""
        ask_secret "Pega tu Session Key aqui" CLAUDE_SESSION_KEY
        if [ -n "$CLAUDE_SESSION_KEY" ]; then
            ok "Session Key guardada"
        else
            warn "Vacio. Podras configurarlo despues en .env"
        fi
        ;;
    2)
        echo ""
        echo -e "  Obtene tu API key en ${CYAN}https://console.anthropic.com/settings/keys${NC}"
        echo ""
        ask_secret "Tu Anthropic API Key (sk-ant-...)" ANTHROPIC_API_KEY
        if [ -n "$ANTHROPIC_API_KEY" ]; then
            ok "API Key guardada"
        else
            warn "Vacio. Podras configurarlo despues en .env"
        fi
        ;;
    *)
        warn "Claude se configurara despues. Edita .env cuando estes listo."
        ;;
esac

# ═══════════════════════════════════════════════════════════════════
#  STEP 3: WhatsApp
# ═══════════════════════════════════════════════════════════════════
banner "3/5 — Configurar WhatsApp"
echo ""
echo -e "  WhatsApp es tu canal principal para hablar con el asistente."
echo -e "  Necesitamos tu numero para la allowlist de seguridad."
echo ""
ask "Tu numero de WhatsApp con codigo de pais (ej: +59899123456)" WA_NUMBER "+598"

ok "WhatsApp configurado para $WA_NUMBER"
echo ""
echo -e "  ${DIM}El escaneo QR se hara al final, cuando el gateway este corriendo.${NC}"

# ═══════════════════════════════════════════════════════════════════
#  STEP 4: Herramientas
# ═══════════════════════════════════════════════════════════════════
banner "4/5 — Herramientas adicionales"
echo ""
echo -e "  Configura las herramientas que quieras. Podes agregar mas despues."
echo ""

# — Brave Search —
BRAVE_KEY=""
if confirm "Activar busqueda web (Brave Search)?"; then
    echo ""
    echo -e "  Obtene tu API key gratis en ${CYAN}https://api.search.brave.com/${NC}"
    echo ""
    ask_secret "Brave API Key" BRAVE_KEY
    [ -n "$BRAVE_KEY" ] && ok "Brave Search configurado" || warn "Sin key. Se configura despues."
else
    echo -e "  ${DIM}Busqueda web desactivada. Podes activarla despues.${NC}"
fi

# — GitHub —
GH_KEY=""
if confirm "Activar GitHub (gestionar repos, issues, PRs)?"; then
    echo ""
    echo -e "  Opciones para autenticarte:"
    echo -e "  ${CYAN}a.${NC} Token personal ${DIM}(https://github.com/settings/tokens)${NC}"
    echo -e "  ${CYAN}b.${NC} Configurar despues con 'gh auth login' dentro del container"
    echo ""
    echo -ne "  ${BOLD}Opcion${NC} ${DIM}[a]${NC}: "
    read -r GH_CHOICE
    GH_CHOICE="${GH_CHOICE:-a}"
    if [ "$GH_CHOICE" = "a" ]; then
        ask_secret "GitHub Token (ghp_... o github_pat_...)" GH_KEY
        [ -n "$GH_KEY" ] && ok "GitHub configurado" || warn "Sin token. Se configura despues."
    else
        warn "Configura GitHub despues: docker compose exec openclaw-gateway gh auth login"
    fi
else
    echo -e "  ${DIM}GitHub desactivado. Podes activarlo despues.${NC}"
fi

# — Email —
SETUP_EMAIL="n"
if confirm "Activar email (Gmail / Outlook)?"; then
    SETUP_EMAIL="y"
    echo ""
    echo -e "  ${DIM}El email se configura despues del build con himalaya CLI.${NC}"
    echo -e "  ${DIM}Te mostrare los pasos al final del setup.${NC}"
    ok "Email marcado para configuracion post-build"
else
    echo -e "  ${DIM}Email desactivado. Podes activarlo despues.${NC}"
fi

# — Calendar —
SETUP_CALENDAR="n"
if confirm "Activar Google Calendar?"; then
    SETUP_CALENDAR="y"
    echo ""
    echo -e "  ${DIM}Calendar requiere OAuth de Google. Se configura post-build.${NC}"
    ok "Calendar marcado para configuracion post-build"
else
    echo -e "  ${DIM}Calendar desactivado. Podes activarlo despues.${NC}"
fi

# ═══════════════════════════════════════════════════════════════════
#  Generate config files
# ═══════════════════════════════════════════════════════════════════
banner "Generando archivos de configuracion"

# — .env —
GATEWAY_TOKEN=$(openssl rand -hex 32)
cat > "$ENV_FILE" <<EOF
# Asistente AI - Variables de entorno (NO commitear)
# Generado: $(date +%Y-%m-%d)

OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
OPENCLAW_CONFIG_DIR=${HOME}/.openclaw
OPENCLAW_WORKSPACE_DIR=${HOME}/.openclaw/workspace
OPENCLAW_TZ=${USER_TZ}

# Claude
CLAUDE_AI_SESSION_KEY=${CLAUDE_SESSION_KEY}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}

# Herramientas
BRAVE_API_KEY=${BRAVE_KEY}
GH_TOKEN=${GH_KEY}
EOF
ok ".env creado"

# — openclaw.json —
if [ -f "$TEMPLATE" ]; then
    sed -e "s/+52XXXXXXXXXX/${WA_NUMBER}/g" \
        -e "s/America\/Mexico_City/${USER_TZ//\//\\/}/g" \
        "$TEMPLATE" > "$CONFIG_FILE"
    ok "openclaw.json creado con numero $WA_NUMBER"
else
    warn "Template no encontrado, se creara durante onboard"
fi

# — MEMORY.md —
cat > "$MEMORY_FILE" <<EOF
# Asistente AI - Memoria Persistente

## Usuario
- Nombre: ${USER_NAME}
- Profesion: ${USER_PROFESSION}
- Idioma preferido: ${USER_LANG}
- Zona horaria: ${USER_TZ}
- Pais: Uruguay (+598)

## Herramientas Disponibles
- WhatsApp: canal principal de comunicacion (numero: ${WA_NUMBER})
- Busqueda web: $([ -n "$BRAVE_KEY" ] && echo "Brave Search API (activo)" || echo "Brave Search (pendiente de configurar)")
- GitHub: $([ -n "$GH_KEY" ] && echo "gh CLI (activo)" || echo "gh CLI (pendiente de configurar)")
- Email: $([ "$SETUP_EMAIL" = "y" ] && echo "Gmail + Outlook via himalaya (pendiente de configurar)" || echo "No configurado")
- Calendar: $([ "$SETUP_CALENDAR" = "y" ] && echo "Google Calendar via gog (pendiente de configurar)" || echo "No configurado")
- Memoria: este archivo (largo plazo) + memory/YYYY-MM-DD.md (logs diarios)
- ClawHub: buscar e instalar nuevas herramientas bajo demanda

## Preferencias Aprendidas
(se llena automaticamente con el uso)

## Proyectos Activos
(se llena automaticamente con el uso)

## Contactos Frecuentes
(se llena automaticamente con el uso)
EOF
ok "MEMORY.md creado con tu perfil"

# — SOUL.md (reglas inmutables) —
SOUL_TEMPLATE="$REPO_DIR/workspace/SOUL.md"
SOUL_FILE="$HOME/.openclaw/workspace/SOUL.md"
if [ -f "$SOUL_TEMPLATE" ]; then
    cp "$SOUL_TEMPLATE" "$SOUL_FILE"
    ok "SOUL.md creado (reglas inmutables del asistente)"
fi

# ═══════════════════════════════════════════════════════════════════
#  STEP 5: Build & Start
# ═══════════════════════════════════════════════════════════════════
banner "5/5 — Construyendo y levantando el asistente"
echo ""
echo -e "  Esto puede tardar varios minutos la primera vez."
echo -e "  Se descargan dependencias y se compila el proyecto."
echo ""

if confirm "Iniciar el build ahora?"; then
    echo ""
    echo -e "  ${DIM}Construyendo imagen base...${NC}"
    DOCKER_BUILDKIT=1 docker build -t openclaw:local \
        --build-arg OPENCLAW_EXTENSIONS="whatsapp brave memory-core" \
        --build-arg OPENCLAW_DOCKER_APT_PACKAGES="git curl jq" \
        -f "$REPO_DIR/Dockerfile" "$REPO_DIR"
    ok "Imagen base construida"

    echo ""
    echo -e "  ${DIM}Construyendo imagen con herramientas CLI...${NC}"
    DOCKER_BUILDKIT=1 docker build -t openclaw:custom \
        -f "$REPO_DIR/Dockerfile.custom" "$REPO_DIR"
    ok "Imagen custom construida"

    # Source env and start
    set -a; source "$ENV_FILE"; set +a
    cd "$REPO_DIR"
    docker compose up -d openclaw-gateway
    ok "Gateway iniciado"

    # Health check
    echo -ne "  Esperando que arranque"
    HEALTHY=false
    for i in $(seq 1 20); do
        if curl -fsS http://127.0.0.1:18789/healthz >/dev/null 2>&1; then
            echo ""
            ok "Gateway saludable"
            HEALTHY=true
            break
        fi
        echo -n "."
        sleep 2
    done
    if [ "$HEALTHY" = false ]; then
        echo ""
        warn "Gateway no responde. Verifica: docker compose logs openclaw-gateway"
    fi

    # WhatsApp QR login
    echo ""
    if confirm "Conectar WhatsApp ahora? (necesitas tu telefono a mano)"; then
        echo ""
        echo -e "  ${BOLD}Instrucciones:${NC}"
        echo -e "  1. Abre WhatsApp en tu telefono"
        echo -e "  2. Ve a ${BOLD}Configuracion → Dispositivos enlazados → Enlazar dispositivo${NC}"
        echo -e "  3. Escanea el codigo QR que aparecera a continuacion"
        echo ""
        pause
        docker compose run --rm openclaw-cli channels login --channel whatsapp
        ok "WhatsApp conectado!"
    else
        echo ""
        echo -e "  ${DIM}Para conectar WhatsApp despues:${NC}"
        echo -e "  ${BOLD}cd $REPO_DIR && docker compose run --rm openclaw-cli channels login --channel whatsapp${NC}"
    fi
else
    echo ""
    echo -e "  Para construir y levantar despues:"
    echo -e "  ${BOLD}cd $REPO_DIR && ./setup.sh${NC}"
    echo -e "  O manualmente:"
    echo -e "  ${BOLD}docker build -t openclaw:local --build-arg OPENCLAW_EXTENSIONS=\"whatsapp brave memory-core\" -f Dockerfile .${NC}"
    echo -e "  ${BOLD}docker build -t openclaw:custom -f Dockerfile.custom .${NC}"
    echo -e "  ${BOLD}docker compose up -d openclaw-gateway${NC}"
fi

# ═══════════════════════════════════════════════════════════════════
#  Post-setup instructions
# ═══════════════════════════════════════════════════════════════════
banner "Setup completo!"
echo ""
echo -e "  ${GREEN}Tu asistente esta listo.${NC} Enviale un mensaje por WhatsApp!"
echo ""
echo -e "  ${BOLD}Panel de control:${NC}  http://127.0.0.1:18789/"
echo -e "  ${BOLD}Token de acceso:${NC}   ${DIM}${GATEWAY_TOKEN:0:12}...${NC}"
echo -e "  ${BOLD}Ver logs:${NC}          docker compose logs -f openclaw-gateway"
echo -e "  ${BOLD}Reiniciar:${NC}         docker compose restart openclaw-gateway"
echo -e "  ${BOLD}Detener:${NC}           docker compose down"

# Post-setup: email instructions
if [ "$SETUP_EMAIL" = "y" ]; then
    echo ""
    echo -e "  ${CYAN}━━ Configurar Email ━━${NC}"
    echo ""
    echo -e "  ${BOLD}Gmail:${NC}"
    echo -e "  1. Activa acceso por App Password: ${CYAN}https://myaccount.google.com/apppasswords${NC}"
    echo -e "  2. Edita ${BOLD}~/.config/himalaya/config.toml${NC}:"
    echo -e "     ${DIM}[accounts.gmail]"
    echo -e "     email = \"tu@gmail.com\""
    echo -e "     backend.type = \"imap\""
    echo -e "     backend.host = \"imap.gmail.com\""
    echo -e "     backend.port = 993"
    echo -e "     backend.encryption.type = \"tls\""
    echo -e "     backend.login = \"tu@gmail.com\""
    echo -e "     backend.auth.type = \"password\""
    echo -e "     backend.auth.raw = \"tu-app-password\"${NC}"
    echo ""
    echo -e "  ${BOLD}Outlook:${NC}"
    echo -e "  Igual pero con host ${BOLD}outlook.office365.com${NC} y puerto ${BOLD}993${NC}"
fi

if [ "$SETUP_CALENDAR" = "y" ]; then
    echo ""
    echo -e "  ${CYAN}━━ Configurar Google Calendar ━━${NC}"
    echo ""
    echo -e "  1. Crea credenciales OAuth en ${CYAN}https://console.cloud.google.com/apis/credentials${NC}"
    echo -e "  2. Dentro del container: ${BOLD}docker compose exec openclaw-gateway gog auth add tu@gmail.com --services calendar${NC}"
fi

echo ""
echo -e "  ${DIM}Todos los archivos de config estan en ~/.openclaw/${NC}"
echo -e "  ${DIM}Memoria del asistente en ~/.openclaw/workspace/MEMORY.md${NC}"
echo ""
