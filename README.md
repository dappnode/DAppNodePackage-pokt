<!-- :female_detective: Looking for a new champion -->

# DAppNode Package _Pocket_

<!--DAppNode package logo (could be added with an hyperlink to a youtube video): -->

![image](/avatar.png)

<!--Brief introduction about the source project (official project definition is an option): -->
Pocket Network is the TCP/IP of Web3 node infrastructure – a multi-chain relay protocol that incentivizes RPC nodes to provide DApps and their users with unstoppable Web3 access.

More information about the source project can be found at their [Official Website](https://pokt.network)

## Why _Pocket_ ?

<!--What can you do with this package?: -->

Support your favorite applications and networks by sharing access to your node's enpoint via Pokt Network's by providing decentralized access for developers and users building and running applications on the Pokt Network. Join this novel decentalized infrastructure network that rewards servicer and validator nodes for the necessary work to keep public RPC endpoints for dozens of different blockchains properly decentralized and secure.

### Requirements

Requirements to run DAppNode package for Pocket

<!--Requirements to run the dappnode package in a list: -->

Minimum Hardware Requirements: 4 CPU Cores | 16 GB RAM | 800GB SSD or NVMe for POKT node + disk space for nodes you intend to relay on Pocket Network.

Ports: Be sure your node has properly exposed the Pocket RPC via HTTPS (Container Default Port 8081 to be forwarded via HTTPS:443) and P2P port (Default: 26656/TCP)
This package attempts to automatically properly map the RPC port via the HTTPS Portal during installation.

UPnP (if enabled on your router and Dappnode) will attempt to forward ports 26656/TCP and 443/TCP to your Dappnode. If you have UPnP disabled, please ensure to forward these ports manually.

### Maintenance

<!--Table with champion/s mantainers, versions and update status -->
<!--UPDATED: :x: OR :heavy_check_mark: -->

|      Updated       | Champion/s |
| :----------------: | :--------: |
| :heavy_check_mark: | @mgarciate |

### Additional links

https://docs.pokt.network/node/

https://docs.pokt.network/core/guides/quickstart

https://github.com/pokt-network/pocket-core-deployments/tree/staging/docker-compose/stacks/pocket-validator

https://docs.pokt.network/core/guides/quickstart

https://docs.pokt.network/home/paths/node-runner#download-the-latest-snapshot

https://docs.pokt.network/home/paths/node-runner#create-an-account

https://github.com/cventastic/POKT_DOKT/

https://github.com/pokt-network/pocket-core-deployments/tree/staging/docker-compose/stacks/pocket-validator

https://github.com/cventastic/POKT_DOKT/blob/main/bootstrap_skript/pokt_mainnet.sh

https://explorer.pokt.network

https://explorer.testnet.pokt.network
