# Notesnook Self-Hosted

Configuración Docker para self-hosting de Notesnook.

> La app web se compila desde el [repo oficial](https://github.com/streetwriters/notesnook) con `SELF_HOSTED=true` para desactivar los prompts de "Upgrade to PRO".

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

## Configuración Local

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

Configurar Nginx/Traefik/Caddy para:
- SSL/TLS (HTTPS)
- Proxy a los puertos internos

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

## Actualización

```bash
./update.sh
```

Este script:
1. Descarga las últimas imágenes oficiales de backend (`streetwriters/*`)
2. Recompila la web app desde el [repo oficial](https://github.com/streetwriters/notesnook) (sin caché)
3. Reinicia todos los servicios

### Actualización manual

```bash
# Solo backends (rápido)
docker compose pull && docker compose up -d

# Solo web app (lento, recompila)
docker compose build --no-cache notesnook-web && docker compose up -d notesnook-web
```

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

## Comandos Útiles

```bash
# Iniciar
docker compose up -d

# Ver logs
docker compose logs -f

# Parar
docker compose down

# Parar y eliminar datos
docker compose down -v

# Reiniciar un servicio
docker compose restart notesnook-web

# Ver estado
docker compose ps
```

## Fork de BeardedTek

Existe un [fork de BeardedTek](https://github.com/beardedtek/notesnook) que modifica cómo la web app lee las URLs de los servidores.

### ¿Qué cambia?

El repo oficial compila las URLs **en tiempo de build** (se "queman" en el código):
```dockerfile
ARG API_HOST=http://localhost:5264
ENV NN_API_HOST=${API_HOST}
RUN npm run build:web  # Las URLs quedan fijas en el bundle
```

El fork de BeardedTek modifica `apps/web/src/common/db.ts` para leer las URLs **en runtime** desde variables de entorno con prefijo `NN_`:
```javascript
// Busca: 1) env NN_API_HOST, 2) config usuario, 3) valor por defecto
const API_HOST = getServerUrl("API_HOST", "https://api.notesnook.com");
```

### ¿Por qué no lo usamos?

Nuestro `app/Dockerfile` ya pasa las URLs como argumentos de build:
```dockerfile
ARG API_HOST
ENV NN_API_HOST=${API_HOST}
RUN npm run build:web
```

Esto funciona porque:
- Tenemos **una sola instancia** (self-hosted personal)
- Las URLs se definen en `.env` y se pasan al build
- Si cambian las URLs, simplemente recompilamos

### ¿Cuándo sí usarlo?

El fork de BeardedTek sería útil si:
- Quisieras **una imagen para múltiples entornos** (dev, staging, prod)
- Necesitaras cambiar URLs **sin recompilar**
- Distribuyeras la imagen a terceros

Para self-hosting típico, el repo oficial + nuestro Dockerfile es suficiente.

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
