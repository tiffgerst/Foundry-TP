// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {InitState} from "./ContractState.sol";
import "forge-std/Test.sol";
import "../src/interfaces/ITokenPool.sol";
import "../src/interfaces/IRegistry.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract TestMultiPools is InitState {
    uint256 constant PRECISION = 1e6;
function testDepositWithdraw() public {
        uint256[3] memory tokenAmountA = [uint256(10000e18), uint256(100e17), uint256(300e16)];
        uint256[3] memory tokenAmountB = [uint256(8000e18), uint256(50e17), uint256(400e16)];
        uint256[3] memory depositUserA;
        uint256[3] memory depositUserB;
        uint256[3] memory expectPoolAum;
        uint256[3] memory conc;
        uint256 sumDepositA;
        uint256 sumDepositB;
        uint256 totalAum;

        // User1 and User2 deposit some token in the protocol
        // We check if the TVL correspond to what has been deposited
        for (uint256 i = 0; i < tokenAmountA.length; i++) {
            address pool = registry.tokenToPool(tokenAddress[i]);
            vm.prank(user1);
            trsy.deposit( tokenAmountA[i],tokenAddress[i]);
            vm.prank(user2);
            trsy.deposit(tokenAmountB[i],tokenAddress[i]);
        

            depositUserA[i] = (tokenAmountA[i] * getPriceInUSD(feedAddress[i])) / (10 ** 18);
            sumDepositA += depositUserA[i];
            depositUserB[i] = (tokenAmountB[i] * getPriceInUSD(feedAddress[i])) / (10 ** 18);
            sumDepositB += depositUserB[i];
            expectPoolAum[i] = depositUserA[i] + depositUserB[i];
            totalAum += expectPoolAum[i];
            uint poolAUM = ITokenPool(pool).getPoolValue();
            assertEq(depositUserA[i] + depositUserB[i], poolAUM );
            assertEq(expectPoolAum[i], poolAUM);
        }
        assertEq(token.balanceOf(user1), sumDepositA);
        assertEq(token.balanceOf(user2), sumDepositB);
        assertEq(token.totalSupply(), sumDepositA + sumDepositB);
        assertEq(totalAum, registry.getTotalAUMinUSD());

        // Approx concentration are 40,12,47
        conc[0] = registry.PoolToConcentration(registry.tokenPools(0));
        conc[1] = registry.PoolToConcentration(registry.tokenPools(1));
        conc[2] = registry.PoolToConcentration(registry.tokenPools(2));

        uint256 liquidityToWithdrawA = sumDepositA / 3;
        uint256 liquidityToWithdrawB = sumDepositB / 2;
        uint256 tsryBalanceA = token.balanceOf(user1);
        uint256 tsryBalanceB = token.balanceOf(user2);
        uint256 shareA = (PRECISION * liquidityToWithdrawA) / token.totalSupply();
        uint256 shareB = (PRECISION * liquidityToWithdrawB) / token.totalSupply();
        uint256 expectedLiquidityA = shareA * totalAum / PRECISION;
        uint256 expectedLiquidityB = shareB * totalAum / PRECISION;

        vm.prank(user1);
        trsy.withdraw(liquidityToWithdrawA);
        vm.prank(user2);
        trsy.withdraw(liquidityToWithdrawB);

        uint256 tsryBurnA = tsryBalanceA - token.balanceOf(user1); // Amount burn
        uint256 tsryBurnB = tsryBalanceB - token.balanceOf(user2); // Amount burn

        assertApproxEqRel(tsryBurnA, expectedLiquidityA, 1e15);
        assertApproxEqRel(tsryBurnB, expectedLiquidityB, 1e15);
        assertApproxEqRel(totalAum - (tsryBurnA + tsryBurnB), registry.getTotalAUMinUSD(), 1e15);
    }

     function getPriceInUSD(address feed) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint256 decimals = priceFeed.decimals();
        return (uint256(price) * (10 ** (18 - decimals)));
    }

//     function testOwnWithdraw() public {
//         uint[] memory amountA = [uint256(10000e18), uint256(100e17), uint256(300e16];
//         for (uint256 i = 0; i < tokenAddress.length; i++) {
//             address pool = registry.tokenToPool(tokenAddress[i]);
//             vm.prank(user1);
//             trsy.deposit(,tokenAddress[i]);
//             vm.prank(user2);
//             trsy.deposit(tokenAmountB[i],tokenAddress[i]);
//     }
// }

}
