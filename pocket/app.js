var express = require('express');
var app = express();
var shell = require('shelljs');
const {CUSTOM_UI_HTTP_PORT = 80} = process.env

var options = {
    index: "index.html"
};

app.use(express.static('./build'));
app.use('/', express.static('app', options));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/version', (req, res) => {
    var version = shell.exec('node --version').stdout;
    res.send(version)
})


app.get('/api/account', (req, res) => {
    // res.send(
    //     JSON.parse('{"amount":44799883637, "amountStaked":15200000000,"address":"6e00cb7e13812b3877d65df09639fad873b5a305","shortAddress":"6e00...a305","network":"testnet","node":{"address":"6e00cb7e13812b3877d65df09639fad873b5a305","chains":["0020","0002"],"jailed":false,"public_key":"1a33cdf837ed3c71aad3bc6a28c60fbfac2b27593bdecce4245e81954939f8fd","service_url":"https://pocket-pocket.39acfcb1331c8b7c.dyndns.dappnode.io:443","status":2,"tokens":"15200000000","unstaking_time":"0001-01-01T00:00:00Z"}}')
    // );
    // return;

    const address = shell.exec(`pocket accounts list --datadir=/home/app/.pocket/ | cut -d' ' -f2- `).stdout.trim();
    const network = shell.exec(`echo $NETWORK`).stdout.trim();
    let account, node, coin;
    try {
        account = JSON.parse(shell.exec(`pocket query account ${address} --datadir=/home/app/.pocket | tail -n +2`).stdout.trim());
        // "upokt"
        coin = account.coins.filter(function(item){
            return item.denom == "upokt";         
        })[0];
        node = JSON.parse(shell.exec(`pocket query node ${address} --datadir=/home/app/.pocket | tail -n +2`).stdout.trim());
    } catch (error) {
        console.log(error);
    }
    const response = {
        amount: coin?.amount ?? 0.0,
        amountStaked: node?.tokens ?? 0.0,
        address: account?.address ?? address,
        network: network,
        initialized: account != null ? true : false,
        node: node,
        jailed: node?.jailed ?? false,
        publicKey: node?.public_key ?? "Unknown",
        unstakingTime: node?.unstaking_time ?? "0001-01-01T00:00:00Z",
    };
    res.send(response);
});

app.get('/api/currentBlock', (req, res) => {
    // res.send(
    //     JSON.parse(`{"height":57120}`)
    // );
    // return;
    const response = JSON.parse(shell.exec(`pocket query height  --datadir=/home/app/.pocket/ | tail -n +2`).stdout.trim());
    res.send(response);
});

app.get('/api/address', (req, res) => {
    const address = shell.exec(`pocket accounts list --datadir=/home/app/.pocket/ | cut -d' ' -f2- `).stdout.trim();
    const response = {
        address: address
    };
    res.send(response);
})

function checkEthereumState(url) {
    try {
        const syncing = JSON.parse(shell.exec(`curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' ${url}`).stdout.trim());
        if (syncing.result === false) {
            return 2;
        }
        return 1;
    } catch (error) {
        return 0;
    }
}

function checkBeaconState(url) {
    try {
        const syncing = JSON.parse(shell.exec(`curl -X GET -H "accept: application/json" ${url}/eth/v1/node/syncing`).stdout.trim());
        if (syncing.data.is_syncing === false && syncing.data.is_optimistic === false && syncing.data.el_offline === false) {
            return 2;
        }
        return 1;
    } catch (error) {
        return 0;
    }
}

function checkNearState(url) {
    try {
        const syncing = JSON.parse(shell.exec(`curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"status","params":[],"id":1}' ${url}`).stdout.trim());
        if (syncing.result.sync_info.syncing === false) {
            return 2;
        }
        return 1;
    } catch (error) {
        return 0;
    }
}

function checkAvalancheState(url) {
    try {
        const syncing = JSON.parse(shell.exec(`curl -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.isBootstrapped", "params": {"chain":"X"}}' -H 'content-type:application/json;' ${url}/ext/info`).stdout.trim());
        if (syncing.result.isBootstrapped === true) {
            return 2;
        }
        return 1;
    } catch (error) {
        return 0;
    }
}

function checkTendermintState(url) {
    try {
        const syncing = JSON.parse(shell.exec(`curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"status","params":[],"id":1}' ${url}`).stdout.trim());
        if (syncing.result.sync_info.catching_up === false) {
            return 2;
        } else if (syncing.result.sync_info.catching_up === true) {
          }  return 1;
    } catch (error) {
        return 0;
    }
}

function checkPoktState(url) {
    try {
        var newUrl = url.replace(/:8081$/, ':26657');
        const syncing = JSON.parse(shell.exec(`curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"status","params":[],"id":-1}' "${newUrl}"`).stdout.trim());
        var prunedSnapshot = shell.exec(`echo $PRUNED_SNAPSHOT`).stdout.trim();
        if (syncing.result.sync_info.catching_up === false && prunedSnapshot == 'Yes') {
            return 3;
        } else if (syncing.result.sync_info.catching_up === false && prunedSnapshot == 'No') {
            return 2;
        } else if (syncing.result.sync_info.catching_up === true) {
          }  return 1;
    } catch (error) {
        return 0;
    }
}

function checkStateChain(type, url) {
    switch (type) {
        case "ethereum":
            return checkEthereumState(url);
        case "near":
            return checkNearState(url);
        case "avalanche":
            return checkAvalancheState(url);
        case "beacon":
            return checkBeaconState(url);
        case "pokt":
            return checkPoktState(url);
        default:
            return 0;
    }
}

app.get('/api/availableChains', (req, res) => {
    const network = shell.exec(`echo $NETWORK`).stdout.trim();
    let chains, json;
    if (network == 'mainnet') {
        chains = mainnetChains;
        json = JSON.parse(shell.exec(`cat chains_mainnet_template.json`).stdout.trim());
    } else {
        chains = testnetChains;
        json = JSON.parse(shell.exec(`cat chains_testnet_template.json`).stdout.trim());
    }
    const response = json.map(chain => {
        if (chains[chain.id]) { } else { return null; }
        return {
            id: chain.id,
            name: chains[chain.id].name,
            url: chain.url,
            state: checkStateChain(chains[chain.id].type, chain.url),
        }
    });
    res.send(response);
})

app.post('/api/replaceChains', (req, res) => {
    let chains = req.body.chains.split(",");
    const network = shell.exec(`echo $NETWORK`).stdout.trim();
    let json;
    if (network == 'mainnet') {
        json = JSON.parse(shell.exec(`cat chains_mainnet_template.json`).stdout.trim());
    } else {
        json = JSON.parse(shell.exec(`cat chains_testnet_template.json`).stdout.trim());
    }
    const chainsFiltered = json.filter(chain => {
        return chains.includes(chain.id);
    }).map(chain => {
        return {
            id: chain.id,
            url: chain.url,
        }
    });
    if (chainsFiltered && chainsFiltered.length > 0) {
        let response = JSON.stringify(chainsFiltered, null, 2);
        shell.exec(`echo '${response}' > /home/app/.pocket/config/chains.json`);
//        shell.exec(`pkill pocket`); This should no longer be needed since the addition of the config option for hot chains reload to be set to `true` this command no longer kills the Pocket process improving performance on initial test nodes so far, with no errors without kiling the process everytime it needs to reload the chains.json file.
        res.send(response);
    } else {
        throw new Error("Empty json");
    }
})

app.post('/api/unjailNode', (req, res) => {
    // pocket nodes unjail <operatorAddr> <fromAddr> <networkID> <fee> <isBefore8.0> [flags]
    const account = shell.exec(`pocket accounts list --datadir=/home/app/.pocket/ | cut -d' ' -f2- `).stdout.trim();
    const network = shell.exec(`echo $NETWORK`).stdout.trim();
    const passphrase = shell.exec(`echo $KEYFILE_PASSPHRASE`).stdout.trim();
    const response = shell.exec(`pocket nodes unjail ${account} ${account} ${network} 10000 false --datadir=/home/app/.pocket/ --pwd ${passphrase} | tail -n +3`).stdout.trim();
    res.send(response);
})

app.post('/api/stakeCustodial', (req, res) => {
    // console.log(req.body.amount);
    // console.log(req.body.chains);
    // res.send({});
    // return;
    const network = shell.exec(`echo $NETWORK`).stdout.trim();
    const passphrase = shell.exec(`echo $KEYFILE_PASSPHRASE`).stdout.trim();
    const address = shell.exec(`pocket accounts list --datadir=/home/app/.pocket/ | cut -d' ' -f2- `).stdout.trim();
    const domain = shell.exec(`echo $_DAPPNODE_GLOBAL_DOMAIN`).stdout.trim();
    // https://discord.com/channels/553741558869131266/564836328202567725/967105908347895819
    const response = shell.exec(`pocket nodes stake custodial ${address} ${req.body.amount} ${req.body.chains} https://pocket-pocket.${domain}:443 ${network} 10000 false --datadir=/home/app/.pocket/ --pwd ${passphrase} | tail -n +3`).stdout.trim();
    res.send(response);
})

app.post('/api/unstakeNode', (req, res) => {
    // res.send({});
    // return;
    const network = shell.exec(`echo $NETWORK`).stdout.trim();
    const passphrase = shell.exec(`echo $KEYFILE_PASSPHRASE`).stdout.trim();
    const address = shell.exec(`pocket accounts list --datadir=/home/app/.pocket/ | cut -d' ' -f2- `).stdout.trim();
    const response = shell.exec(`pocket nodes unstake ${address} ${address} ${network} 10000 false --datadir=/home/app/.pocket/ --pwd ${passphrase} | tail -n +3`).stdout.trim();
    res.send(response);
})


// app.post('/api/stakeNonCustodial', (req, res) => {
// //   pocket nodes stake non-custodial <operatorPublicKey> <outputAddress> <amount> <RelayChainIDs> <serviceURI> <networkID> <fee> <isBefore8.0> [flags]
// const network = shell.exec(`echo $NETWORK`).stdout.trim();
// const passphrase = shell.exec(`echo $KEYFILE_PASSPHRASE`).stdout.trim();
// const domain = shell.exec(`echo $_DAPPNODE_GLOBAL_DOMAIN`).stdout.trim();
// const operatorPublicKey = shell.exec().stdout.trim();
// })


var server = app.listen(CUSTOM_UI_HTTP_PORT, function () {
    var host = server.address().address;
    var port = server.address().port;

    console.log('my app is listening at http://%s:%s', host, port);
});

const testnetChains = {
    "0002": {"name": "Pokt", "type": "pokt"},
    "0020": {"name": "Goerli", "type": "ethereum"},
    "0022": {"name": "Rinkeby", "type": "ethereum"},
    "0023": {"name": "Ropsten", "type": "ethereum"},
};

const mainnetChains = {
    "0001": {"name": "Pokt", "type": "pokt"},
    "0003": {"name": "Avalanche", "type": "avalanche"},
    "0004": {"name": "BSC Mainnet", "type": "ethereum"},
    "0009": {"name": "Polygon Mainnet", "type": "ethereum"},
    "0010": {"name": "BSC Archival", "type": "ethereum"},
    "0021": {"name": "Ethereum", "type": "ethereum"},
    "0022": {"name": "Ethereum Archival", "type": "ethereum"},
    "0026": {"name": "Goerli", "type": "ethereum"},
    "0027": {"name": "Gnosis Chain", "type": "ethereum"},
    "0028": {"name": "Ethereum Archival Trace", "type": "ethereum"},
    "0052": {"name": "NEAR", "type": "near"},
    "0053": {"name": "Optimism", "type": "ethereum"},
    "0063": {"name": "Goerli Archival", "type": "ethereum"},
    "0066": {"name": "Arbitrum One", "type": "ethereum"},
    "0077": {"name": "Sepolia", "type": "ethereum"},
    "0078": {"name": "Sepolia Archival", "type": "ethereum"},
    "0079": {"name": "Base Mainnet", "type": "ethereum"},
    "0080": {"name": "Base Testnet (Goerli)", "type": "ethereum"},
    "0081": {"name": "Holesky Full Node", "type": "ethereum"},
    "000B": {"name": "Polygon Archival", "type": "ethereum"},
    "000C": {"name": "Gnosis Chain Archival", "type": "ethereum"},
    "000F": {"name": "Polygon Mumbai", "type": "ethereum"},
    "03DF": {"name": "EVM AVAX DFK Subnet", "type": "avalanche"},
    "A003": {"name": "Avalanche Archival", "type": "avalanche"},
    "A053": {"name": "Optimism Archival", "type": "ethereum"},
    "B021": {"name": "Ethereum Beacon", "type": "beacon"},
    "B081": {"name": "Holesky Beacon", "type": "beacon"},
};
