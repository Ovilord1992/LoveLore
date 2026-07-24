# ─── Stage 1: build (полные зависимости + prisma generate + tsc) ─────────────
FROM node:22-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npx prisma generate && npm run build

# ─── Stage 2: только prod-зависимости ────────────────────────────────────────
FROM node:22-alpine AS prod-deps
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts

# ─── Stage 3: runtime (non-root) ─────────────────────────────────────────────
FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app

COPY --from=prod-deps /app/node_modules ./node_modules
# Сгенерированный Prisma-клиент (с движками) — из build-стадии.
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=build /app/node_modules/@prisma/client ./node_modules/@prisma/client
COPY --from=build /app/dist ./dist
COPY prisma ./prisma
COPY package.json ./

RUN mkdir -p uploads/packs uploads/covers uploads/cache && chown -R node:node /app
USER node

EXPOSE 3000
CMD ["node", "dist/index.js"]
