//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

//import "./interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenPool{
//variables
IERC20 public immutable token;
address public chainlinkfeed;
uint256 public targetconcentration;
AggregatorV3Interface public oracle;
uint256 public decimal;

//constructor
constructor (address _tokenAddress, address _chainlinkfeed, uint256 _targetconcentration, uint256 _decimal)  {
    token = IERC20(_tokenAddress);
    chainlinkfeed = _chainlinkfeed;
    oracle = AggregatorV3Interface(_chainlinkfeed);
    targetconcentration = _targetconcentration;
    decimal = _decimal;

}
/** 
@dev function to get current price of the token from the oracle 
returns the price of the token in USD with 18 decimals 
(token has 18 decimals, oracle has 8 decimals, so we multiply by 10^10 to make oracle price same decimals as token) )
 */
function getPrice() public  view returns (uint256){
    (,int256 price, , , ) = oracle.latestRoundData();
    uint256 decimals = oracle.decimals();
    return (uint256(price) * (10**(18-decimals)));
}

/**
@dev function to get the current pool value in USD
Multiplies the price of the token by number of tokens in the pool and divides by amount of token decimals 
 */
function getPoolValue() public view returns(uint256){
    uint256 price = getPrice();
    return ((token.balanceOf(address(this)) * price)/10**decimal);
}

/**
@dev function to get the usd value of the number of tokens someone wants to deposit
@param _amount (number of tokens to be deposited)
 */
 
function getDepositValue(uint256 _amount) external view returns(uint256){
    uint256 price = getPrice();
    return ((_amount * price) / (10 ** decimal));
}

/**
@dev function to send user tokens upon withdrawal
@param receiver - who to send the tokens to
@param amount - how much to send 
 */
function withdrawToken(address receiver, uint256 amount) external  {
    bool success = token.transfer(receiver, amount);
    require(success);
}
}





