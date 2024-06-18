import { Badge } from "react-bootstrap";
import { FaWallet, FaClock } from "react-icons/fa";
import { Account } from '../../../types';
import { upoktToPokt } from '../../../utils';

import "./Wallet.scss";

export default function Wallet({
  account,
}: {
  account: Account | undefined;
}) {

  function shortenAddress(address: string) {
    return address.substring(0, 4) + "..." + address.substring(address.length - 4);
  }

  return (
    <div className="wallet">
      {account && (
        <>
          <h4>
            <Badge>
              <FaWallet /> {shortenAddress(account.address)}
            </Badge>
          </h4>
          <h4>
            {account.unstakingTime !== '0001-01-01T00:00:00Z' && <Badge> <FaClock />  Unstaked Date: {account.unstakingTime}</Badge>}
          </h4>
          <h4>
            <Badge> {account.jailed ? "Jailed" : "Not Jailed"}</Badge>
          </h4>
          <h4>
            <Badge> {account.network}</Badge>
          </h4>
          <h4>
            {account.amount ? <Badge>{upoktToPokt(account.amount).toFixed(2)} POKT</Badge> : <Badge>Unknown</Badge>}
          </h4>
        </>
      )}
    </div>
  );
}