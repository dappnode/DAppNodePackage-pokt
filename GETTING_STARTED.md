
# Dappnode Pokt

Hardware Requirements: 4 CPU’s (or vCPU’s) | 32 GB RAM | 1TB+ Disk for full POKT Chain and node + additional disk space for other chains to relay.
  - Pruned Nodes require under 100 GB for the Pokt node, but the Pokt chain cannot be relayed as it's pruned.
Ports: Expose Pocket RPC via HTTPS (Default :8081) and P2P port (Default: 26656)  
  - This is handled automatically on install (however with UPnP disabled on your router, please map TCP 26656 and TCP 443 to your Dappnode)  

Check your [wallet](https://wallet.pokt.network/)  
Check the [explorer](https://explorer.pokt.network/)

⚠️WARNING⚠️: DO NOT delete the volumes of this package without doing a backup (Backup > Backup now). After you re-sync, upload the backup directly on Backup > Restore Backup > Restore.
