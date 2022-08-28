//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

//import "./interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenPool{
IERC20 public token;
address public chainlinkfeed;
uint256 public targetconcentration;
AggregatorV3Interface public oracle;
uint256 public decimal;

constructor (address _tokenAddress, address _chainlinkfeed, uint256 _targetconcentration, uint256 _decimal)  {
    token = IERC20(_tokenAddress);
    chainlinkfeed = _chainlinkfeed;
    oracle = AggregatorV3Interface(_chainlinkfeed);
    targetconcentration = _targetconcentration;
    decimal = _decimal;

}
function getPrice() public view returns (uint256){
    (,int256 price, , , ) = oracle.latestRoundData();
    uint256 decimals = oracle.decimals();
    return uint256(price) * (10**(18-decimals));
}

function getPoolValue() external view returns(uint256, uint256){
    uint256 price = getPrice();
    return ((token.balanceOf(address(this)) * price)/10**decimal, targetconcentration);
}

function getDepositValue(uint256 _amount) external view returns(uint256, uint256){
    uint256 price = getPrice();
    return ((_amount * price) / (10 ** decimal), targetconcentration);
}

function withdrawToken(address receiver, uint256 amount) external  {
    bool success = token.transfer(receiver, amount);
    require(success);
}
}





