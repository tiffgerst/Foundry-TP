//SPDX-License-Identifier:MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TRSYERC20 is ERC20 {

    constructor () ERC20("ASTreasury", "TRSY")  {
    }
    
    /** @dev Create own mint function as token is only minted upon depositing, not upon creation of the token contract
    @param receiver - who to send minted tokens to
    @param amt - how many tokens to mint */

    function mint(address receiver, uint256 amt) public {
        _mint(receiver, amt);
    }
    /** @dev function to burn tokens from a specific address
    @param user - the user whose tokens are to be burned
    @param amt - how many tokens are to be burned */

    function burn (address user, uint256 amt) public {
        _burn(user, amt);
    }
}