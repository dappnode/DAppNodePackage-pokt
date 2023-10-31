#!/bin/bash

# TODO: M Remove after testing
# set -x

ERROR="[ ERROR ]"
WARN="[ WARN ]"
INFO="[ INFO ]"

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

# Check if the node is initialized with SNAPSHOT
# Handle Snapshot Download and Decompression if needed
echo "${INFO} Check if initializing with SNAPSHOT..."
if [ "$NETWORK" == "mainnet" ] && ! $is_update; then
  
  if [ "$SNAPSHOT_MIRROR" == "U.S." ] then
    $MIRROR_URL="https://pocket-snapshot-us.liquify.com/files/"
  elif [ "$SNAPSHOT_MIRROR" == "U.K." ] then
    $MIRROR_URL="https://pocket-snapshot-uk.liquify.com/files/"
  elif [ "$SNAPSHOT_MIRROR" == "Japan" ] then
    $MIRROR_URL="https://pocket-snapshot-jp.liquify.com/files/"
  else 
    $MIRROR_URL="https://pocket-snapshot.liquify.com/files/"
  fi
  
  if [ "$PRUNED_SNAPSHOT" == "yes" ]; then
    MIRROR_URL=$MIRROR_URL"pruned/"
  else
    MIRROR_URL=$MIRROR_URL
  fi

  if [ "$COMPRESSED_SNAPSHOT" == "yes" ]; then
    fileName="latest_compressed.txt"
    SNAPSHOT_URL="$MIRROR_URL$fileName"
  else
    fileName="latest.txt"
    SNAPSHOT_URL="$MIRROR_URL$fileName"
  fi

  if [ "$ARIA2_SNAPSHOT" == "yes" ]; then
    echo "${INFO} Initializing with SNAPSHOT, it could take several hours..."
    start_downloading_ui
    mkdir -p /home/app/.pocket/
    cd /home/app/.pocket/
    echo "${INFO} Downloading snapshot file version..."
    echo "${INFO} wget -O ${fileName} ${MIRROR_URL}"
    wget -O "${fileName}" "${MIRROR_URL}"
    echo "${INFO} $fileName: $(cat $fileName)"
    latestFile=$(cat $fileName)
    # Function to check if the download is complete
    is_complete() {
        if [[ -f "$latestFile" ]]; then
            # Check if the file is a valid tar archive
            tar -tf "$fileName" >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                return 0
            fi
        fi
        return 1
    }

    # Function to extract the downloaded file to /home/app/.pocket/ directory
    extract_file() {
        if [[ $latestFile == *.tar.lz4 ]]; then
            lz4 -c -d "$latestFile" | tar -x -C /home/app/.pocket/
        elif [[ $latestFile == *.tar ]]; then
            tar -xvf "$latestFile" -C /home/app/.pocket/
        fi
    }

    # Loop until the download is complete
    while [[ ! $(is_complete) ]]; do
        echo "Starting download..."
        aria2c -x16 -s16 -o "$latestFile" "$MIRROR_URL"
    done

    echo "Download complete!"

    # Extract the downloaded file to /home/app/.pocket/ directory
    echo "Extracting the downloaded file to /home/app/.pocket/..."
    extract_file

    # Delete the source file
    echo "Deleting the source file..."
    rm "$latestFile"

    echo "${INFO} Extraction and cleanup of snapshot complete!"
    stop_downloading_ui
  else
########FINISH HERE
    ##############################################################################################################
    echo "${INFO} Initializing with SNAPSHOT, it could take several hours..."
    start_downloading_ui
    mkdir -p /home/app/.pocket/
    cd /home/app/.pocket/
    echo "${INFO} Downloading snapshot file version..."
    echo "${INFO} wget -O latest.txt ${MIRROR_URL}"
    wget -O latest.txt "${MIRROR_URL}"
    echo "${INFO} latest.txt: $(cat latest.txt)"
    latestFile=$(cat latest.txt)
    if [ "$COMPRESSED_SNAPSHOT" == "yes" ]; then
      echo "${INFO} Downloading and decompressing the latest compressed snapshot file..."
      echo "${INFO} wget -c -O - https://pocket-snapshot.liquify.com/files/pruned/$latestFile | lz4 -d - | tar -xv -"
      wget -c -O - "https://pocket-snapshot.liquify.com/files/pruned/$latestFile" | lz4 -d - | tar -xv -
      echo "${INFO} Snapshot Downloaded and Decompressed!"
      echo "${INFO} Removing temporary snapshot file metadata..."
      rm latest.txt
      echo "${INFO} Snapshot Ready!"
      stop_downloading_ui
    else
      echo "${INFO} Downloading and decompressing the latest uncompressed snapshot file..."
      echo "${INFO} wget -c -O - https://pocket-snapshot.liquify.com/files/pruned/$latestFile | tar -xv -"
      wget -c -O - "https://pocket-snapshot.liquify.com/files/pruned/$latestFile" | tar -xv -
      echo "${INFO} Snapshot Downloaded and Decompressed!"
      echo "${INFO} Removing temporary snapshot file metadata..."
      rm latest.txt
      echo "${INFO} Snapshot Ready!"
      stop_downloading_ui
    fi
  else
    echo "${INFO} Initializing with SNAPSHOT, it could take several hours..."
    start_downloading_ui
    mkdir -p /home/app/.pocket/
    cd /home/app/.pocket/
    echo "${INFO} Downloading snapshot file version..."
    echo "${INFO} wget -O latest.txt ${MIRROR_URL}"
    wget -O latest.txt "${MIRROR_URL}"
    echo "${INFO} latest.txt: $(cat latest.txt)"
    latestFile=$(cat latest.txt)
    if [ "$COMPRESSED_SNAPSHOT" == "yes" ];

  echo "${INFO} SNAPSHOT Url: ${SNAPSHOT_URL}"
  echo "${INFO} Initializing with SNAPSHOT, it could take several hours..."
  start_downloading_ui
  mkdir -p /home/app/.pocket/
  cd /home/app/.pocket/

  #Update snapshot to Liquify Pruned Uncomepressed and Compressed Version to save disk space and bandwidth during initial sync
  echo "${INFO} Downloading snapshot file version..."
  echo "${INFO} wget -O latest.txt ${SNAPSHOT_URL}"
  wget -O latest.txt "${SNAPSHOT_URL}"
  echo "${INFO} latest.txt: $(cat latest.txt)"
  latestFile=$(cat latest.txt)
  if [[ $SNAPSHOT_URL == *compressed.txt* ]]
  then
    echo "${INFO} Downloading and decompressing the latest compressed snapshot file..."
    echo "${INFO} wget -c -O - https://pocket-snapshot.liquify.com/files/pruned/$latestFile | lz4 -d - | tar -xv -"
    wget -c -O - "https://pocket-snapshot.liquify.com/files/pruned/$latestFile" | lz4 -d - | tar -xv -
    echo "${INFO} Snapshot Downloaded and Decompressed!"
    echo "${INFO} Removing temporary snapshot file metadata..."
    rm latest.txt
    echo "${INFO} Snapshot Ready!"
    stop_downloading_ui
  else
    echo "${INFO} Downloading and decompressing the latest uncompressed snapshot file..."
    echo "${INFO} wget -c -O - https://pocket-snapshot.liquify.com/files/pruned/$latestFile | tar -xv -"
    wget -c -O - "https://pocket-snapshot.liquify.com/files/pruned/$latestFile" | tar -xv -
    echo "${INFO} Snapshot Downloaded and Decompressed!"
    echo "${INFO} Removing temporary snapshot file metadata..."
    rm latest.txt
    echo "${INFO} Snapshot Ready!"
    stop_downloading_ui
  fi
fi

echo "${INFO} pocket start"
exec supervisord -c /etc/supervisord/supervisord.conf
