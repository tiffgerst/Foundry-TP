// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IncentiveState} from "./ContractState.sol";
import "forge-std/Test.sol";
import "../src/interfaces/ITokenPool.sol";
import "../src/interfaces/IRegistry.sol";
import"../src/Treasury.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract TestIncentive is IncentiveState {
    uint256 constant PRECISION = 1e6;


    function testIncentivePerfectHit() public {
        token.mint(address(trsy),100e18);
    assertEq(trsy.getIncentiveStatus(),0);
    uint x = trsy.getTokenAmount(100e18, pools[1]);
    uint y = trsy.getTokenAmount(100e18, pools[2]);
    uint z = trsy.getTokenAmount(800e18, pools[0]);

    uint balanceA = token.balanceOf(user1);
    vm.prank(user1);
    trsy.depositIncentive(z, tokenAddress[0]);
    uint rewardA = trsy.getTRSYAmount((800e18+800e18*50000/PRECISION));
    assertApproxEqRel(balanceA+rewardA, token.balanceOf(user1),1e5);
    emit log_named_uint("Target: 20%, Concentration pool eth:", registry.getConcentration(pools[2]));
    emit log_named_uint("Target: 30%, Concentration pool aave:", registry.getConcentration(pools[1]));
    emit log_named_uint("Target: 50%, Concentration pool dai:", registry.getConcentration(pools[0]));
    uint rewardB = trsy.getTRSYAmount((100e18+100e18*50000/PRECISION));
    vm.prank(user3);
    trsy.depositIncentive(x, tokenAddress[1]);
    assertApproxEqRel(rewardB, token.balanceOf(user3),1e5);
    emit log_named_uint("Target: 20%, Concentration pool eth:", registry.getConcentration(pools[2]));
    emit log_named_uint("Target: 30%, Concentration pool aave:", registry.getConcentration(pools[1]));
    emit log_named_uint("Target: 50%, Concentration pool dai:", registry.getConcentration(pools[0]));
    uint postBal = token.balanceOf(address(trsy));
    uint onlyreward = trsy.getTRSYAmount(100e18*50000/PRECISION);
    vm.prank(user1);
    trsy.depositIncentive(y, tokenAddress[2]);
    emit log_named_uint("Target: 20%, Concentration pool eth:", registry.getConcentration(pools[2]));
    emit log_named_uint("Target: 30%, Concentration pool aave:", registry.getConcentration(pools[1]));
    emit log_named_uint("Target: 50%, Concentration pool dai:", registry.getConcentration(pools[0]));
    assertEq(trsy.getIncentiveStatus(),1);
    assertApproxEqRel(balanceA+rewardA+rewardB + (postBal - onlyreward)/2, token.balanceOf(user1),1e5);

    assertApproxEqRel(rewardB+(postBal - onlyreward)/2, token.balanceOf(user3),1e5);
    }
    
    function testIncentiveTimeElapse() public{ 
        
    emit log_named_uint("Target: 20%, Concentration pool eth pre deposit:", registry.getConcentration(pools[2]));
    emit log_named_uint("Target: 30%, Concentration pool aave pre deposit:", registry.getConcentration(pools[1]));
    emit log_named_uint("Target: 50%, Concentration pool dai pre deposit:", registry.getConcentration(pools[0]));
    assertEq(trsy.getIncentiveStatus(),0);
    vm.prank(user1);
    trsy.depositIncentive(800e18, tokenAddress[0]);
    vm.prank(user2);
    trsy.depositIncentive(2e18, tokenAddress[1]);
    emit log_named_uint("Target: 20%, Concentration pool eth post deposits:", registry.getConcentration(pools[2]));
    emit log_named_uint("Target: 30%, Concentration pool aave post deposits:", registry.getConcentration(pools[1]));
    emit log_named_uint("Target: 50%, Concentration pool dai post deposits:", registry.getConcentration(pools[0]));
    vm.rollFork(block.number + 2 hours);
    uint prebalt = token.balanceOf(address(trsy));
    uint prebaluser = token.balanceOf(user1);
    vm.startPrank(user1);
    trsy.depositIncentive(100e18, tokenAddress[2]);
    assertEq(prebalt, token.balanceOf(address(trsy)));
    assertEq(prebaluser, token.balanceOf(user1));
     emit log_named_uint("Target: 20%, Concentration pool eth post incentive:", registry.getConcentration(pools[2]));
    emit log_named_uint("Target: 30%, Concentration pool aave post incentive:", registry.getConcentration(pools[1]));
    emit log_named_uint("Target: 50%, Concentration pool dai post incentive:", registry.getConcentration(pools[0]));
    assertEq(trsy.getIncentiveStatus(),1);

    }

    function testIncentiveError () public{
    assertEq(trsy.getIncentiveStatus(),0);
    uint x = trsy.getTokenAmount(100e18, pools[1]);
    uint y = trsy.getTokenAmount(100e18, pools[2]);
    uint prebal = token.balanceOf(address(trsy));
    vm.expectRevert(bytes("Token is not whitelisted"));
    trsy.depositIncentive(x, address(9));
    vm.expectRevert(bytes("Amount must be greater than $1"));
    vm.prank(user1);
    trsy.depositIncentive(1e17, tokenAddress[0]);
    vm.expectRevert(bytes("Pool is already above target concentration"));
    vm.prank(user1);
    trsy.depositIncentive(y, tokenAddress[2]);
    vm.expectRevert(bytes("Amount exceeds max incentive"));
    vm.prank(user1);
    trsy.depositIncentive((prebal*PRECISION/50000 + 10e18), tokenAddress[0]);
    token.mint(address(trsy), 400e18);
    vm.expectRevert(bytes("This will make the pool too concentrated"));
    vm.prank(user1);
    trsy.depositIncentive(4000e18, tokenAddress[0]);
    }
    
    function testIncentiveTiming() public {
        uint[3] memory amountA = [uint256(900e18), uint256(1800e18), uint256(900e18)];
        uint[3] memory amountB = [uint256(900e18), uint256(2700e18), uint256(1800e18)];
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            uint tokensA = trsy.getTokenAmount(amountA[i],pools[i]);
            uint tokensB = trsy.getTokenAmount(amountB[i],pools[i]);
            vm.prank(user1);
            trsy.deposit(tokensA,tokenAddress[i]);
            vm.prank(user2);
            trsy.deposit(tokensB,tokenAddress[i]);
           
    }   
    uint endtime = block.timestamp + 2 hours;
    emit log_uint(endtime);
    uint prebal = token.balanceOf(address(trsy));
    emit log_named_uint("Prebalance", prebal/1e18);
    assertApproxEqRel(endtime, trsy.endTime(), 20);
    vm.roll(block.number + 1 hours);
    vm.prank(user1);
    trsy.deposit(100e18, tokenAddress[0]);
    assertEq(endtime, trsy.endTime());
    }
    }

