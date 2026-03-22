# Asistente AI

Asistente personal de IA que corre localmente en Docker/WSL2. Basado en [OpenClaw](https://github.com/openclaw/openclaw).

Te responde por WhatsApp, lee tus correos, busca en internet, gestiona tu GitHub y calendario. Usa Claude como cerebro.

## Instalacion

### Prerequisitos

- Windows con WSL2 (o Linux)
- Docker instalado

### Un solo comando

```bash
git clone https://github.com/markov0404/asistente-ai.git
cd asistente-ai
./setup.sh
```

El wizard interactivo te guia paso a paso:

```
╔═══════════════════════════════════════════╗
║         Asistente AI — Setup              ║
║   Tu asistente personal con IA local      ║
╚═══════════════════════════════════════════╝

1/5 — Tu perfil
  Tu nombre: Dani
  Tu profesion: ingeniero

2/5 — Configurar Claude
  [1] Claude via sesion web (usa tu cuenta Pro)
  [2] Claude via API key

3/5 — Configurar WhatsApp
  Tu numero: +59899123456

4/5 — Herramientas
  Activar busqueda web? [S/n]
  Activar GitHub? [S/n]
  Activar email? [S/n]
  Activar calendario? [S/n]

5/5 — Build y arranque
  Construyendo... OK
  Escanea el QR de WhatsApp...
```

## Que puede hacer

- **WhatsApp**: recibe y responde mensajes, lee adjuntos (fotos, PDFs, docs)
- **Email**: lee y responde correos de Gmail y Outlook
- **Busqueda web**: investiga temas en internet
- **GitHub**: gestiona repos, issues, PRs
- **Google Calendar**: consulta y crea eventos
- **Memoria**: recuerda tu contexto y conversaciones previas
- **Extensible**: puede instalar nuevas herramientas bajo demanda

## Reglas del asistente (inmutables)

Estas reglas estan en el system prompt y el asistente no puede modificarlas:

1. Pregunta antes de ejecutar cualquier accion
2. No asume — pregunta e investiga primero
3. Se adapta a tu profesion
4. Muestra borradores antes de enviar emails/mensajes
5. Confirma acciones destructivas
6. Protege tu privacidad

## Uso diario

Enviale un mensaje de WhatsApp:

- "Que correos tengo hoy?"
- "Resume mi agenda de esta semana"
- "Busca informacion sobre X"
- "Que issues tengo abiertos en GitHub?"
- "Respondele a Juan que si puedo el jueves" (muestra borrador primero)

## Comandos utiles

```bash
# Ver logs
docker compose logs -f openclaw-gateway

# Reiniciar
docker compose restart openclaw-gateway

# Detener
docker compose down

# Reconectar WhatsApp
docker compose run --rm openclaw-cli channels login --channel whatsapp

# Panel de control web
# http://127.0.0.1:18789/
```

## Archivos importantes

```
~/.openclaw/
  openclaw.json          # Config (reglas inmutables del asistente)
  workspace/MEMORY.md    # Memoria editable del asistente
  workspace/memory/      # Logs diarios automaticos
  credentials/whatsapp/  # Sesion de WhatsApp
```
