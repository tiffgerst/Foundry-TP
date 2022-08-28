//SPDX-License-Identifier:MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TRSYERC20 is ERC20 {
    constructor () ERC20("ASTreasury", "TRSY")  {
    }
    function mint(address receiver, uint256 amt) public {
        _mint(receiver, amt);
    }
    function burn (address user, uint256 amt) public {
        _burn(user, amt);
    }
}