// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {ZeroState} from "./ContractState.sol";
import "../src/TokenPool.sol";
import "forge-std/Test.sol";
import "../src/Registry.sol";
import "../src/Treasury.sol";
import "../src/TokenPoolFactory.sol";
import "./Mocks/MockERC20.sol";


///@notice This contract aim to test the params at deployment.
contract TestZeroState is ZeroState {
    function testSetUpTreasury() public {
        assertEq(trsy.registry(), address(registry));
        assertEq(trsy.owner(), deployer);
    }

    function testSetUpRegistry() public {
        assertEq(registry.owner(), deployer);
        assertEq(registry.factory(), address(factory));
        for (uint256 i = 0; i < tokenPools.length; i++) {
            assertEq(registry.tokenPools(i), pools[i]);
            assertEq(registry.tokenToPool(tokenAddress[i]), pools[i]);
            assertEq(registry.PoolToToken(pools[i]), tokenAddress[i]);
            assertEq(
                registry.PoolToConcentration(pools[i]), concentration[i]
            );
        }
    }

    function testSetUpTokenPoolFactory() public {
        assertEq(factory.registry(), address(registry));
        assertEq(factory.owner(), deployer);
    }

    function testSetUpReservePool() public {
        for (uint256 i = 0; i < tokenPools.length; i++) {
            assertEq(tokenPools[i].targetconcentration(), concentration[i]);
            assertEq(tokenPools[i].chainlinkfeed(), feedAddress[i]);
        }
    }

    function testSetUpMock() public {
        for (uint256 i = 0; i < tokenPools.length; i++) {
            (,int price, , ,) = AggregatorV3Interface(feedAddress[i]).latestRoundData();
            (,int feedprice, , ,) = feedContract[i].latestRoundData();
            assertEq(price, feedprice);
            assertEq(erc20Contract[i].totalSupply(), 1000000000000000000000);
            assertEq(
                erc20Contract[i].balanceOf(deployer), 1000000000000000000000
            );
            assertEq(
                erc20Contract[i].balanceOf(address(1)), 1000000000000000000000
            );
        }
    } 

}

contract TestRegistry is ZeroState {
    
    function testOnlyFactory() public{
        vm.expectRevert(bytes("Only the factory can add token pools"));
        registry.addTokenPool(pools[1], tokenAddress[1], concentration[1]);
        vm.prank(address(factory));
        registry.addTokenPool(pools[1], tokenAddress[1], concentration[1]);
        assertEq(registry.PoolToToken(pools[1]), tokenAddress[1]);
        }
    
    function testSetTargetConcentration() public{
        vm.expectRevert(Registry.Error_Unauthorized.selector);
        registry.setTargetConcentration(pools[1], concentration[2]);
        vm.prank(deployer);
        registry.setTargetConcentration(pools[1], concentration[2]);
        assertEq(registry.PoolToConcentration(pools[1]), concentration[2]);
    }
}

contract TestFactory is ZeroState{
    function testDeployPool() public{
        vm.expectRevert(bytes("Only the owner can deploy a token pool"));
        factory.deployTokenPool(tokenAddress[1], feedAddress[1], concentration[1]);
        vm.prank(deployer);
        factory.deployTokenPool(address(10), address(20), concentration[1]);
        address pool = registry.tokenToPool(address(10));
        assertEq(registry.tokenPools(3), pool);
        assertEq(registry.PoolToConcentration(pool), concentration[1]);
    }
}