# Notesnook Self-Hosted - Contexto para Claude

## Reglas

- **Documentar explicaciones**: Cuando el usuario pregunte algo y la respuesta sea una explicación de cómo funciona Notesnook (sync, encriptación, backups, etc.), añadir esa información al `README.md`. El README debe servir como manual de usuario y resolución de dudas.
- **Sin Co-Authored-By**: Nunca incluir la línea "Co-Authored-By: Claude" en los mensajes de commit.

## Estructura del proyecto

```
notesnook/
├── app/
│   └── Dockerfile       # Build de la web app desde source
├── docker-compose.yml   # Orquestación de todos los servicios
├── update.sh            # Script de actualización
├── .env                 # Variables de entorno (no commitear)
└── .env.example         # Plantilla de variables
```

## Servicios Docker

| Servicio | Imagen | Puerto |
|----------|--------|--------|
| notesnook-web | Build local (`app/Dockerfile`) | 3000 |
| notesnook-server | `streetwriters/notesnook-sync` | 5264 |
| identity-server | `streetwriters/identity` | 8264 |
| sse-server | `streetwriters/sse` | 7264 |
| monograph-server | `streetwriters/monograph` | 6264 |
| notesnook-s3 | `minio/minio` | 9000 |
| notesnook-db | `mongo:7.0.12` | 27017 |
| mailhog | `mailhog/mailhog` | 8025 |

## Compilación de la web app

La web app se compila desde el [repo oficial](https://github.com/streetwriters/notesnook) con:
- `SELF_HOSTED=true` → Desactiva prompts de "Upgrade to PRO"
- URLs pasadas como ARGs de build → Se "queman" en el bundle JS

```dockerfile
ARG API_HOST
ENV NN_API_HOST=${API_HOST}
RUN npm run build:web
```

## Variables de entorno importantes

Ver `.env.example` para la lista completa. Las URLs (`API_HOST`, `AUTH_HOST`, etc.) se usan tanto en runtime (backends) como en build-time (web app).

## Volúmenes de datos

- `dbdata`: MongoDB
- `s3data`: MinIO (archivos adjuntos)

## Comandos frecuentes

```bash
# Desarrollo
docker compose up -d --build
docker compose logs -f

# Actualización completa
./update.sh

# Solo recompilar web
docker compose build --no-cache notesnook-web && docker compose up -d notesnook-web
```
