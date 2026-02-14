# Notesnook Self-Hosted

Configuración Docker para self-hosting de Notesnook en tu Mac (local) con opción de migrar a VPS.

> La app web se compila desde el [repo oficial](https://github.com/streetwriters/notesnook) con `SELF_HOSTED=true` para desactivar los prompts de "Upgrade to PRO".

## Cómo funciona

Notesnook usa **encriptación end-to-end (E2EE)**:

- Tus notas se encriptan **en tu navegador** con una clave derivada de tu contraseña
- El servidor solo almacena datos encriptados (nunca ve el contenido)
- Los datos también se guardan localmente en el navegador (IndexedDB)

### Modo offline

Puedes usar la app **sin conexión al servidor**:
- Ver, crear y editar notas
- Los cambios se sincronizan cuando el servidor vuelva a estar online

### Sincronización

Mira la esquina inferior izquierda:
- **"Synced"** → Todo sincronizado
- **"Syncing..."** → Sincronizando
- **"X items pending"** → Hay cambios sin subir

Forzar sync: `Ctrl+Shift+S` (o `Cmd+Shift+S` en Mac)

### Logout

Al cerrar sesión, se borran los datos **locales del navegador** (por seguridad). Tus datos en el servidor permanecen intactos. Al volver a iniciar sesión, se descargan y desencriptan de nuevo.

---

## Servicios

| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| notesnook-web | 3000 | Aplicación web |
| notesnook-server | 5264 | API de sincronización |
| identity-server | 8264 | Autenticación |
| sse-server | 7264 | Eventos en tiempo real |
| monograph-server | 6264 | Notas públicas |
| notesnook-s3 | 9000 | MinIO (almacenamiento) |
| notesnook-db | 27017 | MongoDB (interno) |
| mailhog | 8025 | UI para emails de prueba |

---

## Uso Local (Mac)

### 1. Crear `.env`

```bash
cp .env.example .env
```

Contenido mínimo:

```bash
INSTANCE_NAME=mi-notesnook
NOTESNOOK_API_SECRET=clave-secreta-de-al-menos-32-caracteres
DISABLE_SIGNUPS=false

SMTP_HOST=mailhog
SMTP_PORT=1025
SMTP_USERNAME=test
SMTP_PASSWORD=test
```

### 2. Iniciar servicios

```bash
docker compose up -d --build
```

> El primer build de `notesnook-web` tarda varios minutos (compila desde el código fuente).

### 3. Acceder

- **App**: http://localhost:3000
- **MailHog**: http://localhost:8025 (ver emails de verificación)

### 4. Registro

1. Crear cuenta en http://localhost:3000
2. Te pedirá un código de 6 dígitos
3. Abrir http://localhost:8025 (MailHog)
4. El email con el código estará ahí

---

## Comandos del día a día

```bash
# Iniciar
docker compose up -d

# Parar
docker compose down

# Ver logs
docker compose logs -f

# Ver estado
docker compose ps

# Reiniciar un servicio
docker compose restart notesnook-web
```

---

## Actualización

```bash
./update.sh
```

Este script:
1. Descarga las últimas imágenes oficiales de backend
2. Recompila la web app desde el repo oficial (sin caché)
3. Reinicia todos los servicios

### Actualización manual

```bash
# Solo backends (rápido)
docker compose pull && docker compose up -d

# Solo web app (lento, recompila)
docker compose build --no-cache notesnook-web && docker compose up -d notesnook-web
```

---

## Backups

Los datos están en volúmenes Docker:
- `dbdata`: Base de datos MongoDB
- `s3data`: Archivos adjuntos (MinIO)

```bash
# Backup MongoDB
docker compose exec notesnook-db mongodump --archive=/data/db/backup.archive

# Copiar backup al host
docker cp $(docker compose ps -q notesnook-db):/data/db/backup.archive ./backup.archive
```

---

## Migración a VPS

### 1. Actualizar `.env`

Añadir las URLs públicas:

```bash
APP_HOST=https://notes.tudominio.com
API_HOST=https://api.tudominio.com
AUTH_HOST=https://auth.tudominio.com
SSE_HOST=https://sse.tudominio.com
MONOGRAPH_HOST=https://mono.tudominio.com
S3_HOST=https://s3.tudominio.com
```

### 2. Configurar SMTP real

```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=tu-email@gmail.com
SMTP_PASSWORD=tu-app-password
```

### 3. Reverse Proxy

Configurar Nginx/Traefik/Caddy para SSL y proxy a los puertos internos.

Ejemplo Caddy (`Caddyfile`):

```
notes.tudominio.com {
    reverse_proxy localhost:3000
}

api.tudominio.com {
    reverse_proxy localhost:5264
}

auth.tudominio.com {
    reverse_proxy localhost:8264
}

sse.tudominio.com {
    reverse_proxy localhost:7264
}

mono.tudominio.com {
    reverse_proxy localhost:6264
}

s3.tudominio.com {
    reverse_proxy localhost:9000
}
```

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                        IMÁGENES                             │
├─────────────────────────────────────────────────────────────┤
│  Backend (oficiales de Docker Hub)                          │
│  ├── streetwriters/notesnook-sync    → notesnook-server     │
│  ├── streetwriters/identity          → identity-server      │
│  ├── streetwriters/sse               → sse-server           │
│  ├── streetwriters/monograph         → monograph-server     │
│  ├── mongo:7.0.12                    → notesnook-db         │
│  └── minio/minio                     → notesnook-s3         │
├─────────────────────────────────────────────────────────────┤
│  Frontend (build local desde source)                        │
│  └── github.com/streetwriters/notesnook → notesnook-web     │
│      (compilado con SELF_HOSTED=true)                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Los servicios no inician
```bash
docker compose logs validate
```
Verifica que todas las variables requeridas estén en `.env`.

### No recibo emails
- Local: Revisa http://localhost:8025 (MailHog)
- VPS: Verifica credenciales SMTP

### Error de conexión entre servicios
```bash
docker compose down
docker compose up -d
```
Espera ~60s para que los healthchecks pasen.

---

## Notas técnicas

### ¿Por qué no usamos el fork de BeardedTek?

Existe un [fork](https://github.com/beardedtek/notesnook) que permite cambiar URLs en runtime (sin recompilar). No lo usamos porque:

- Tenemos **una sola instancia** (self-hosted personal)
- Las URLs se definen en `.env` y se pasan al build
- Si cambian las URLs, simplemente recompilamos con `./update.sh`

El fork sería útil si necesitaras una imagen para múltiples entornos o distribuirla a terceros.

### ¿Por qué se compila la web app localmente?

El repo oficial compila las URLs del servidor **en tiempo de build** (quedan "quemadas" en el código). Por eso `app/Dockerfile` pasa las URLs como argumentos:

```dockerfile
ARG API_HOST
ENV NN_API_HOST=${API_HOST}
RUN npm run build:web
```
