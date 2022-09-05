// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {InitState} from "./ContractState.sol";
import "forge-std/Test.sol";
import "../src/interfaces/ITokenPool.sol";
import "../src/interfaces/IRegistry.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract TestMultiPools is InitState {
    uint256 constant PRECISION = 1e6;
    function testOwnWithdraw() public {
        uint[3] memory amountA = [uint256(10e18), uint256(20e18), uint256(50e18)];
        uint total = 0;
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            uint tokens = trsy.getTokenAmount(amountA[i],pools[i]);
            vm.prank(user1);
            trsy.deposit(tokens,tokenAddress[i]);
            vm.prank(user2);
            trsy.deposit(tokens,tokenAddress[i]);
            total += 2 * amountA[i];
    }   
        uint idk = trsy.getTokenAmount(100e18, pools[1]);
        assertApproxEqRel(100e18, ITokenPool(pools[1]).getDepositValue(idk), 1e6);
        emit log_named_uint("Concentration of Pool 0, pre-withdrawal",registry.getConcentration(pools[0]));
        emit log_named_uint("Concentration of Pool 1, pre-withdrawal",registry.getConcentration(pools[1]));
        emit log_named_uint("Concentration of Pool 2, pre-withdrawal",registry.getConcentration(pools[2]));

        assertApproxEqRel(registry.getTotalAUMinUSD(),total,1e18);
        assertApproxEqRel(token.balanceOf(user1),trsy.getTRSYAmount(800e18),1e18);
        assertApproxEqRel(token.totalSupply(),total, 1e18);
        assertEq(registry.getConcentration(pools[0]),125000); //1/8
        assertEq(registry.getConcentration(pools[1]),250000);
        vm.prank(user1);
        trsy.withdraw(10e18);
        emit log_named_uint("Concentration of Pool 0, post-withdrawal #1",registry.getConcentration(pools[0]));
        emit log_named_uint("Concentration of Pool 1, post-withdrawal #1",registry.getConcentration(pools[1]));
        emit log_named_uint("Concentration of Pool 2, post-withdrawal #1",registry.getConcentration(pools[2]));
        assertApproxEqRel(ITokenPool(pools[0]).getPoolValue(), ITokenPool(pools[0]).getDepositValue(2* 100e18),1e18);
        assertApproxEqRel(ITokenPool(pools[1]).getPoolValue(), ITokenPool(pools[1]).getDepositValue(2* 200e18),1e18);
        uint wd = token.balanceOf(user2);
        vm.prank(user2);
        trsy.withdraw(wd);
        emit log_named_uint("Concentration of Pool 0, post-withdrawal #2",registry.getConcentration(pools[0]));
        emit log_named_uint("Concentration of Pool 1, post-withdrawal #2",registry.getConcentration(pools[1]));
        emit log_named_uint("Concentration of Pool 2, post-withdrawal #2",registry.getConcentration(pools[2]));
        vm.prank(user1);
        trsy.withdraw(60e18);
        emit log_named_uint("Concentration of Pool 0, post-withdrawal #3",registry.getConcentration(pools[0]));
        emit log_named_uint("Concentration of Pool 1, post-withdrawal #3",registry.getConcentration(pools[1]));
        emit log_named_uint("Concentration of Pool 2, post-withdrawal #3",registry.getConcentration(pools[2]));
}

}

