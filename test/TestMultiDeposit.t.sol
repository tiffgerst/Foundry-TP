// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {MultiDepositState} from "./ContractState.sol";
import "forge-std/Test.sol";
import "../src/interfaces/ITokenPool.sol";
import "../src/interfaces/IRegistry.sol";
import"../src/Treasury.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract TestMultiPools is MultiDepositState {
    uint256 constant PRECISION = 1e6;
    function testRebalance() public {
        uint tknamt = trsy.getTokenAmount(100e18, pools[1]);
        assertApproxEqRel(100e18, ITokenPool(pools[1]).getDepositValue(tknamt), 1e6);
        emit log_named_uint("Concentration of Pool 0, pre-withdrawal",registry.getConcentration(pools[0]));
        emit log_named_uint("Concentration of Pool 1, pre-withdrawal",registry.getConcentration(pools[1]));
        emit log_named_uint("Concentration of Pool 2, pre-withdrawal",registry.getConcentration(pools[2]));
        emit log_named_uint("Tax accrued: $", token.balanceOf(address(trsy)));
        emit log_named_uint("Total TRSY supply: $", token.totalSupply());
        emit log_named_uint("User1 TRSY balance: $", token.balanceOf(user1));
        emit log_named_uint("User2 TRSY balance: $", token.balanceOf(user2));

        assertApproxEqRel(registry.getTotalAUMinUSD(),total,1e18);
        assertApproxEqRel(token.balanceOf(user1),trsy.getTRSYAmount(800e18),1e18);
        assertApproxEqRel(token.totalSupply(),total, 1e18);
        assertEq(registry.getConcentration(pools[0]),125000); //1/8
        assertEq(registry.getConcentration(pools[1]),250000);
        vm.prank(user1);
        trsy.withdraw(10e18);
        uint tax = trsy.calculateTax(10e18, user1);

        emit log_named_uint("Concentration of Pool 0, post-withdrawal #1",registry.getConcentration(pools[0]));
        emit log_named_uint("Concentration of Pool 1, post-withdrawal #1",registry.getConcentration(pools[1]));
        emit log_named_uint("Concentration of Pool 2, post-withdrawal #1",registry.getConcentration(pools[2]));
        assertApproxEqRel(ITokenPool(pools[0]).getPoolValue(), 2* 10e18,1e15);
        assertApproxEqRel(ITokenPool(pools[1]).getPoolValue(), 2* 20e18,1e15);
        assertApproxEqRel(ITokenPool(pools[2]).getPoolValue(), 2* 50e18-10e18+tax,1e15);
        uint wd = token.balanceOf(user2);
        vm.prank(user2);
        trsy.withdraw(wd);
        emit log_named_uint("Concentration of Pool 0, post-withdrawal #2",registry.getConcentration(pools[0]));
        emit log_named_uint("Concentration of Pool 1, post-withdrawal #2",registry.getConcentration(pools[1]));
        emit log_named_uint("Concentration of Pool 2, post-withdrawal #2",registry.getConcentration(pools[2]));
        assertApproxEqRel(ITokenPool(pools[2]).getPoolValue(), 2* 50e18-10e18+tax-wd+trsy.calculateTax(wd, user2),1e15);
        vm.prank(user1);
        trsy.withdraw(65e18);
        emit log_named_uint("Concentration of Pool 0, post-withdrawal #3",registry.getConcentration(pools[0]));
        emit log_named_uint("Concentration of Pool 1, post-withdrawal #3",registry.getConcentration(pools[1]));
        emit log_named_uint("Concentration of Pool 2, post-withdrawal #3",registry.getConcentration(pools[2]));    }
    
    function testTax() public {
        vm.rollFork(block.number - 300000);
        emit log_uint(block.timestamp);
        vm.prank(user1);
        trsy.deposit(200e18,tokenAddress[1]);
        vm.rollFork(block.number + 7000);
        emit log_uint(block.timestamp);
        vm.prank(user1);
        trsy.withdraw(100e18);
        uint tax = trsy.calculateTax(100e18, user1);
        assertApproxEqRel(tax, 2.43e19, 1e18);
        // block.timestamp -  trsy.timestamp(user1) = 93088
        // 93088 / 86400 = 1.08 days
        //100 * 0.05 + abs((1.08 * 200000 /30) + 200000) * 100 / 1e6
        //5e18 + 192,817.2839506173 * 100e18 / 1e6
        //5e18 + 1.93e19 = 2.43 e19
    }   

    function testGetConcentration() public {
        assertEq(registry.getConcentration(pools[0]),125000); 
        //Total AUM = 160e18
        //Pool 0 = 20e18
        //20/160 = 0.125 or 12.5%
    }
    
    function testgetNewConcentration() public{
        assertEq(registry.getNewConcentration(pools[0], 40e18), 300000);
    }
    //Total AUM = 160e18
        //Pool 0 = 20e18
        // + 40e18 makes new AUM 200e18, Pool0 AUM = 60, 60/200 = 0.3 or 30%
    
    function testFuzzTax(uint256 forkroll) public{
        vm.rollFork(block.number - 60 days);
        vm.assume(forkroll<60 days);
        vm.prank(user1);
        trsy.deposit(200e18,tokenAddress[1]);
        vm.rollFork(block.number + forkroll);
        vm.prank(user1);
        trsy.withdraw(100e18);
        uint time = block.timestamp - trsy.timestamp(user1);
        int numdays = int(time / 86400);
        uint tax = trsy.calculateTax(100e18, user1);
        emit log_uint(time);
        if (numdays > 30) {
            assertEq(tax, 100e18 * 10000/PRECISION);
        }
        else {
            int percent =  0 - (numdays * 200000 / 30 - 200000);
            uint calc = 100e18 * 10000 / PRECISION + 100e18 * uint(percent) / PRECISION;
            assertApproxEqRel(tax, calc, 1e5);
        }
    }
    
    
    
    }

  
  