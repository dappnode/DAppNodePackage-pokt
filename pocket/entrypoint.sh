#!/bin/bash

# TODO: M Remove after testing
# set -x

ERROR="[ ERROR ]"
WARN="[ WARN ]"
INFO="[ INFO ]"

#Determine Global ENVs for Execution Clients on Goerli and Mainnet
case $_DAPPNODE_GLOBAL_EXECUTION_CLIENT_PRATER in
"goerli-geth.dnp.dappnode.eth")
    GLOBAL_EXECUTION_CLIENT_GOERLI="http://goerli-geth.dappnode:8545"
    ;;
"goerli-nethermind.dnp.dappnode.eth")
    GLOBAL_EXECUTION_CLIENT_GOERLI="http://goerli-nethermind.dappnode:8545"
    ;;
"goerli-besu.dnp.dappnode.eth")
    GLOBAL_EXECUTION_CLIENT_GOERLI="http://goerli-besu.dappnode:8545"
    ;;
"goerli-erigon.dnp.dappnode.eth")
    GLOBAL_EXECUTION_CLIENT_GOERLI="http://goerli-erigon.dappnode:8545"
    ;;
*)
    echo "Unknown value for _DAPPNODE_GLOBAL_EXECUTION_CLIENT_PRATER: $_DAPPNODE_GLOBAL_EXECUTION_CLIENT_PRATER"
    GLOBAL_EXECUTION_CLIENT_GOERLI="http://goerli-geth.dappnode:8545"
    ;;
esac
export GLOBAL_EXECUTION_CLIENT_GOERLI=$GLOBAL_EXECUTION_CLIENT_GOERLI

case $_DAPPNODE_GLOBAL_EXECUTION_CLIENT_MAINNET in
"geth.dnp.dappnode.eth")
    GLOBAL_EXECUTION_CLIENT_MAINNET="http://geth.dappnode:8545"
    ;;
"nethermind.public.dappnode.eth")
    GLOBAL_EXECUTION_CLIENT_MAINNET="http://nethermind.public.dappnode:8545"
    ;;
"besu.public.dappnode.eth")
    GLOBAL_EXECUTION_CLIENT_MAINNET="http://besu.public.dappnode:8545"
    ;;
"erigon.dnp.dappnode.eth")
    GLOBAL_EXECUTION_CLIENT_MAINNET="http://erigon.dappnode:8545"
    ;;
*)
    echo "Unknown value for _DAPPNODE_GLOBAL_EXECUTION_CLIENT_MAINNET: $_DAPPNODE_GLOBAL_EXECUTION_CLIENT_MAINNET"
    GLOBAL_EXECUTION_CLIENT_MAINNET="http://geth.dappnode:8545"
    ;;
esac
export GLOBAL_EXECUTION_CLIENT_MAINNET=$GLOBAL_EXECUTION_CLIENT_MAINNET



# Replace domain
export DOMAIN=${_DAPPNODE_GLOBAL_DOMAIN}
envsubst < /home/app/.pocket/config/config_template.json > /home/app/.pocket/config/config.json

#############
# FUNCTIONS #
#############

function start_downloading_ui () {
  echo "${INFO} Downloading snapshot UI - Starting"
  cd /home/app/dummyui && node app.js &
  echo "${INFO} Downloading snapshot UI - Started"
}

function stop_downloading_ui () {
  echo "${INFO} Downloading snapshot UI - Stopping"
  pkill node
  sleep 2
  echo "${INFO} Downloading snapshot UI - Stopped"
}

########
# MAIN #
########

[[ -d /home/app/.pocket/data/application.db ]] && is_update=true || is_update=false

echo "${INFO} isUpdate: ${is_update}"
echo "${INFO} pocket accounts list --datadir=/home/app/.pocket/"
pocket accounts list --datadir=/home/app/.pocket/
if ! [ "$?" -eq 0 ] ;then
  echo "${INFO} pocket accounts import-armored /home/app/.pocket/config/keyfile.json --datadir=/home/app/.pocket/ --pwd-decrypt --pwd-encrypt"
    pocket accounts import-armored /home/app/.pocket/config/keyfile.json --datadir=/home/app/.pocket/ --pwd-decrypt ${KEYFILE_PASSPHRASE} --pwd-encrypt ${KEYFILE_PASSPHRASE}
    if ! [ "$?" -eq 0 ] ;then
        echo "${ERROR} It has not been possible to import the wallet"
        sleep 1000
        exit 1
    fi
fi
## # Create an account if it doesn't exist
## if ! [ "$?" -eq 0 ] ;then
##  pocket accounts create --pwd ${KEYFILE_PASSPHRASE} --datadir=/home/app/.pocket/
## fi

# Set validator
echo "${INFO} pocket accounts set-validator --pwd --datadir=/home/app/.pocket/ account"
pocket accounts set-validator --pwd ${KEYFILE_PASSPHRASE} --datadir=/home/app/.pocket/ `pocket accounts list --datadir=/home/app/.pocket/ | cut -d' ' -f2- `
if ! [ "$?" -eq 0 ] ;then
    echo "${ERROR} It has not been possible to set the validator"
    sleep 1000
    exit 1
fi

# Check pocket node
echo "${INFO} pocket start --simulateRelay --datadir=/home/app/.pocket/"
pocket start --simulateRelay --datadir=/home/app/.pocket/ &
PID_SIMULATE_RELAY=$!
sleep 2
OUTPUT=$(curl -X POST --data '{"relay_network_id":"0021","payload":{"data":"{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"0x8D97689C9818892B700e27F316cc3E41e17fBeb9\", \"latest\"],\"id\":1}","method":"POST","path":"","headers":{}}}' https://pocket-pocket.${_DAPPNODE_GLOBAL_DOMAIN}/v1/client/sim)
if echo "$OUTPUT" | grep "no such host"; then
  echo "${ERROR} It has not been possible to simulate relay"
else
  echo "${INFO} OK"
fi
kill $PID_SIMULATE_RELAY

echo "${INFO} Check if initializing with SNAPSHOT..."
if [ "$NETWORK" == "mainnet" ] && ! $is_update; then
  echo "${INFO} SNAPSHOT Url: ${SNAPSHOT_URL}"
  echo "${INFO} Initializing with SNAPSHOT, it could take several hours..."
  start_downloading_ui
  mkdir -p /home/app/.pocket/data
  cd /home/app/.pocket/data

  # Use different tar arguments if the file ends with .tar.gz
  if [[ $SNAPSHOT_URL == *.tar.gz* ]]
  then
    TAR_ARGS=xvzf
  else
    TAR_ARGS=xvf
  fi

  echo "${INFO} wget -qO- ${SNAPSHOT_URL} | tar ${TAR_ARGS} -"
  wget -qO- ${SNAPSHOT_URL} | tar ${TAR_ARGS} -
  echo "${INFO} SNAPSHOT downloaded!"
  stop_downloading_ui
fi

echo "${INFO} pocket start"
exec supervisord -c /etc/supervisord/supervisord.conf
