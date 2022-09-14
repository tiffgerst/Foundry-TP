// import { Button, makeStyles } from "@material-ui/core";
import React from "react";
import { useEthers } from "@usedapp/core";

// const useStyles = makeStyles((theme) => ({
//   container: {
//     padding: theme.spacing(4),
//     display: "flex",
//     justifyContent: "flex-end",
//     gap: theme.spacing(1),
//   },
// }));

export const Header = () => {
  //   const classes = useStyles();

  const { account, activateBrowserWallet, deactivate } = useEthers();

  const isConnected = account !== undefined;

  return (
    <div>
      {/* //className={classes.container}> */}
      {isConnected ? (
        <button onClick={deactivate}>Disconnect</button>
      ) : (
        <button color="primary" onClick={() => activateBrowserWallet()}>
          Connect
        </button>
      )}
    </div>
  );
};
