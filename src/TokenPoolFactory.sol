//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;
import "./TokenPool.sol";
import "./interfaces/IRegistry.sol";

contract TokenPoolFactory {

//Variables
address public owner;
address public registry;

//Events
event TokenPoolDeployed(
        address indexed poolAddress,
        address tokenAddress
    );

//Constructor
constructor (address _registry) {
    owner = msg.sender;
    registry = _registry;
}

//Functions
/** @dev Function deploys a new TokenPool, and sends the address of the new TokenPool to the Registry to be added to its list
  @param tokenAddress (address of the token to be used in the TokenPool)
  @param chainlinkfeed (address of the Chainlink feed for the token, which gives its price in real time)
  @param targetconcentration (target concentration of the token in the TokenPool)
  @param decimal (number of decimals of the token; usually 18 but some ERC20 tokens have a different number of decimals)
  */
function deployTokenPool(address tokenAddress, address chainlinkfeed, uint256 targetconcentration, uint256 decimal) public {
    require(msg.sender == owner, "Only the owner can deploy a token pool");
    address poolAddress = address(new TokenPool(tokenAddress, chainlinkfeed, targetconcentration, decimal));
    IRegistry(registry).addTokenPool(poolAddress, tokenAddress, targetconcentration);
    emit TokenPoolDeployed(poolAddress, tokenAddress);
}

}
