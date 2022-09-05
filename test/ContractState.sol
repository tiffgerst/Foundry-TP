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
    Registry public registry;
    TokenPoolFactory public factory;
    Treasury public trsy;
    MockERC20[] public erc20Contract;
    AggregatorV3Interface[] public feedContract;
    TokenPool[] public tokenPools;
    TRSYERC20 public token;
    address trsytoken;

    address public deployer = vm.addr(1);

    string[3] public tokenName = ["dai", "aave", "ethereum"];
    address[3] public tokenAddress;
    address[3] public feedAddress = [0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9, 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9,0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419];
    address[3] public pools;
    uint256[3] public concentration = [500000, 300000, 200000];
    uint256  amountReceived = 10000e18;

    function setUp() public virtual {
        vm.label(deployer, "Deployer");
        vm.startPrank(deployer);

        // Deploy main contracts
        registry = new Registry();
        token = new TRSYERC20();
        trsy = new Treasury(address(token), address(registry));
        factory =
            new TokenPoolFactory(address(registry));
        vm.label(address(registry), "Registry");
        vm.label(address(trsy), "Treasury");
        vm.label(address(factory), "TokenPoolFactory");

        // Log the ReservePoolFactory in registry
        registry.setFactory(address(factory));
        

        for (uint256 i = 0; i < tokenName.length; i++) {
            // Deploy erc20 and chainlink mock
            MockERC20 erc20 = new MockERC20(tokenName[i], tokenName[i]);
            vm.label(address(erc20), tokenName[i]);
            AggregatorV3Interface feed = AggregatorV3Interface(feedAddress[i]);
            vm.label(address(erc20), string.concat("Feed ", tokenName[i]));

            // Create new pools
            factory.deployTokenPool(address(erc20), feedAddress[i], concentration[i],18);
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
    address user1 = vm.addr(2);
    address user2 = vm.addr(3);

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
            erc.transfer(user1, amountReceived);
            erc.transfer(user2, amountReceived);
            trsy.whitelistToken(tokenAddress[i]);
            vm.stopPrank();
            vm.prank(user1);
            erc.approve(address(trsy), amountReceived);
            vm.prank(user2);
            erc.approve(address(trsy), amountReceived);
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
