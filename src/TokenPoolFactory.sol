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
function deployTokenPool(address tokenAddress, address chainlinkfeed, uint256 targetconcentration, uint256 decimal) public {
    require(msg.sender == owner, "Only the owner can deploy a token pool");
    address poolAddress = address(new TokenPool(tokenAddress, chainlinkfeed, targetconcentration, decimal));
    IRegistry(registry).addTokenPool(poolAddress, tokenAddress, targetconcentration);
    emit TokenPoolDeployed(poolAddress, tokenAddress);
}

}
