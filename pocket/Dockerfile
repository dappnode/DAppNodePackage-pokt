# build environment
ARG UPSTREAM_VERSION
FROM node:16.17.0-alpine as build-ui
WORKDIR /app
COPY ui /app/ui
# COPY ui/package.json ./
# COPY ui/yarn.lock ./

WORKDIR /app/ui
RUN yarn && yarn build


FROM ghcr.io/pokt-network/pocket-v0:${UPSTREAM_VERSION}
#ghcr.io/pokt-network/pocket-v0:BETA-0.10.2

WORKDIR /home/app/

USER root

# RUN apk add -u gettext curl jq nginx supervisor
RUN apk add -u gettext curl jq nodejs npm supervisor

ADD entrypoint.sh /usr/local/bin/entrypoint.sh

ADD chains/chains_mainnet.json /home/app/.pocket/config/chains.json
ADD genesis_mainnet.json /home/app/.pocket/config/genesis.json
ADD config_template.json /home/app/.pocket/config/config_template.json
ADD supervisord.conf /etc/supervisord/supervisord.conf
# ADD nginx.conf /etc/nginx/nginx.conf
# ADD index.html /usr/share/nginx/html/index.html 
# ADD index.html /home/app/index.html 
ADD app.js /home/app/app.js
ADD chains/chains_mainnet_template.json /home/app/chains_mainnet_template.json
ADD chains/chains_testnet_template.json /home/app/chains_testnet_template.json
RUN npm install express shelljs

COPY --from=build-ui /app/ui/build /home/app/build
COPY dummyui /home/app/dummyui

EXPOSE 8081
EXPOSE 26656
ENTRYPOINT ["entrypoint.sh"]
