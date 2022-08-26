// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/Registry.sol";
import "../src/Treasury.sol";
import "../src/TokenPool.sol";
import "../src/TokenPoolFactory.sol";
import "./Mocks/MockERC20.sol";
//import "./Mocks/MockV3Aggregator.sol";
import"../src/TRSYERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


// ZeroState represent the initial state of the deployment where all the contracts are deployed.
abstract contract ZeroState is Test {
    Registry registry;
    TokenPoolFactory factory;
    Treasury trsy;
    MockERC20[] erc20Contract;
    AggregatorV3Interface[] feedContract;
    TokenPool[] tokenPools;
    TRSYERC20 token;

    address public deployer = address(1);

    string[3] public tokenName = ["dai", "aave", "ethereum"];
    address[3] public tokenAddress;
    address[3] public feedAddress = [0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9, 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9,0xaEA2808407B7319A31A383B6F8B60f04BCa23cE2];
    address[3] public pools;
    uint256[3] public concentration = [500000, 300000, 200000];

    function setUp() public virtual {
        vm.label(deployer, "Deployer");
        vm.startPrank(deployer);

        // Deploy main contracts
        registry = new Registry();
        token = new TRSYERC20(1000000000000000000000);
        trsy = new Treasury(address(token), address(registry));
        factory =
            new TokenPoolFactory(address(registry));
        vm.label(address(registry), "PoolRegistry");
        vm.label(address(trsy), "Treasury");
        vm.label(address(factory), "TokenPoolFactory");

        // Log the ReservePoolFactory in registry
        registry.setFactory(address(factory));
        

        for (uint256 i = 0; i < tokenName.length; i++) {
            // Deploy erc20 and chainlink mock
            MockERC20 erc20 = new MockERC20(tokenName[i], tokenName[i]);
            vm.label(address(erc20), tokenName[i]);
            AggregatorV3Interface feed = AggregatorV3Interface(feedAddress[i]);
            //MockV3Aggregator feed = new MockV3Aggregator(8,"lib/chainlink-MockAggregator/dataRequest.js", tokenName[i]);
            vm.label(address(erc20), string.concat("Feed ", tokenName[i]));

            // Create new pools
            factory.deployTokenPool(address(erc20), feedAddress[i], concentration[i]);
            address pool = registry.tokenToPool(address(erc20));
            TokenPool p = TokenPool(pool);
            vm.label(pool, string.concat("Pool ", tokenName[i]));

            // Set token concentrations
            registry.setTargetConcentration(pool, concentration[i]);

            // Keep a track of contracts in arrays
            erc20Contract.push(erc20);
            feedContract.push(feed);
            tokenPools.push(p);
            tokenAddress[i] = address(erc20);
            pools[i] = address(pool);
        }

        vm.stopPrank();
    }
}

abstract contract InitState is ZeroState {
    address user1 = address(2);
    address user2 = address(3);

    ERC20 erc;

    function setUp() public virtual override {
        super.setUp(); // ZeroState functionality
        vm.label(user1, "user1");
        vm.label(user2, "user2");
        vm.startPrank(deployer);
        trsy.whitelistUser(user1);
        trsy.whitelistUser(user2);
        vm.stopPrank();
        uint256 len = tokenAddress.length;
        for (uint256 i = 0; i < len;) {
            vm.startPrank(deployer);
            erc = ERC20(tokenAddress[i]);
            erc.transfer(user1, 10000000000000000000);
            erc.transfer(user2, 10000000000000000000);
            trsy.whitelistToken(tokenAddress[i]);
            vm.stopPrank();
            vm.startPrank(user1);
            erc.approve(address(trsy), 10000000000000000000);
            vm.stopPrank();
            vm.startPrank(user2);
            erc.approve(address(trsy), 10000000000000000000);
            vm.stopPrank();
            unchecked {
                i++;
            }
        }
    }
}

//@notice On this state we will test the contract state for only one deposit
abstract contract FirstDepositState is InitState {
    function setUp() public override {
        super.setUp();
        vm.startPrank(user1);
        trsy.deposit(10000000000000000000, tokenAddress[1]);
        vm.stopPrank();
    }
}
