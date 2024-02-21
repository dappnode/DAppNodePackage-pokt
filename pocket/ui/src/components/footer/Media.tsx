import React from "react";
import { FaDiscord, FaDiscourse, FaGithub, FaTwitter } from "react-icons/fa";

export default function Media() {
  return (
    <div className="footer-media">
      <a href="https://github.com/dappnode/DAppNodePackage-pokt">
        <FaGithub />
      </a>
      <a href="https://discord.gg/dappnode">
        <FaDiscord />
      </a>
      <a href="https://twitter.com/dappnode">
        <FaTwitter />
      </a>
      <a href="https://discourse.dappnode.io/">
        <FaDiscourse />
      </a>
    </div>
  );
}
