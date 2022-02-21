ARG UPSTREAM_VERSION
FROM poktnetwork/pocket:${UPSTREAM_VERSION}

WORKDIR /home/app/.pocket/
ADD entrypoint.sh /home/app/.pocket/entrypoint.sh
ADD keyfile.json /home/app/.pocket/keyfile.json
ADD chains/chains_testnet.json /home/app/.pocket/config/chains.json
ADD genesis_testnet.json /home/app/.pocket/config/genesis.json

EXPOSE 8081
EXPOSE 26656

CMD ["pocket", "start", "--keybase=false", "--testnet", "--datadir=/home/app/.pocket/"]
# ENTRYPOINT ["/entrypoint.sh"]
