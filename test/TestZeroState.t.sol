// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {ZeroState} from "./ContractState.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
            assertEq(erc20Contract[i].totalSupply(), 20000000000000000000000);
            assertEq(erc20Contract[i].balanceOf(deployer), 20000000000000000000000);
            
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
        factory.deployTokenPool(tokenAddress[1], feedAddress[1], concentration[1],18);
        vm.prank(deployer);
        factory.deployTokenPool(address(10), address(20), concentration[1],18);
        address pool = registry.tokenToPool(address(10));
        assertEq(registry.tokenPools(3), pool);
        assertEq(registry.PoolToConcentration(pool), concentration[1]);
    }
}

contract TestTreasury is ZeroState {
    function testWhitelistUser() public {
        vm.expectRevert(Treasury.Error_Unauthorized.selector);
        trsy.whitelistUser(address(10));
        vm.prank(deployer);
        trsy.whitelistUser(address(10));
        assertEq(trsy.whitelistedUsers(address(10)), true);
        assertEq(trsy.whitelistedUsers(address(11)), false);
    }
    function testWhitelistToken()public {
        vm.expectRevert(Treasury.Error_Unauthorized.selector);
        trsy.whitelistToken(tokenAddress[1]);
        vm.prank(deployer);
        trsy.whitelistToken(address(15));
        assertEq(trsy.whitelistedTokens(address(15)), true);
        assertEq(trsy.whitelistedTokens(address(16)), false);
    }
    function testDepositNotWhitelisted() public {
        vm.prank(address(20));
        vm.expectRevert(bytes("User is not whitelisted"));
        trsy.deposit(100, tokenAddress[1]);
    }

    function testDepositTokenNotWhitelisted() public{
        vm.prank(deployer);
        trsy.whitelistUser(address(2));
        vm.prank(address(2));
        vm.expectRevert(bytes("Token is not whitelisted"));
        trsy.deposit(100, address(16));
    }

    function testWithdrawUserNotWhitelisted() public{
        vm.prank(address(20));
        vm.expectRevert(bytes("User is not whitelisted"));
        trsy.withdraw(100);
    }

    function testGetTRSYamount(uint256 amount) public{
        vm.assume(amount > 0);
        vm.assume(amount < 1e50);
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            uint256 val = ITokenPool(pools[i]).getDepositValue(amount);
           (,int256 price,,,) = feedContract[i].latestRoundData();
            uint256 decimals = feedContract[i].decimals();
            assertEq(val, amount * (uint256(price) * (10**(18-decimals))) / 10 ** 18);    
        }
    
}
}