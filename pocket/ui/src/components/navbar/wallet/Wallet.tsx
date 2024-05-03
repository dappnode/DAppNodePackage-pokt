import { Badge } from "react-bootstrap";
import { FaWallet } from "react-icons/fa";
import { Account } from '../../../types';
import { upoktToPokt } from '../../../Functions';

import "./Wallet.scss";

export default function Wallet({
  account,
}: {
  account: Account | undefined;
}) {
  return (
    <div className="wallet">
      {account && (
        <>
          <h4>
            <Badge>
              <FaWallet /> {account.shortAddress}
            </Badge>
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