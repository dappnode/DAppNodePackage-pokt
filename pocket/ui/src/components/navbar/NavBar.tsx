import React from "react";
import { Navbar, Container } from "react-bootstrap";
import Wallet from "./wallet/Wallet";
import { Account } from "../../types";
import "./NavBar.scss";

export default function NavBar({
  account
}: {
  account: Account | undefined;
}) {
  return (
    <Container className="navbar">
      <Navbar.Brand>
        <h4>
          <img alt="" src="/dappnode-logo.svg" /> Validator
        </h4>
      </Navbar.Brand>

      {/* {ethereumProviderAtr.selectedAddress && gnoSmartContract && mGnoSmartContract && ( */}
        <Wallet
          account={account}
          // ethereumProviderAtr={ethereumProviderAtr}
          // gnoSmartContract={gnoSmartContract}
          // mGnoSmartContract={mGnoSmartContract}
          // gnoBlance={gnoBlance}
          // setGnoBalance={setGnoBalance}
          // mGnoBalance={mGnoBalance}
          // setMgnoBalance={setMgnoBalance}
        />
      {/* )} */}
    </Container>
  );
}
