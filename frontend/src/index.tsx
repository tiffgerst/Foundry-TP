import React from "react";
import ReactDOM from "react-dom/client";
import "./index.css";
import App from "./App";
import reportWebVitals from "./reportWebVitals";
import { getDefaultProvider } from "ethers";
import { formatEther } from "@ethersproject/units";
import {
  Mainnet,
  DAppProvider,
  useEtherBalance,
  useEthers,
  Config,
  Goerli,
  Kovan,
} from "@usedapp/core";

const root = ReactDOM.createRoot(
  document.getElementById("root") as HTMLElement
);
const config: Config = {
  readOnlyChainId: Mainnet.chainId,
  readOnlyUrls: {
    [Mainnet.chainId]: getDefaultProvider("mainnet"),
    [Goerli.chainId]: getDefaultProvider("goerli"),
    [Kovan.chainId]: getDefaultProvider("kovan"),
  },
};
root.render(
  <DAppProvider config={config}>
    <App />
  </DAppProvider>
);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
