# Build Stage
FROM node:22 AS builder

WORKDIR /app

# Install git
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# Clone Notesnook monorepo (official)
RUN git clone --depth=1 https://github.com/streetwriters/notesnook.git .

# Install dependencies
RUN npm ci

# Build-time arguments for server URLs
ARG NN_API_HOST=http://localhost:5264
ARG NN_AUTH_HOST=http://localhost:8264
ARG NN_SSE_HOST=http://localhost:7264
ARG NN_MONOGRAPH_HOST=http://localhost:6264

# Patch db.ts to use our self-hosted URLs instead of Notesnook.com
RUN sed -i "s|API_HOST: \"https://api.notesnook.com\"|API_HOST: \"${NN_API_HOST}\"|g" apps/web/src/common/db.ts && \
    sed -i "s|AUTH_HOST: \"https://auth.streetwriters.co\"|AUTH_HOST: \"${NN_AUTH_HOST}\"|g" apps/web/src/common/db.ts && \
    sed -i "s|SSE_HOST: \"https://events.streetwriters.co\"|SSE_HOST: \"${NN_SSE_HOST}\"|g" apps/web/src/common/db.ts && \
    sed -i "s|MONOGRAPH_HOST: \"https://monogr.ph\"|MONOGRAPH_HOST: \"${NN_MONOGRAPH_HOST}\"|g" apps/web/src/common/db.ts

# Verify the patch was applied
RUN grep -A 8 "db.host" apps/web/src/common/db.ts

# Build the web app
RUN npm run build:web

# Production Stage
FROM nginx:alpine

# Remove default nginx site
RUN rm -rf /usr/share/nginx/html/*

# Copy build output
COPY --from=builder /app/apps/web/build /usr/share/nginx/html

# Custom nginx config for SPA
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
