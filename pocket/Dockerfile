# Build UI Environment
ARG UPSTREAM_VERSION

#<<<<<<< Devel-Bump-to-RC-12.0
FROM node:20-alpine as build-ui
#=======
#FROM node:18.20.3-alpine as build-ui
#FROM node:20.15.0-alpine AS build-ui
#>>>>>>> Voss/devel

WORKDIR /app

COPY ui /app/ui
# COPY ui/package.json ./
# COPY ui/yarn.lock ./

WORKDIR /app/ui

RUN yarn && yarn build
RUN npx update-browserslist-db@latest

#Starting with version BETA-0.10.2 of the v0 Pokt Core, the DockerHub package registry has been replaced by the Github Container Registry at ghcr.io/pokt-network/pocket-v0:latest.
FROM ghcr.io/pokt-network/pocket-v0:${UPSTREAM_VERSION}

WORKDIR /home/app/

USER root

# RUN apk add -u gettext curl jq nginx supervisor lz4 aria2
RUN apk update
RUN apk add -u gettext curl jq nodejs npm supervisor lz4 aria2
RUN mkdir -p /home/app/.pocket/config

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY chains/chains_mainnet.json /home/app/.pocket/config/chains.json
COPY genesis_mainnet.json /home/app/.pocket/config/genesis.json
COPY config_template.json /home/app/.pocket/config/config_template.json
COPY supervisord.conf /etc/supervisord/supervisord.conf
# COPY nginx.conf /etc/nginx/nginx.conf
# COPY index.html /usr/share/nginx/html/index.html 
# COPY index.html /home/app/index.html 
COPY app.js /home/app/app.js
COPY chains/chains_mainnet_template.json /home/app/chains_mainnet_template.json
COPY chains/chains_testnet_template.json /home/app/chains_testnet_template.json
COPY config_template.json /home/app/config_template.json

RUN npm install express shelljs
RUN npx update-browserslist-db@latest

COPY --from=build-ui /app/ui/build /home/app/build
COPY dummyui /home/app/dummyui

# UI Internal
EXPOSE 80
# RPC Proxy via HTTPS External
EXPOSE 8081
# P2P External
EXPOSE 26656
# Tendermint RPC Internal
EXPOSE 26657  

ENTRYPOINT ["entrypoint.sh"]
