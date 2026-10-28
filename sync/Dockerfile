FROM node:26.10.0-slim

ARG PNPM_VERSION=12.16.1
RUN npm install -g pnpm@${PNPM_VERSION}

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prod

COPY src/ src/

USER node

CMD ["node", "src/sync.ts"]
