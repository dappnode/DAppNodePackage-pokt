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

# Function to check if the snapshot download is complete
function is_complete() {
    if [[ -f "${latestFile}" ]]; then
        # Check if the file is a valid tar archive
        tar -tf "$latestFile" >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            return 0
        fi
    fi
    return 1
}    

# Function to extract the downloaded file to /home/app/.pocket/ directory
function extract_file() {
    if [[ $latestFile == *.tar.lz4 ]]; then
        lz4 -c -d "$latestFile" | tar -xv -C /home/app/.pocket/
    elif [[ $latestFile == *.tar ]]; then
        tar -xvf "$latestFile" -C /home/app/.pocket/
    fi
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

# Check if the node is initialized with SNAPSHOT
# Handle Snapshot Download and Decompression if needed
echo "${INFO} Check if initializing with SNAPSHOT..."
if [ "$NETWORK" == "mainnet" ] && ! $is_update; then
  
  if [ "$SNAPSHOT_MIRROR" == "Yes" ]; then
    MIRROR_URL="https://pocket-snapshot-uk.liquify.com/files/"
  else 
    MIRROR_URL="https://pocket-snapshot.liquify.com/files/"
  fi
  
  if [ "$PRUNED_SNAPSHOT" == "Yes" ]; then
    MIRROR_URL=$MIRROR_URL"pruned/"
  else
    MIRROR_URL=$MIRROR_URL
  fi

  if [ "$COMPRESSED_SNAPSHOT" == "Yes" ]; then
    fileName="latest_compressed.txt"
    SNAPSHOT_URL="$MIRROR_URL$fileName"
  else
    fileName="latest.txt"
    SNAPSHOT_URL="$MIRROR_URL$fileName"
  fi

  #Download Snapshot Metedata
  start_downloading_ui
  mkdir -p /home/app/.pocket/
  cd /home/app/.pocket/
  echo "${INFO} Downloading snapshot file version..."
  echo "${INFO} wget -O ${fileName} ${SNAPSHOT_URL}"
  wget -O "${fileName}" "${SNAPSHOT_URL}"
  echo "${INFO} ${fileName}: $(cat $fileName)"
  latestFile=$(cat $fileName)
  downloadURL="${MIRROR_URL}${latestFile}"

  if [ "$ARIA2_SNAPSHOT" == "Yes" ]; then
    echo "${INFO} Initializing with Aria2 SNAPSHOT, it could take several hours..."
    echo "${INFO} Starting aria2 download..."
    echo "${INFO} aria2c -x16 -s16 -o ${latestFile} ${downloadURL}"
    aria2c -x16 -s16 -o "${latestFile}" "${downloadURL}"

    # # Loop until the download is complete \\ This does not work so far likely a syntax error, but so far no tests have led to failures yet with this config, on my test nodes at least
    # while [[ ! $(is_complete) ]]; do
    #     echo "${INFO} Starting aria2 download..."
    #     echo "${INFO} aria2c -x16 -s16 -o ${latestFile} ${downloadURL}"
    #     aria2c -x16 -s16 -o "${latestFile}" "${downloadURL}"
    # done

    echo "${INFO} Download complete!"

    # Extract the downloaded file to /home/app/.pocket/ directory
    echo "${INFO} Extracting the downloaded file to /home/app/.pocket/..."
    extract_file

    # Delete the source file
    echo "${INFO} Deleting the source file, and metadata file..."
    rm "${latestFile}" "${fileName}"
    echo "${INFO} Extraction and cleanup of snapshot complete!"
    stop_downloading_ui
  else

    ### WGET INLINE SNAPSHOT
    ##############################################################################################################
    echo "${INFO} Initializing with wget inline SNAPSHOT, it could take several hours..."
    max_retries=5
    retries=0

    if [ "$COMPRESSED_SNAPSHOT" == "Yes" ]; then
      echo "${INFO} Downloading and decompressing the latest compressed snapshot file..."
      echo "${INFO} while ! wget -c -O - ${downloadURL} | lz4 -d - | tar -xv -; do"
      while ! wget -c -O - "${downloadURL}" | lz4 -d - | tar -xv -; do
        if [ $retries -ge $max_retries ]; then
          echo "Download failed after $max_retries retries, try using aria download or a pruned download if this fails multiple times. exiting..."
          exit 1
        fi
        retries=$((retries+1))
        echo "Download failed, retrying in 10 seconds (retry $retries of $max_retries)..."
        sleep 10
      done
      echo "${INFO} Snapshot Downloaded and Decompressed!"
      echo "${INFO} Removing temporary snapshot file metadata..."
      rm "${fileName}"
      echo "${INFO} Snapshot Ready!"
      stop_downloading_ui
    else
      echo "${INFO} Downloading and decompressing the latest uncompressed snapshot file..."
      echo "${INFO} while ! wget -c -O - ${downloadURL} | tar -xv -; do"
      echo "${INFO}   if [ $retries -ge $max_retries ]; then"
      echo "${INFO}     echo Download failed after $max_retries retries, try using aria download or a pruned download if this fails multiple times. exiting..."
      echo "${INFO}     exit 1"
      echo "${INFO}   fi"
      echo "${INFO}   retries=$((retries+1))"
      echo "${INFO}   echo Download failed, retrying in 10 seconds (retry $retries of $max_retries)..."
      echo "${INFO}   sleep 10"
      echo "${INFO} done"
      while ! wget -c -O - "${downloadURL}" | tar -xv -; do
        if [ $retries -ge $max_retries ]; then
          echo "${INFO} Download failed after $max_retries retries, try using aria download or a pruned download if this fails multiple times. exiting..."
          exit 1
        fi
        retries=$((retries+1))
        echo "${INFO} Download failed, retrying in 10 seconds (retry $retries of $max_retries)..."
        sleep 10
      done
      echo "${INFO} Snapshot Downloaded and Decompressed!"  
      echo "${INFO} Removing temporary snapshot file metadata..."
      rm $fileName
      echo "${INFO} Snapshot Ready!"
      stop_downloading_ui
    fi
  fi
fi

echo "${INFO} pocket start"
exec supervisord -c /etc/supervisord/supervisord.conf
