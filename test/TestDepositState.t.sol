// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {FirstDepositState} from "./ContractState.sol";
import "forge-std/Test.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../src/interfaces/ITokenPool.sol";
import "../src/Registry.sol";
import "../src/interfaces/IRegistry.sol";
contract TestTRSY is FirstDepositState {
    uint256 public amountDeposited = 10000000000000000000;
    uint256 constant PRECISION = 1e6;
    
    function testMint() public {
        uint256 usdVal = ITokenPool(pools[1]).getDepositValue(amountDeposited);
        uint tax = usdVal * 50000 / PRECISION;
        assertEq(token.balanceOf(user1), usdVal-tax);
        assertEq(token.totalSupply(), token.balanceOf(user1) + token.balanceOf(address(trsy)));
        }

    function testTransferToken() public {
        address pool = registry.tokenToPool(tokenAddress[1]);
        assertEq(erc20Contract[1].balanceOf(user1), amountReceived - amountDeposited);
        assertEq(erc20Contract[1].balanceOf(pool), amountDeposited);
        emit log_uint(erc20Contract[1].balanceOf(pool));
        emit log_uint((erc20Contract[1].balanceOf(user1)));

        
    }

    function testPreviewWithdraw() public {
        uint256 totalSupply = token.totalSupply();
        uint256 tsryToWithdraw = token.balanceOf(user1) / 2; // Widthraw 50 %
        uint256 aum = registry.getTotalAUMinUSD();
        uint256 shareOfThePool = (PRECISION * tsryToWithdraw) / totalSupply; // 50 %
        uint256 usdVal = (aum * shareOfThePool) / PRECISION;
        assertEq(trsy.getWithdrawAmount(tsryToWithdraw), usdVal);
        emit log_uint(trsy.getWithdrawAmount(tsryToWithdraw));

    }

    function testFuzzPreviewWithdraw(uint256 amount) public {
        amount = bound(amount, 1, token.totalSupply());
        uint256 totalSupply = token.totalSupply();
        uint256 tsryToWithdraw = amount; // Widthraw 50 %
        uint256 aum = registry.getTotalAUMinUSD();
        uint256 shareOfThePool = (PRECISION * tsryToWithdraw) / totalSupply; // 50 %
        uint256 usdVal = (aum * shareOfThePool) / PRECISION;
        assertEq(trsy.getWithdrawAmount(tsryToWithdraw), usdVal);
    }
    function testPrice() public {
        emit log_uint(trsy.getTokenAmount(419232812450000000000, pools[1]));
    }
    function testWithdraw() public {
        uint256 tsryToWithdraw = token.balanceOf(user1)/2; // Widthraw 50 %
        address pool = registry.tokenToPool(tokenAddress[1]); //pool to withdraw from
        uint withdrawtax = trsy.calculateTax(tsryToWithdraw, user1); //tax to be paid upon withdraw
        uint256 usdVal = ITokenPool(pools[1]).getDepositValue(amountDeposited); //how much was initially deposited 
        uint tax = usdVal * 50000 / PRECISION; //deposit tax paid 
        uint actual = usdVal - tax; //dollar amount actually given trsy for 
        uint dollar = trsy.getWithdrawAmount(withdrawtax); //how many dollars were taxed upon withdrawal
        uint tokentax = trsy.getTokenAmount(dollar, pools[1]); //number of tokens taxed upon withdrawal
        uint amt = trsy.getTokenAmount(actual, pools[1]); //number of tokens given trsy for
        assertEq(trsy.getTRSYAmount(actual),token.balanceOf(user1));
        vm.prank(user1);
        trsy.withdraw(tsryToWithdraw);
        assertEq(token.balanceOf(user1),tsryToWithdraw); //50% should be gone
        assertEq(erc20Contract[1].balanceOf(user1), (amountReceived - amountDeposited) + amt / 2 - tokentax);
        assertEq(erc20Contract[1].balanceOf(pool), amountDeposited-amt/2 + tokentax);
        
    }  
//     function testFuzzWithdraw(uint256 amount) public {
//         amount = bound(amount, 1, token.balanceOf(user1));
//         uint256 tsryToWithdraw = amount;
//         address pool = registry.tokenToPool(tokenAddress[1]);
//         uint256 totalSupply = token.totalSupply();
//         uint256 preBal = token.balanceOf(user1);
//         uint256 aum = registry.getTotalAUMinUSD();
//         uint256 poolAum = ITokenPool(pool).getPoolValue();
//         uint256 shareOfThePool = (PRECISION * tsryToWithdraw) / totalSupply;
//         uint256 tokenPreBal = erc20Contract[1].balanceOf(user1) - erc20Contract[1].balanceOf(user1)*50000/PRECISION;
//         vm.prank(user1);
//         trsy.withdraw(tsryToWithdraw);
//          uint256 tsryBurn = preBal - (token.balanceOf(user1) - token.balanceOf(user1)*50000/PRECISION); // Amount burn
//         uint256 liquidityReceived =
//             ITokenPool(pool).getDepositValue(erc20Contract[1].balanceOf(user1) - tokenPreBal);
//         uint256 expectedLiquidity = shareOfThePool * aum / PRECISION;

//         // Case where user have been able to withdraw all the liquidity (enough liquidity in pools)
//         if (tsryBurn == amount) {
//             //assertApproxEqRel(tsryBurn, liquidityReceived, 1e15);
//             assertApproxEqRel(expectedLiquidity, liquidityReceived,1e15);
//             assertApproxEqRel(aum - tsryBurn, registry.getTotalAUMinUSD(),1e15);
//             assertApproxEqRel(poolAum - tsryBurn, ITokenPool(pool).getPoolValue(),1e15);
//         }
//         // Case where not enough liquitiy
//         else {
//             assertApproxEqRel(tsryBurn, liquidityReceived, 1e15); // 0.1 % Tolerance
//             assertApproxEqRel(aum - tsryBurn, registry.getTotalAUMinUSD(), 1e15);
//             assertApproxEqRel(poolAum - tsryBurn, ITokenPool(pool).getPoolValue(), 1e15);
//         }

// }
}

contract TestRegistry is FirstDepositState {
    uint256 public amountDeposited = 10000000000000000000;
    uint256 constant PRECISION = 1e6;

    function testgetConcentrationDifference() public {
        uint256 totalAUM = registry.getTotalAUMinUSD();
        uint256 poolAUM = ITokenPool(pools[1]).getPoolValue();
        uint concentration = registry.PoolToConcentration(pools[1]);
        uint poolConcentration = registry.getConcentration(pools[1]);
        int difference = int(poolConcentration) - int(concentration);
        assertEq(difference, 700000);
        assertEq(difference, int((((poolAUM/totalAUM))*PRECISION) - concentration));
        uint pcd = registry.getConcentration(pools[0]);
        uint target = registry.PoolToConcentration(pools[0]);
        int diff = int(pcd) - int(target);
        assertEq(0-diff, 500000);
    }

    function testGetAllPoolAUM() public {
        uint price = ITokenPool(pools[1]).getDepositValue(amountDeposited);
        assertEq(registry.getTotalAUMinUSD(),price );
    } 
}
 
