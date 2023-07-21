import React, { useEffect, useState } from "react";
import { Button, Form } from "react-bootstrap";
import NavBar from "./components/navbar/NavBar";
import Footer from "./components/footer/Footer";
import { AppService } from './services/app.service';
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
      setAmountToStake(account.amountStaked > 0 ? (account.amountStaked / 1000000) : 0);
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
        } else if (chain.name.toLowerCase() === 'pokt') {
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

  const stake = async () => {
    try {
      setTxhash(null);
      if ((amountToStake ?? 0) < 15100) {
        throw new Error(`Minimum amount to stake is 15100 POKT`);
      }
      if ((amountToStake ?? 0) > ((Number(account?.amount ?? 0) + Number(account?.amountStaked ?? 0)) / 1000000) - 1) {
        throw new Error(`You do not have enough POKT to stake`);
      }
      const responseStake = await appService.stake(amountToStake ?? 0, Array.from(selectedChains.keys()).join(','));
      console.log(responseStake);
      if (!(responseStake.code) && !(responseStake.raw_log) && responseStake.txhash) {
        toast.success(`It can take 15+ minutes for the next block to process on the Pocket blockchain. This means you will likely have to wait 15+ minutes before your validator will be active.`);
        setTxhash(responseStake.txhash);
        await replaceChains();
        return;
      }
      throw new Error(`Error while staking: ${JSON.stringify(responseStake)}`);
    } catch (e) {
      toast.error((e as Error).message);
      console.error(e);
    }
  }

  const unstake = async () => {
    try {
      setTxhash(null);
      if (account && ((account.amountStaked) < 0)) {
        throw new Error(`You do not have any POKT staked`);
      }
      const responseUnstake = await appService.unstake();
      console.log(responseUnstake);
      if (!(responseUnstake.code) && !(responseUnstake.raw_log) && responseUnstake.txhash) {
        toast.success(`It can take 15+ minutes for the next block to process on the Pocket blockchain. This means you will likely have to wait 15+ minutes before your validator will begin Unstaking.`);
        setTxhash(responseUnstake.txhash);
        await replaceChains();
        return;
      }
      throw new Error(`Error while unstaking: ${JSON.stringify(responseUnstake)}`);
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

  const chainState = (state: number) => {
    switch (state) {
      case 1: return "Syncing";
      case 2: return "Running";
      default: return "Not installed";
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
            <Form.Label>Current block height</Form.Label>
            <Form.Control
              type="text"
              placeholder="Current block height"
              value={currentBlock ?? 'Unknown'}
              disabled={true}
              readOnly={true}
            />
            <Form.Text>
              Current synced block in Dappnode
            </Form.Text>
          </div>
          <div>
            <Form.Label>Address</Form.Label>
            <Form.Control
              type="text"
              placeholder="Validator address"
              value={account?.address ?? 'Unknown'}
              disabled={true}
              readOnly={true}
            />
            <Form.Text>
              Target Address to stake
            </Form.Text>
          </div>
          <div>
            <Form.Label>Amount {(account?.amountStaked ?? 0) > 0 ? `(Staked: ${(account?.amountStaked ?? 0) / 1000000} POKT)` : ``}</Form.Label>
            <Form.Control
              type="number"
              onChange={(e) => setAmountToStake(parseInt(e.target.value))}
              placeholder="Amount to stake"
              value={amountToStake ?? 0}
              minLength={5}
            />
            <Form.Text>
              The amount of POKT to stake. Must be higher than the current value of the StakeMinimum parameter, found <a href="https://docs.pokt.network/learn/economics/nodes/#node-staking" target="_blank" rel="noreferrer">here</a>.
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
                  disabled={chain.name.toLowerCase() === 'pokt' ? true : chain.state !== 2}
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
              Ensure the node is all the way synced before proceeding to stake the validator.
            </Form.Text>
            </div>
            <div>
            <Form.Text>
              You can ensure your node is fully synced by checking the block height at <a href="https://explorer.pokt.network" target="_blank" rel="noreferrer">https://explorer.pokt.network</a>
            </Form.Text>
            </div>
            <div>
            <Form.Text>
              More info <a href="https://docs.pokt.network/home/paths/node-runner#stake-the-validator" target="_blank" rel="noreferrer">here</a>.
            </Form.Text>
            </div>
            </div>
            <div>
              <Button
                onClick={() => stake()}
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
              Stake =  Stake node for the first time. Re-stake = stake node again after changing staked chains or the amount of Pokt staked.
            </Form.Text>
            </div>
          </div>
          <div>
            <div>
              <div>
              <Form.Label>Before Un-staking</Form.Label>
              </div>
              <div>
              <Form.Text>
                Remember it takes 21 days to unstake your node.
              </Form.Text>
              </div>
              <div>
              <Form.Text>
                More info <a href="https://docs.pokt.network/node/staking/#unstaking" target="_blank" rel="noreferrer">here</a>.
              </Form.Text>
              </div>
              </div>
              <div>
                <Button
                  onClick={() => unstake()}
                  disabled={(currentBlock ?? 0) === 0}
                >{account?.node ?? `Un-Stake`}</Button>
                {txhash && (
                  <Form.Text>
                    {` `}Tx: {txhash}
                  </Form.Text>
                )}
                {(currentBlock ?? 0) === 0 && (
                  <Form.Text>
                    {` `}(Not Staked)
                  </Form.Text>
                )}
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
