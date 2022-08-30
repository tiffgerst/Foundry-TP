// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IRegistry {
    function addTokenPool(address, address,uint256) external;

    function tokenToPool(address) external view returns (address);

    function getTotalAUMinUSD() external view returns (uint256);
    
    function tokensToWithdraw(uint256 _amount) external returns (address[] memory, uint256[] memory);}