FROM node:18-bookworm AS base

# Install netcat for database connectivity checks
RUN apt-get update && apt-get install -y netcat-traditional && rm -rf /var/lib/apt/lists/*

# Dependencies layer
FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --only=production

# Generate Prisma client after installing node_modules
COPY prisma ./prisma/

RUN npx prisma generate

# Builder layer
FROM base AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci

COPY . .
COPY prisma ./prisma/

# Production runner
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEW_RELIC_NO_CONFIG_FILE=true
ENV NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true
ENV NEW_RELIC_LOG=stdout

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 authservice

COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

COPY --from=deps --chown=authservice:nodejs /app/node_modules ./node_modules
COPY --from=deps --chown=authservice:nodejs /app/prisma ./prisma
COPY --from=builder --chown=authservice:nodejs /app/src ./src
COPY --from=builder --chown=authservice:nodejs /app/package.json ./package.json

USER authservice

EXPOSE 5439
ENV PORT=5439

CMD ["./entrypoint.sh"]
