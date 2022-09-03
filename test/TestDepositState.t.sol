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
    
//     struct Rebalancing {
//     address pool;
//     uint256 amt;
// }

    function testMint() public {
        (uint256 usdVal,) = ITokenPool(pools[1]).getDepositValue(amountDeposited);
        assertEq(token.balanceOf(user1), usdVal);
        assertEq(token.totalSupply(), token.balanceOf(user1));
        emit log_uint(token.balanceOf(user1));
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
        uint256 tsryToWithdraw = token.balanceOf(user1); // Widthraw 50 %
        address pool = registry.tokenToPool(tokenAddress[1]);
        emit log_uint(erc20Contract[1].balanceOf(pool));
        vm.prank(user1);
        trsy.withdraw(tsryToWithdraw);
        assertEq(token.balanceOf(user1), 0);
        assertEq(erc20Contract[1].balanceOf(user1), amountReceived );
        assertEq(erc20Contract[1].balanceOf(pool), 0);
        emit log_uint(erc20Contract[1].balanceOf(pool));
    }  

}

contract TestRegistry is FirstDepositState {
    uint256 public amountDeposited = 10000000000000000000;
    uint256 constant PRECISION = 1e6;

    function testgetConcentrationDifference() public {
        uint256 totalAUM = registry.getTotalAUMinUSD();
        (uint256 poolAUM, uint concentration) = ITokenPool(pools[1]).getPoolValue();
        int poolConcentrationDiff = registry.getConcentrationDifference(pools[1]);
        assertEq(poolConcentrationDiff, 700000);
        assertEq(poolConcentrationDiff, int((((poolAUM/totalAUM))*PRECISION) - concentration));
        int pcd = registry.getConcentrationDifference(pools[0]);
        assertEq(0-pcd, 500000);
    }

    function testGetAllPoolAUM() public {
        (uint price, ) = ITokenPool(pools[1]).getDepositValue(amountDeposited);
        assertEq(registry.getTotalAUMinUSD(),price );
    } 


  
    
    
    
}
 


//     function testPoolData() public {
//         address pool = router.getRoute(tokenAddress[1]);
//         PoolLogic.PoolData memory poolData = registry.getPoolData(pool);
//         assertEq(poolData.poolAddress, pool);
//         assertEq(poolData.tokenAddress, tokenAddress[1]);
//         assertEq(poolData.currentConcentration, 1000000);
//         assertEq(poolData.targetConcentration, concentration[1]);
//         assertEq(poolData.tokenBalance, amountDeposited);
//         assertEq(poolData.aumInUSD, getPrice(amountDeposited));
//     }

//     function testGetPoolAUM() public {
//         address pool = router.getRoute(tokenAddress[1]);
//         assertEq(registry.getPoolAUMinUSD(pool), getPrice(amountDeposited));

//         uint256 tsryToWithdraw = router.balanceOf(user1) / 2; // Widthraw 50 %
//         vm.prank(user1);
//         router.withdraw(tsryToWithdraw);
//         assertEq(tsryToWithdraw, registry.getPoolAUMinUSD(pool));
//     }

//     

//     
// }

// contract FuzzOracleFirstDeposit is FirstDepositState {
//     uint256 public amountDeposited = 10000000000000000000;

//     function testFuzzDeposit(uint256 nJump) public {
//         nJump = bound(nJump, 1, 350);
//         address pool = router.getRoute(tokenAddress[1]);
//         for (uint256 i = 0; i < nJump; i++) {
//             chainlinkFeed[1].updateAnswer();
//             assertEq(registry.getPoolAUMinUSD(pool), getPrice(amountDeposited));
//             assertEq(registry.getTotalPoolsAUMinUSD(), getPrice(amountDeposited));
//         }
//     }

//     function getPrice(uint256 amount) internal view returns (uint256) {
//         return (amount * feedContract[1].getPriceInUSD()) / (10 ** chainlinkFeed[1].decimals());
//     }
