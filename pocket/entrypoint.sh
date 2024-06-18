#!/bin/bash

# TODO: V Remove after testing
set -x

ERROR="[ ERROR ]"
WARN="[ WARN ]"
INFO="[ INFO ]"

##############
#   CONFIG   #
##############

# Replace the config_template.json file with the updated version
echo "${INFO} Updating config_template.json..."
cp /home/app/config_template.json /home/app/.pocket/config/config_template.json
if [ $? -ne 0 ]; then
  echo "${ERROR} Failed to update config_template.json with new version Exiting..."
  sleep 60
  exit 1
fi

# Replace domain, seeds, max peers inbound/outbound, backfire protection, session rollover and persistent peers in the config file with environment variables
export DOMAIN=${_DAPPNODE_GLOBAL_DOMAIN}
export SEEDS=${SEEDS}
export PERSISTENT_PEERS=${PERSISTENT_PEERS}
export MAX_PEERS_INBOUND=${MAX_PEERS_INBOUND}
export MAX_PEERS_OUTBOUND=${MAX_PEERS_OUTBOUND}
export BACKFIRE_PREVENTION=${BACKFIRE_PREVENTION}
export SESSION_ROLLOVER=${SESSION_ROLLOVER}
export PRUNED=${PRUNED_SNAPSHOT}

# Run envsubst before the jq commands and write the modified output to config_template.json
echo "${INFO} Substituting environment variables in the config_template.json file..."
envsubst < /home/app/.pocket/config/config_template.json > temp.json
if [ $? -ne 0 ]; then
  echo "${ERROR} Failed to set ENV variables in Config. Confirm you have valid entries for the config options Seeds and Persistent Peers in the Pocket package config tab. If you don't see an issue with your config, please contact support. Exiting..."
  sleep 60
  exit 1
fi

# Process the modified config_template.json file with jq commands and write the output to config.json
jq --arg max_peers_inbound "${MAX_PEERS_INBOUND}" '.tendermint_config.P2P.MaxNumInboundPeers = ($max_peers_inbound|tonumber)' temp.json > temp2.json && rm temp.json
if [ $? -ne 0 ]; then
  echo "${ERROR} Failed to set Max Inbound Peers in the Config. Confirm you have a valid entry for the Max Inbound Peers value in the Pocket package config tab. If you don't see an issue with your input please contact support. Exiting..."
  sleep 60
  exit 1
fi
jq --arg max_peers_outbound "${MAX_PEERS_OUTBOUND}" '.tendermint_config.P2P.MaxNumOutboundPeers = ($max_peers_outbound|tonumber)' temp2.json > temp3.json && rm temp2.json
if [ $? -ne 0 ]; then
  echo "${ERROR} Failed to set Max Outbound Peers in the Config. Confirm you have a valid entry for the Max Outbound Peers value in the Pocket package config tab. If you don't see an issue with your input please contact support. Exiting..."
  sleep 60
  exit 1
fi
jq --arg session_rollover "${SESSION_ROLLOVER}" '.pocket_config.client_session_sync_allowance = ($session_rollover|tonumber)' temp3.json > temp4.json && rm temp3.json
if [ $? -ne 0 ]; then
  echo "${ERROR} Failed to set Session Rollover in the Config. Confirm you have a valid entry for the Session Rollover value in the Pocket package config tab. If you don't see an issue with your input please contact support. Exiting..."
  sleep 60
  exit 1
fi
jq --arg backfire_prevention "${BACKFIRE_PREVENTION}" 'if $backfire_prevention == "true" then .pocket_config.prevent_negative_reward_claim = true else .pocket_config.prevent_negative_reward_claim = false end' temp4.json > /home/app/.pocket/config/config.json && rm temp4.json
if [ $? -ne 0 ]; then
  echo "${ERROR} Failed to set Backfire Prevention in the Config. Confirm you have a valid entry for the Backfire Prevention value in the Pocket package config tab. If you don't see an issue with your input please contact support. Exiting..."
  sleep 60
  exit 1
else
  echo "${INFO} Config file updated successfully!"
fi

# Add addrbook.json from liquify to config directory if it doesn't exist already Causing a restart loop and failure to connect to any peers or seeds.
# MAY WANT TO USE A CUSTOM DAPPNODE/VISNOVALABS LINK TO A NEWER ADDR BOOK (CURRENTLY LIQUIFY IS 5 MONTHS OLD) THAT INCLUDES OUR DAPPNODE PEERS THAT ARE ONLINE ALREADY AND HAVE BEEN, ALONG WITH NEW RECRUITS, HOPE TO USE PERSISTENT PEERS TO HELP PEERING FOR DAPPNODE USERS ESPECIALLY PRUNED USERS AS THEY CAN HAVE TROUBLE SYNCING TO HEAD AFTER SNAPSHOT SINCE THEY DONT HAVE ALL DATA AND PEERS WILL DROP THEM.
if [! -f /home/app/.pocket/config/addrbook.json]; then
  echo "${INFO} Downloading addrbook.json..."
  wget -O /home/app/.pocket/config/addrbook.json https://pocket-snapshot.liquify.com/files/addrbook.json
  if [ $? -ne 0 ]; then
    echo "${ERROR} Failed to download addrbook.json. Exiting..."
    sleep 60
    exit 1
  else
    echo "${INFO} addrbook.json downloaded successfully!"
  fi
else
  echo "${INFO} addrbook.json already exists!"
fi

#############
# FUNCTIONS #
#############

function start_snapshot_ui () {
  echo "${INFO} Snapshot Download UI - Starting"
  cd /home/app/dummyui && node app.js &
  echo "${INFO} Snapshot Download UI - Started"
}

function stop_snapshot_ui () {
  echo "${INFO} Snapshot Download UI - Stopping"
  pkill node
  sleep 2
  echo "${INFO} Snapshot Download UI - Stopped"
}

# Function to cleanup failed snapshot downloads
function cleanup_failed_snapshot () {
  rm -rf /home/app/.pocket/data \
  /home/app/.pocket/pocket* \
  /home/app/.pocket/$fileName \
  /home/app/.pocket/$latestFile \
  /home/app/.pocket/*.aria \
  /home/app/.pocket/*.tmp
}

# Function to download latest snapshot via Aria2c
function download_snapshot() {
  status=-1
  while (( status != 0 ))
  do 
    PIDS=$(pgrep '^aria2c$')
    if [ -z "$PIDS" ]; then
      echo "${INFO} aria2c -o $latestFile -s16 -x16 -k100M $downloadURL &"
      aria2c -o $latestFile -s16 -x16 -k100M $downloadURL &
      pid=$!
    fi
    if kill -0 $pid 2>/dev/null; then
      wait $pid
    fi
    status=$?
    echo "${INFO} Aria Snapshot Download Exited."
    case $status in
      3)
        echo "${WARN} Cannot access snapshot or file does not exist on server. \
        Please check the snapshot URL and try again."
        echo "${ERROR} Exiting..."
        echo "${INFO} Removing incomplete snapshot files..."
        cleanup_failed_snapshot
        sleep 100
        exit 3
        ;;
      9)
        echo "${WARN} No space left on device for this snapshot, make room or try downloading a pruned snapshot; they're orders of magnitude smaller than a full snapshot."
        echo "${ERROR} Exiting..."
        echo "${INFO} Removing incomplete snapshot files..."
        cleanup_failed_snapshot
        sleep 1000
        exit 9
        ;;
      *)
        continue
        ;;
    esac
  done
  # download succeeded.
  return 0
}

# # Function to check if the snapshot download is complete was used in a previous iteration of a while loop that did not work well, this is likely uneeded now. Aria should and does validate files downloaded AFAIK, but the real reason for removing is that to check integrity of a comprssed snapshot which is likely gonna be the norm pruned or full, it needs to extract the lz4 layer firt then list the contents of the tar arvhice which is like doubleing time, and space yet again, so leaving to be stashed, or used in a furture iteration if needed.
# function is_complete() {
#   if [[ -f "${latestFile}" ]]; then
#     # Check if the file is a valid tar or tar.lz4 archive
#     file "${latestFile}"
#     if [[ $? -eq 0 ]] && [[ "${latestFile}" == *.tar ]] || [[ "${latestFile}" == *.tar.lz4 ]]; then
#       if [[ "${latestFile}" == *.tar.lz4 ]]; then
#         lz4 -cd "${latestFile}" | tar -tf -
#       else
#         tar -tf "${latestFile}"
#       fi
#       if [[ $? -eq 0 ]]; then
#         return 0
#       fi
#     fi
#   fi
#   return 1
# }

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
    echo "${ERROR} It has not been possible to import the uploaded wallet. Please check the passphrase and the integrity of your keyfile.json file."
    sleep 1000
    exit 1
  fi
fi

## # Create an account if it doesn't exist // This is something we definitely should do (unless we add a new service to the package that runs the official Pocket WWallet) but we need to find a way to make absolutely sure that the user downloads a backup of the newly generated keystore and set keyfile_passphrase from config, not sure how to do this elegantly.
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

## Check pocket node by simulating relays
#echo "${INFO} pocket start --simulateRelay --datadir=/home/app/.pocket/"
#pocket start --simulateRelay --datadir=/home/app/.pocket/ &
#PID_SIMULATE_RELAY=$!
#sleep 2
#OUTPUT=$(curl -X POST --data '{"relay_network_id":"0021","payload":{"data":"{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"0x8D97689C9818892B700e27F316cc3E41e17fBeb9\", \"latest\"],\"id\":1}","method":"POST","path":"","headers":{}}}' https://pocket-pocket.${_DAPPNODE_GLOBAL_DOMAIN}/v1/client/sim)
#if echo "$OUTPUT" | grep "no such host"; then
#  echo "${ERROR} It has not been possible to simulate relays"
#else
#  echo "${INFO} OK"
#fi
#kill $PID_SIMULATE_RELAY

# Check if the node is initialized with SNAPSHOT
# Handle Snapshot Download and Decompression if needed
echo "${INFO} Check if initializing with SNAPSHOT..."
if [ "$NETWORK" == "mainnet" ] && ! $is_update; then
  # Is Monday? ENV
  if [ "$SNAPSHOT_MIRROR" == "Yes" ]; then
    MIRROR_URL="https://pocket-snapshot-uk.liquify.com/files/"
  else 
    MIRROR_URL="https://pocket-snapshot.liquify.com/files/"
  fi
  # Pruned? ENV
  if [ "$PRUNED_SNAPSHOT" == "Yes" ]; then
    MIRROR_URL=$MIRROR_URL"pruned/"
  else
    MIRROR_URL=$MIRROR_URL
  fi
  # Compressed? ENV
  if [ "$COMPRESSED_SNAPSHOT" == "Yes" ]; then
    fileName="latest_compressed.txt"
    SNAPSHOT_URL="$MIRROR_URL$fileName"
  else
    fileName="latest.txt"
    SNAPSHOT_URL="$MIRROR_URL$fileName"
  fi

  #Download Snapshot Metedata for Latest Snapshot File
  start_snapshot_ui
  mkdir -p /home/app/.pocket/
  cd /home/app/.pocket/
  echo "${INFO} Downloading latest snapshot file version..."
  echo "${INFO} wget -O ${fileName} ${SNAPSHOT_URL}"
  wget -O "${fileName}" "${SNAPSHOT_URL}"
  echo "${INFO} ${fileName}: $(cat $fileName)"
  latestFile=$(cat $fileName)
  downloadURL="${MIRROR_URL}${latestFile}"

  if [ "$ARIA2_SNAPSHOT" == "Yes" ]; then
    echo "${INFO} Initializing with Aria2c SNAPSHOT, it could take several hours to complete for an non-pruned full node..."
    echo "${INFO} Starting Aria2c download..."

    # Call the Aria2c Download Snapshot Function
    download_snapshot
    echo "${INFO} Aria2 Download of Snapshot Complete!"

    # Extract the downloaded file to /home/app/.pocket/ directory
    for attempt in {1..3}; do
      echo "${INFO} Attempt ${attempt}: Extracting the downloaded snapshot to /home/app/.pocket/ ..."
      extract_file
      if [ $? -eq 0 ]; then
        break
      else
        echo "${ERROR} Attempt ${attempt} failed: extracting the downloaded snapshot exited with non-zero exit code."
        if [ $attempt -lt 3 ]; then
          echo "${INFO} Cleaning up data directory before retry..."
          rm -rf /home/app/.pocket/data
          sleep 10
        fi
      fi
    done

    if [ $attempt -eq 3 ]; then
      echo "${ERROR} FATAL ERROR: All extraction attempts failed. Exiting..."
      echo "${ERROR} The extraction of the downloaded snapshot failed. Please check the integrity of the snapshot file and try downloading again, contact Dappnode Support on Discord if the issue persists."
      echo "${INFO} Cleaning up and exiting..."
      cleanup_failed_snapshot
      sleep 500
      exit 1
    fi

    # Delete the source file
    echo "${INFO} Deleting the Snapshot source file and metadata file..."
    rm "${latestFile}" "${fileName}"
    echo "${INFO} Extraction and cleanup of snapshot complete!"
    stop_snapshot_ui
  else

    ### WGET INLINE SNAPSHOT#########  curl option mqy be faster and more resiliant? WGET tested out well though, never had an error with a failed download due to conection loss as was the initial issuse when the snapshots were chsnged but liquify has upgraded their infra since to help as it was not isolated to me. ##  curl -L -O -C - "${downloadURL}" | lz4 -d - | tar -xv -
    ##########################################################################################
    echo "${INFO} Initializing with Wget inline SNAPSHOT, it could take several hours or days to download and a NON-pruned snapshot on lower end residential ISP speeed offerings..."
    max_retries=5
    retries=0

    if [ "$COMPRESSED_SNAPSHOT" == "Yes" ]; then
      echo "${INFO} Downloading and decompressing the latest compressed snapshot file..."
      echo "${INFO} while ! wget -c ${downloadURL} -O- | lz4 -d - | tar -xv -C /home/app/.pocket/; do"
      while ! wget -c "${downloadURL}" -O- | lz4 -d - | tar -xv -C /home/app/.pocket/; do
        if [ $retries -ge $max_retries ]; then
          echo "Download failed after $max_retries retries, try using aria download or a pruned download if this fails multiple times. exiting..."
          echo "${INFO} Cleaning up and exiting..."
          cleanup_failed_snapshot
          sleep 500
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
      stop_snapshot_ui
    else
      echo "${INFO} Downloading and decompressing the latest uncompressed snapshot file..."
      echo "${INFO} while ! wget -c ${downloadURL} -O- | tar -xv -C /home/app/.pocket/; do"
      while ! wget -c "${downloadURL}" -O- | tar -xv -C /home/app/.pocket/; do
        if [ $retries -ge $max_retries ]; then
          echo "${INFO} Download failed after $max_retries retries, try using aria download or a pruned download if this fails multiple times. exiting..."
          echo "${INFO} Cleaning up and exiting..."
          cleanup_failed_snapshot
          sleep 500
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
      stop_snapshot_ui
    fi
  fi
fi

echo "${INFO} pocket start"
exec supervisord -c /etc/supervisord/supervisord.conf
