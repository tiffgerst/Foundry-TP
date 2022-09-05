// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {InitState} from "./ContractState.sol";
import "forge-std/Test.sol";
import "../src/Treasury.sol";


contract TestTreasury is InitState {
    function testCannotDepositZero() public {
        vm.expectRevert(bytes("Amount must be greater than $1"));
        vm.startPrank(user1);
        trsy.deposit(0,tokenAddress[0]);
    }

    function testCannotWithdrawMoreThanBalance() public {
        vm.startPrank(user1);
        trsy.deposit(10e18,tokenAddress[0]);
        uint256 tsryBalance = token.balanceOf(user1);
        emit log_uint(tsryBalance);
        vm.expectRevert(abi.encodeWithSelector(Treasury.InsufficientBalance.selector, tsryBalance, tsryBalance * 2));
        trsy.withdraw(tsryBalance * 2);
    }

    function testCannotWithdrawZero() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes("Amount must be greater than 0"));
        trsy.withdraw(0);
    }

    function testAll() public {
        //address pool = registry.tokenToPool(tokenAddress[0]);
        uint price = tokenPools[0].getPrice();
        emit log_uint(price);
        uint hi= ITokenPool(pools[1]).getPoolValue();
        emit log_uint(hi);
    }

}
