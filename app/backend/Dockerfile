# build
FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

# shared runtime
FROM node:24-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app

# RDS CA bundle so the app can verify the database's TLS certificate
ADD --chmod=644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /app/certs/rds-ca.pem

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
USER node

# api image
FROM runtime AS api
EXPOSE 3000
CMD ["node", "dist/api.js"]

# worker image
FROM runtime AS worker
CMD ["node", "dist/worker.js"]