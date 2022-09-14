import logo from "../img/logo.svg";
import styles from "./navbar.module.scss";
import { useEthers } from "@usedapp/core";

function Navbar() {
  const { account, activateBrowserWallet, deactivate } = useEthers();

  const isConnected = account !== undefined;

  return (
    <div>
      <header>
        <a className={styles.logo} href="/">
          <img src={logo} alt="logo" />
        </a>
        <nav>
          <ul className={styles.nav__links}>
            <li>
              <a>Deposit</a>
            </li>
            <li>
              <a>Withdraw</a>
            </li>
            <li>
              <a>Incentive</a>
            </li>
            <li>
              <a>My Account</a>
            </li>
            <li>
              {isConnected ? (
                <button
                  className={styles.draw}
                  onClick={deactivate}
                  id={styles.deactivate}
                >
                  Disconnect
                </button>
              ) : (
                <button
                  className={styles.draw}
                  color="primary"
                  onClick={() => activateBrowserWallet()}
                >
                  Connect
                </button>
              )}{" "}
            </li>
          </ul>
        </nav>
      </header>
    </div>
  );
}

export default Navbar;
