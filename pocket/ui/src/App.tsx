import React, { useEffect, useState } from "react";
import { Button, Form } from "react-bootstrap";
import NavBar from "./components/navbar/NavBar";
import Footer from "./components/footer/Footer";
import { AppService } from './services/app.service';
import { upoktToPokt } from "./utils";
// Styles
import "./App.scss";
import "bootstrap/dist/css/bootstrap.css";
import { Account, Chain } from "./types";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

function App() {
  const [account, setAccount] = useState<Account>();
  const [availableChains, setAvailableChains] = useState<[Chain]>();
  const [currentBlock, setCurrentBlock] = useState<number | null>(null);
  const [amountToStake, setAmountToStake] = useState<number | null>(null);
  const [selectedChains, setSelectedChains] = useState(new Map());
  const [first, setFirst] = useState(true);
  const [txhash, setTxhash] = useState<string | null>(null);
  
  const appService = new AppService();
  toast.configure();

  const getAccount = async () => {
    const account = await appService.getAccount();
    setAccount(account);
    if (amountToStake) {} 
    else { 
      setAmountToStake(account.amountStaked > 0 ? upoktToPokt(account.amountStaked) : 0);
    }
    if (account && account.initialized) {
      try {
        await getAvailableChains(account);
      } catch (e) {
        toast.error((e as Error).message);
        console.error(e);
      }
    }
  }

  const getAvailableChains = async (currentAccount: Account) => {
    const chains = await appService.getAvailableChains();
    if (selectedChains.keys.length > 0 || !first) {}
    else {
      console.log(selectedChains);
      chains.forEach((chain: Chain) => {
        if (currentAccount?.node && currentAccount.node.chains.includes(chain.id)) {
          handleChange(chain.id, true);
        }
      });
      setAvailableChains(chains);
    }
    setFirst(false);
  }

  const getCurrentBlock = async () => {
    const block = await appService.getCurrentBlock();
    setCurrentBlock(block);
  }

  const replaceChains = async () => {
    const block = await appService.replaceChains(Array.from(selectedChains.keys()).join(','));
    setCurrentBlock(block);
  }

  const unjailNode = async () => {
    try {
      setTxhash(null);
      if (account?.jailed === false) {
        throw new Error("Your Node is not jailed, you cannot Unjail your Node");
      }
      const responseUnjailNode = await appService.unjailNode();
      console.log(responseUnjailNode);
      if (!(responseUnjailNode.code) && !(responseUnjailNode.raw_log) && responseUnjailNode.txhash) {
        toast.success("It can take 15+ minutes for the next block to process on the Pocket blockchain. This means you may have to wait 15+ minutes before your validator will become active again when the Unjail Tx is broadcast to the network and included in a block.");
      setTxhash(responseUnjailNode.txhash);
      //await getAccount();
      await getCurrentBlock();
      return;
      }
      throw new Error(`Error while Unjailing Node: ${JSON.stringify(responseUnjailNode.raw_log)}`);
    } catch (e) {
      toast.error((e as Error).message);
      console.error(e);
    }
  }

  const stakeCustodial = async () => {
    try {
      setTxhash(null);
      if (account?.jailed === true) {
        throw new Error("Your Node is jailed, you must Unjail your Node before Staking/Re-Staking");
      }
      if ((amountToStake ?? 0) <= 15001) {
        throw new Error(`Minimum amount to stake is 15,001 POKT`);
      }
      if ((amountToStake ?? 0) > upoktToPokt(Number(account?.amount ?? 0) + Number(account?.amountStaked ?? 0)) - 1) {
        throw new Error(`You do not have enough POKT to stake`);
      }
      if ((amountToStake ?? 0) < upoktToPokt(Number(account?.amountStaked ?? 0))) {
        throw new Error(`You cannot Re-Stake below the amount you have already staked, you can only Re-Stake the same amount you have staked with different selected chains to relay, and/or increase the amount to stake, you muust UnStake your node to withdraw your Staked POKT, a process that takes 21 days to complete.`);
      }
   if (selectedChains.keys.length > 15) {
       throw new Error(`You cannot stake more than 15 chains at a time`);
      }
      const responseStakeCustodial = await appService.stakeCustodial(amountToStake ?? 0, Array.from(selectedChains.keys()).join(','));
      console.log(responseStakeCustodial);
      if (!(responseStakeCustodial.code) && !(responseStakeCustodial.raw_log) && responseStakeCustodial.txhash) {
        toast.success(`It can take 15+ minutes for the next block to process on the Pocket blockchain. This means you may have to wait 15+ minutes before your validator will be active when staking for the first time, and similarly while re-staking, chainging selected chains or amounts, etc.`);
        setTxhash(responseStakeCustodial.txhash);
        await replaceChains();
        return;
      }
      throw new Error(`Error while staking: ${JSON.stringify(responseStakeCustodial)}`);
    } catch (e) {
      toast.error((e as Error).message);
      console.error(e);
    }
  }

  function handleChange(id:string, isChecked: boolean) {
    let modifiedMap = selectedChains;
    if(modifiedMap?.get(id) && !isChecked) {
        modifiedMap?.delete(id)
    } else {
        modifiedMap?.set(id, true);
    }
    setSelectedChains(modifiedMap);
    console.log(modifiedMap);
  }

  /**
   * Check wallet balance every 30s
   */
  /**ESlint */
  useEffect(() => {
    async function getBalance() {
      try {
        await getCurrentBlock();
        await getAccount();
      } catch (e) {
        // toast.error((e as Error).message);
        console.error(e);
      }
    }
    getBalance();

    // Get balance every 30s
    const interval = setInterval(async () => {
      await getBalance();
    }, 30 * 1000);
    return () => {
      clearInterval(interval);
    };
  }, [first, selectedChains, txhash]);
  // }, [first, selectedChains, txhash, getCurrentBlock, getAccount]);
//

  const chainState = (state: number) => {
    switch (state) {
      case 1: return "Syncing";
      case 2: return "Running";
      case 3: return "Running but Pruned; Cannot Relay";
      default: return "Not Installed";
    }
  }

  return (
    <div className="App">
      <NavBar
        account={account}
      />

      <div className="content">
        <Form.Group controlId="formValidator" className="mb-3">
          <div>
            <Form.Label>Current Block Height</Form.Label>
            <Form.Control
              type="text"
              placeholder="Current Local Node Block Height"
              value={currentBlock ?? 'Unknown'}
              disabled={true}
              readOnly={true}
            />
            <Form.Text>
              Current Highest Synced Block In This Dappnode Pokt Node
            </Form.Text>
          </div>
          <div>
            <Form.Label>Address</Form.Label>
            <Form.Control
              type="text"
              placeholder="Validator Address"
              value={account?.address ?? 'Unknown'}
              disabled={true}
              readOnly={true}
            />
            <Form.Text>
              Target Address To Stake
            </Form.Text>
          </div>
          <div>
            <Form.Label>Amount {(account?.amountStaked ?? 0) > 0 ? `(Staked: ${upoktToPokt(account?.amountStaked ?? 0)} POKT)` : ``}</Form.Label>
            <Form.Control
              type="number"
              onChange={(e) => setAmountToStake(parseInt(e.target.value))}
              placeholder="Amount to stake"
              value={amountToStake ?? 0}
              minLength={5}
            />
            <Form.Text>
              The amount of POKT to stake. Must be higher than the current value of the StakeMinimum parameter, found <a href="https://docs.pokt.network/node-operators/manual-node-setup-guide/part-5-going-live#staking-your-node" target="_blank" rel="noreferrer">here</a>.
            </Form.Text>
          </div>
          <div>
            <Form.Label>Select Chains</Form.Label>
            {
              availableChains?.map((chain: Chain) => (
                <Form.Check
                  key={chain.id}
                  onChange={e => {handleChange(chain.id, e.target.checked)}}
                  defaultChecked={selectedChains?.get(chain.id) ?? false}
                  label={`${chain.name} - ${chainState(chain.state)}`}
                  disabled={chain.state !== 2}
                />
              ))
            }
          </div>
        <div>
          <div>
            <div>
            <Form.Label>Before staking</Form.Label>
            </div>
            <div>
            <Form.Text>
              You should leave 1 POKT liquid (unstaked) to pay the transaction fees for your node's claim and proof transactions.
            </Form.Text>
            </div>
            <div>
            <Form.Text>
              Ensure your Pokt Chain is fully synced before proceeding to stake the validator.
            </Form.Text>
            </div>
            <div>
            <Form.Text>
              You can ensure your node is fully synced by checking the block height at <a href="https://poktscan.com" target="_blank" rel="noreferrer">PoktScan</a>
            </Form.Text>
            </div>
            <div>
            <Form.Text>
              More info <a href="https://docs.pokt.network/node-operators/manual-node-setup-guide/part-5-going-live#staking-your-node" target="_blank" rel="noreferrer">here</a>.
            </Form.Text>
            </div>
            </div>
            <div>
              <Button
                onClick={() => stakeCustodial()}
                disabled={(currentBlock ?? 0) === 0}
              >{account?.node ? `Re-stake` : `Stake`}</Button>
              {txhash && (
                <Form.Text>
                  {` `}Tx: {txhash}
                </Form.Text>
              )}
              {(currentBlock ?? 0) === 0 && (
                <Form.Text>
                  {` `}(Syncing...)
                </Form.Text>
              )}
            </div>
            <div>
            <Form.Text>
              Stake = Initial Stake. Re-stake = staking again after changing chains or amount of Pokt staked.
            </Form.Text>
          </div>
          <div>
            <Button
              onClick={() => unjailNode()}
              disabled={!account?.jailed || (currentBlock ?? 0) === 0}
            >Unjail Node</Button>
            {txhash && (
              <Form.Text>
                {` `}Tx: {txhash}
              </Form.Text>
            )}
          </div>
          <div>
            <Form.Text>
              Ensure your Pokt node is fully synced then submit a request to Unjail your node using the Unjail button above, so that it will be allowed to participate in relaying and earn rewards again.
            </Form.Text>
          </div>
          </div>
        </Form.Group>

      </div>

      <Footer />
      <ToastContainer
        position="bottom-center"
        pauseOnHover={true}
        autoClose={5000}
        hideProgressBar={false}
        newestOnTop={false}
        rtl={false}
        pauseOnFocusLoss
        draggable
        theme="colored" />
    </div>
  );
}

export default App;
