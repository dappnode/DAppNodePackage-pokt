#!/bin/bash

# TODO: V Remove after testing
set -x

ERROR="[ ERROR ]"
WARN="[ WARN ]"
INFO="[ INFO ]"

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

#jq --arg session_rollover "${SESSION_ROLLOVER}" 'if $session_rollover == 1 then .pocket_config.client_session_sync_allowance = 1 else .pocket_config.client_session_sync_allowance = 0 end' temp3.json > temp4.json
#jq --arg backfire_prevention "${BACKFIRE_PREVENTION}" 'if $backfire_prevention == true then .pocket_config.prevent_negative_reward_claim = true else .pocket_config.prevent_negative_reward_claim = false end' temp4.json > /home/app/.pocket/config/config.json

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

# Function to cleanup failed snapshot downloads
function cleanup_failed_snapshot () {
  rm -r -f /home/app/.pocket/data \
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

# Function to check if the snapshot download is complete
function is_complete() {
  if [[ -f "${latestFile}" ]]; then
    # Check if the file is a valid tar archive
    file "${latestFile}"
    if [[ $? -eq 0 ]] && [[ "${latestFile}" == *.tar ]] || [[ "${latestFile}" == *.tar.lz4 ]]; then
      if [[ "${latestFile}" == *.tar.lz4 ]]; then
        lz4 -cd "${latestFile}" | tar -tf -
      else
        tar -tf "${latestFile}"
      fi
      if [[ $? -eq 0 ]]; then
        return 0
      fi
    fi
  fi
  return 1
}

# function is_complete() {
#   if [[ -f "${latestFile}" ]]; then
#     # Check if the file is a valid tar archive
#     tar -tf "$latestFile" >/dev/null 2>&1
#     if [[ $? -eq 0 ]]; then
#       return 0
#     fi
#   fi
#   return 1
# }    

# Tabnine suggests this function to download the snapshot inline, but is not tested yet.
function download_inline_snapshot() {
  local downloadURL="$1"
  local latestFile="$2"
  local retries=0
  local max_retries=5

  while ! [ -f "$latestFile" ] || ! [ -s "$latestFile" ]; do
    if [ $retries -ge $max_retries ]; then
      echo "${ERROR} Download failed after $max_retries retries, try using aria download or a pruned download if this fails multiple times. exiting..."
      echo "${INFO} Cleaning up and exiting..."
      cleanup_failed_snapshot
      sleep 500
      exit 1
    fi
    retries=$((retries+1))
    echo "${INFO} Download failed, retrying in 10 seconds (retry $retries of $max_retries)..."
    sleep 10

    if [[ "$latestFile" == *.tar.lz4 ]]; then
      echo "${INFO} Downloading and decompressing the latest compressed snapshot file..."
      echo "${INFO} wget -c -O - ${downloadURL} | lz4 -d - | tar -xv -"
      wget -c -O - "${downloadURL}" | lz4 -d - | tar -xv -
    else
      echo "${INFO} Downloading and decompressing the latest uncompressed snapshot file..."
      echo "${INFO} wget -c -O - ${downloadURL} | tar -xv -"
      wget -c -O - "${downloadURL}" | tar -xv -
    fi

    if [ ! -f "$latestFile" ] || ! [ -s "$latestFile" ]; then
      echo "${ERROR} Download failed, the downloaded file is not a valid tar archive."
      rm "$latestFile"
    fi
  done

  echo "${INFO} Snapshot Downloaded and Decompressed!"
  echo "${INFO} Removing temporary snapshot file metadata..."
  rm "${fileName}"
  echo "${INFO} Snapshot Ready!"
  stop_downloading_ui
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

  #Download Snapshot Metedata for Latest Snapshot File
  start_downloading_ui
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
    # echo "${INFO} aria2c -x16 -s16 -o ${latestFile} ${downloadURL}"
    # aria2c -x16 -s16 -o "${latestFile}" "${downloadURL}"

    # # Loop until the download is complete \\ This does not work so far likely a syntax error, but so far no tests have led to failures yet with this config, on my test nodes at least
    # while [[ ! $(is_complete) ]]; do
    #     echo "${INFO} Starting aria2 download..."
    #     echo "${INFO} aria2c -x16 -s16 -o ${latestFile} ${downloadURL}"
    #     aria2c -x16 -s16 -o "${latestFile}" "${downloadURL}"
    # done
    ################################################################

    # Call the Aria2c Download Snapshot Function
    download_snapshot
    echo "${INFO} Aria2 Download of Snapshot Complete!"

    # Extract the downloaded file to /home/app/.pocket/ directory
    echo "${INFO} Extracting the downloaded file to /home/app/.pocket/ ..."
    extract_file
    if [ $? -ne 0 ]; then
      echo "${ERROR} extracting the downloaded snapshot exited with non-zero exit code. Exiting..."
      echo "${INFO} Cleaning up and exiting..."
      cleanup_failed_snapshot
      sleep 500
      exit 1
    fi
    
    # Delete the source file
    echo "${INFO} Deleting the Snapshot source file and metadata file..."
    rm "${latestFile}" "${fileName}"
    echo "${INFO} Extraction and cleanup of snapshot complete!"
    stop_downloading_ui
  else

    ### WGET INLINE SNAPSHOT#########  curl option should be faster and more resiliant  curl -L -O -C - "${downloadURL}" | lz4 -d - | tar -xv -
    ##########################################################################################
    echo "${INFO} Initializing with wget inline SNAPSHOT, it could take several hours or days to download a NON-pruned snapshot..."
    max_retries=5
    retries=0

    if [ "$COMPRESSED_SNAPSHOT" == "Yes" ]; then
      echo "${INFO} Downloading and decompressing the latest compressed snapshot file..."
      echo "${INFO} while ! wget -c -O - ${downloadURL} | lz4 -d - | tar -xv -; do"
      while ! wget -c -O - "${downloadURL}" | lz4 -d - | tar -xv -; do
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
      stop_downloading_ui
    fi
  fi
fi

echo "${INFO} pocket start"
exec supervisord -c /etc/supervisord/supervisord.conf
