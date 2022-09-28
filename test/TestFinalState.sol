pragma solidity ^0.8.12;

import {FinalState} from "./ContractState.sol";
import "forge-std/Test.sol";
import "../src/interfaces/ITokenPool.sol";
import "../src/interfaces/IRegistry.sol";
import"../src/Treasury.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TestAll is FinalState {
    function testIt() public {
        emit log_named_uint("Concentration of Pool 0",registry.getConcentration(pools[0]));
        emit log_named_uint("Concentration of Pool 1",registry.getConcentration(pools[1]));
        emit log_named_uint("Concentration of Pool 2",registry.getConcentration(pools[2]));
        assertEq(trsy.getIncentiveStatus(),0);
        vm.prank(user3);
        trsy.depositIncentive(5000e18, tokenAddress[0]);
        vm.prank(user1);
        trsy.withdraw(2000e18);
        vm.prank(user4);
        trsy.depositIncentive(9000e18, tokenAddress[0]);
        vm.prank(deployer);
        trsy.closeIncentive();
        assertEq(trsy.getIncentiveStatus(),1);
        vm.prank(user1);
        trsy.withdraw(4000e18);
        vm.prank(user2);
        trsy.deposit(30e18, tokenAddress[1]);
        assertEq(trsy.getIncentiveStatus(),0);
        emit log_uint(token.balanceOf(address(trsy))/1e18);

        emit log_named_uint("Concentration of Pool 0",registry.getConcentration(pools[0]));
        emit log_named_uint("Concentration of Pool 1",registry.getConcentration(pools[1]));
        emit log_named_uint("Concentration of Pool 2",registry.getConcentration(pools[2]));

    }

}
