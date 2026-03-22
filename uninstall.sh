#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════
#  Asistente AI — Desinstalador
# ═══════════════════════════════════════════════════════════════════

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
fail() { echo -e "  ${RED}✘${NC} $1"; }

confirm_destructive() {
    echo -ne "  ${RED}$1${NC} ${DIM}[s/N]${NC}: "
    read -r yn
    case "$yn" in [sS]*) return 0 ;; *) return 1 ;; esac
}

clear
echo ""
echo -e "${BOLD}  ╔═══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}  ║       Asistente AI — Desinstalar          ║${NC}"
echo -e "${BOLD}  ╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Que queres hacer?"
echo ""
echo -e "  ${CYAN}1.${NC} Solo detener ${DIM}— pausa el asistente, no borra nada${NC}"
echo -e "  ${CYAN}2.${NC} Desinstalar liviano ${DIM}— borra containers e imagenes Docker${NC}"
echo -e "     ${DIM}Conserva: config, memoria, sesion WhatsApp, credenciales${NC}"
echo -e "  ${CYAN}3.${NC} Desinstalar todo ${DIM}— borra absolutamente todo${NC}"
echo -e "  ${CYAN}4.${NC} Cancelar"
echo ""
echo -ne "  ${BOLD}Opcion${NC}: "
read -r CHOICE

case "$CHOICE" in
    # ── Option 1: Stop only ──────────────────────────────────────
    1)
        echo ""
        echo -e "  ${BOLD}Deteniendo el asistente...${NC}"
        cd "$REPO_DIR" 2>/dev/null && docker compose down 2>/dev/null && ok "Containers detenidos" || warn "No habia containers corriendo"
        echo ""
        echo -e "  El asistente esta pausado. Para volver a iniciarlo:"
        echo -e "  ${BOLD}cd $REPO_DIR && docker compose up -d openclaw-gateway${NC}"
        ;;

    # ── Option 2: Uninstall but keep data ────────────────────────
    2)
        echo ""
        echo -e "  ${BOLD}Esto va a:${NC}"
        echo -e "  ${RED}✘${NC} Detener y borrar containers Docker"
        echo -e "  ${RED}✘${NC} Borrar imagenes Docker (openclaw:local, openclaw:custom) (~4GB)"
        echo -e "  ${GREEN}✔${NC} Conservar tu config (~/.openclaw/openclaw.json)"
        echo -e "  ${GREEN}✔${NC} Conservar tu memoria (~/.openclaw/workspace/)"
        echo -e "  ${GREEN}✔${NC} Conservar tu sesion de WhatsApp"
        echo -e "  ${GREEN}✔${NC} Conservar credenciales de email"
        echo ""

        if confirm_destructive "Continuar con la desinstalacion liviana?"; then
            echo ""
            # Stop containers
            cd "$REPO_DIR" 2>/dev/null && docker compose down 2>/dev/null && ok "Containers detenidos" || warn "No habia containers"

            # Remove images
            docker rmi openclaw:custom 2>/dev/null && ok "Imagen openclaw:custom eliminada" || warn "Imagen custom no encontrada"
            docker rmi openclaw:local 2>/dev/null && ok "Imagen openclaw:local eliminada" || warn "Imagen local no encontrada"

            # Remove dangling images from build
            DANGLING=$(docker images -f "dangling=true" -q 2>/dev/null)
            if [ -n "$DANGLING" ]; then
                docker rmi $DANGLING 2>/dev/null && ok "Imagenes huerfanas limpiadas" || true
            fi

            # Remove network
            docker network rm asistente-ai_default 2>/dev/null && ok "Red Docker eliminada" || true

            echo ""
            echo -e "  ${GREEN}Desinstalacion liviana completa.${NC}"
            echo ""
            echo -e "  Tus datos siguen en:"
            echo -e "  ${DIM}~/.openclaw/${NC}          Config, memoria, credenciales"
            echo -e "  ${DIM}~/.config/himalaya/${NC}   Config de email"
            echo -e "  ${DIM}$REPO_DIR/${NC}  Codigo fuente"
            echo ""
            echo -e "  Para reinstalar: ${BOLD}cd $REPO_DIR && ./setup.sh${NC}"
        else
            echo -e "  ${DIM}Cancelado.${NC}"
        fi
        ;;

    # ── Option 3: Full uninstall ─────────────────────────────────
    3)
        echo ""
        echo -e "  ${RED}${BOLD}ATENCION: Esto borra TODO permanentemente:${NC}"
        echo -e "  ${RED}✘${NC} Containers e imagenes Docker (~4GB)"
        echo -e "  ${RED}✘${NC} Config del asistente (~/.openclaw/openclaw.json)"
        echo -e "  ${RED}✘${NC} Toda la memoria del asistente (~/.openclaw/workspace/)"
        echo -e "  ${RED}✘${NC} Sesion de WhatsApp (tendras que escanear QR de nuevo)"
        echo -e "  ${RED}✘${NC} Credenciales de email (~/.config/himalaya/)"
        echo -e "  ${RED}✘${NC} Codigo fuente ($REPO_DIR/)"
        echo ""

        if confirm_destructive "BORRAR TODO permanentemente?"; then
            echo ""
            echo -ne "  ${RED}Escribe 'BORRAR' para confirmar${NC}: "
            read -r CONFIRM
            if [ "$CONFIRM" != "BORRAR" ]; then
                echo -e "  ${DIM}Cancelado.${NC}"
                exit 0
            fi

            echo ""
            # Stop containers
            cd "$REPO_DIR" 2>/dev/null && docker compose down 2>/dev/null && ok "Containers detenidos" || warn "No habia containers"

            # Remove images
            docker rmi openclaw:custom 2>/dev/null && ok "Imagen openclaw:custom eliminada" || true
            docker rmi openclaw:local 2>/dev/null && ok "Imagen openclaw:local eliminada" || true
            DANGLING=$(docker images -f "dangling=true" -q 2>/dev/null)
            [ -n "$DANGLING" ] && docker rmi $DANGLING 2>/dev/null || true
            docker network rm asistente-ai_default 2>/dev/null || true
            ok "Docker limpiado"

            # Remove config and data
            rm -rf ~/.openclaw && ok "~/.openclaw/ eliminado"
            rm -rf ~/.config/himalaya && ok "~/.config/himalaya/ eliminado"

            # Remove repo (we are inside it, so cd out first)
            REPO_TO_DELETE="$REPO_DIR"
            cd ~ || cd /tmp
            rm -rf "$REPO_TO_DELETE" && ok "$REPO_TO_DELETE/ eliminado"

            echo ""
            echo -e "  ${GREEN}Desinstalacion completa.${NC} Todo fue eliminado."
            echo -e "  ${DIM}Para reinstalar: git clone https://github.com/markov0404/asistente-ai.git && cd asistente-ai && ./setup.sh${NC}"
        else
            echo -e "  ${DIM}Cancelado.${NC}"
        fi
        ;;

    *)
        echo -e "  ${DIM}Cancelado.${NC}"
        ;;
esac

echo ""
