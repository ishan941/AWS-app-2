FROM node:20-alpine As base

FROM base As deps
WORKDIR /app

COPY package*.json ./ 
COPY packages/shared/package*.json ./packages/shared/
COPY apps/backend/package*.json ./apps/backend/
RUN npm ci --only=production && npm cache clean --force
FROM base AS builder
WORKDIR /app

# Copy package files and install all dependencies
COPY package*.json ./
COPY packages/shared/package*.json ./packages/shared/
COPY apps/backend/package*.json ./apps/backend/
RUN npm ci

# Copy source code
COPY . .

# Build shared package first
RUN npm run build:shared

# Build backend
RUN npm run build:backend
FROM base AS runner
WORKDIR /app

# Create non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nodejs

# Copy built application
COPY --from=builder --chown=nodejs:nodejs /app/apps/backend/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/packages/shared/dist ./packages/shared/dist
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

USER nodejs

EXPOSE 3001

ENV NODE_ENV=production

CMD ["node", "dist/main.js"]