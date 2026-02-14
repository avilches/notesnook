# Build Stage
FROM node:20 AS builder

WORKDIR /app

# Install git
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# Clone Notesnook monorepo (official)
RUN git clone --depth=1 https://github.com/streetwriters/notesnook.git .

# Install dependencies
RUN npm ci

# Build-time arguments for server URLs
ARG API_HOST
ARG AUTH_HOST
ARG SSE_HOST
ARG MONOGRAPH_HOST
ARG SELF_HOSTED=true

# Set environment variables for build
ENV NN_API_HOST=${API_HOST}
ENV NN_AUTH_HOST=${AUTH_HOST}
ENV NN_SSE_HOST=${SSE_HOST}
ENV NN_MONOGRAPH_HOST=${MONOGRAPH_HOST}
ENV SELF_HOSTED=${SELF_HOSTED}

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
