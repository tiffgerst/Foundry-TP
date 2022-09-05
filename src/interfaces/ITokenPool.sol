// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

interface ITokenPool {
    
    
    function getPoolValue() external view returns (uint256);

    function getDepositValue(uint256) external view returns (uint256);
    
    function withdrawToken(address , uint256) external ;
    
    function getPrice() external returns (uint);
}
