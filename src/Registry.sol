//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITokenPool.sol";
import "./TokenPool.sol";

contract Registry {
//Variables
address public owner;
address[] public tokenPools;
address public factory; 
mapping (address => address) public tokenToPool;
mapping (address => address) public PoolToToken;
mapping (address => uint256) public PoolToConcentration;
uint256 constant PRECISION = 1e6;


//Structs
struct Rebalancing {
    address pool;
    uint256 amt;
}

//Errors
error Error_Unauthorized();

//Events
event ReservePoolDeployed(
        address indexed poolAddress,
        address tokenAddress
    );

//Modifier
modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Error_Unauthorized();
        }
        _;
    }
//Constructor
    constructor(){
       owner = msg.sender;
    }

/**
@dev function to set the factory address
@param _factory (address of the factory)
 */
    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

/**
@dev function to add TokenPool to tokenPool array and various mappings
@param _tokenPool - address of tokenPool
@param _token - address of token
@param concentration - value of target concentration 
 */
    function addTokenPool(address _tokenPool, address _token, uint256 concentration) public {
        require(msg.sender == factory, "Only the factory can add token pools");
        tokenPools.push(_tokenPool);
        tokenToPool[_token] = _tokenPool;
        PoolToToken[_tokenPool] = _token;
        PoolToConcentration[_tokenPool] = concentration;
    }

/** 
@dev function to update the target concentration of a specific pool 
@param _pool - address of tokenPool
@param _target - value of target concentration
 */
    function setTargetConcentration(address _pool, uint256 _target)
        external
        onlyOwner
    {
        PoolToConcentration[_pool] = _target;
    }

/**
@dev function to get the total USD value of all assets in the protocol
iterates through all the pools to get their usd value and adds all the values together
 */

    function getTotalAUMinUSD() public view returns (uint256) {
        uint256 total = 0;
        uint256 len = tokenPools.length;
        for (uint i = 0; i < len;) {
            address pool = tokenPools[i];  
            uint256 poolBalance = ITokenPool(pool).getPoolValue();
            total += poolBalance;
            unchecked{++i;}
        }
        return total;
    }

/** 
@dev function to get the pools to withdraw from and the amount to withdraw from each pool
@param _amount - amount in usd to be withdrawn
 */
    function tokensToWithdraw(uint256 _amount) public view returns (address[] memory, uint256[] memory){
        (address[] memory pools, uint256[] memory tokenAmt) = checkWithdraw(_amount);
        return (pools, tokenAmt);
    }


/**
@dev function that finds which pools need to be rebalanced through a withdraw
@param _amount - how much usd is to be withdrawn
Calculates new aum and how much money has to be added/removed from pool to reach the target concentration
Checks which pool have to have money removed (and how much) and adds them to the array 
 */
    function liquidityCheck(uint256 _amount) public view returns(Rebalancing[] memory)  {
        uint len = tokenPools.length;
        Rebalancing[] memory withdraw = new Rebalancing[](len);
        uint aum = getTotalAUMinUSD();
        uint newAUM = aum - _amount;
        for (uint i = 0; i < len;) {
            address pool = tokenPools[i];
            uint256 poolBalance = ITokenPool(pool).getPoolValue();
            uint256 target = PoolToConcentration[pool];
            uint256 poolTarget = newAUM*target/PRECISION;
            if(poolBalance > poolTarget){
                uint256 amt = poolBalance - poolTarget;
                withdraw[i]=(Rebalancing({pool: pool, amt: amt}));
            }
            else{
                withdraw[i]=(Rebalancing({pool: pool, amt: 0}));
            }
            unchecked{++i;}
        }
        return withdraw;
        }
    
/**
@dev function that takes the rebalancing array from liquidityCheck and returns the pools to withdraw from
and how much to withdraw from each pool
Checks total amount to be withdraw, finds pools with greatest concentration disparity and takes from those first
@param _amount - amount to be withdrawn
 */
    function checkWithdraw(uint _amount)public view returns (address[] memory, uint256[] memory){
        Rebalancing[] memory withdraw = liquidityCheck(_amount);
        uint256 len = withdraw.length;
        address[] memory pool = new address[](len);
        uint[] memory tokenamt = new uint[](len);
        uint total = 0;
        for (uint i; i<len;){
            (Rebalancing memory max, uint index) = findMax(withdraw);
            if ((total<_amount)&&(total + max.amt > _amount)){
                tokenamt[i]= (_amount - total);
                pool[i] = (max.pool);
                total += tokenamt[i];
            }
            else if ((total<_amount)&&(total + max.amt <= _amount)){
                tokenamt[i] = (max.amt);
                pool[i] = (max.pool);
                total += max.amt;
                 withdraw[index].amt = 0;
            }
            unchecked{++i;}
           }
        return (pool, tokenamt);
    }
/**
@dev helper function that finds which pool has to have the most money withdrawn
@param _rebalance - rebalancing array 
 */
        function findMax (Rebalancing[] memory _rebalance) public pure returns (Rebalancing memory, uint256){ 
        uint256 len = _rebalance.length;
        uint max = 0;
        uint index = 0;
        for (uint i = 0; i<len;){
            if (max < _rebalance[i].amt){
                max = _rebalance[i].amt;
                index = i;
            }
            unchecked{++i;}
        }
        return (_rebalance[index],index);
    }
/**
@dev function to get the current concentration of a specific pool
@param pool - pool to fnd concentration of 
 */

    function getConcentration(address pool) view public returns(uint){
            uint256 total = getTotalAUMinUSD();
            uint256 poolBalance = ITokenPool(pool).getPoolValue();       
            return total == 0 ? 0 :poolBalance*PRECISION/total;
        }
/**
@dev function to get the concentration of certain pool when a certain amount is added to the pool
@param pool - pool to find concentration of
@param amount - amount to be added to pool
 */
    function getNewConcentration (address pool, uint amount) view public returns (uint){    
            uint256 total = getTotalAUMinUSD();
            uint256 poolBalance = ITokenPool(pool).getPoolValue() + amount;       
            return total == 0 ? 0 :poolBalance*PRECISION/total;
            
        }
/**
@dev checks if any pool has a concentration more than 5% above/below target concentration
 */
    function checkDeposit() public view returns (bool){
        uint len = tokenPools.length;
        for (uint i = 0; i < len;) {
            address pool = tokenPools[i];
            uint currentConcentration = getConcentration(pool);
            int diff = int(currentConcentration) - int(PoolToConcentration[pool]);
            if (diff>500000 ){
                return (true);
            }
            unchecked{++i;}
        }
        return false;
    }
    
    // function checkDeposit() public returns (Rebalancing[] memory, uint){
    //     uint len = tokenPools.length;
    //     Rebalancing[] memory deposit = new Rebalancing[](len);
    //     uint aum = getTotalAUMinUSD();
    //     uint total = 0;
    //     bool severe; 
    //     for (uint i = 0; i < len;) {
    //         address pool = tokenPools[i];
    //         uint256 poolBalance = ITokenPool(pool).getPoolValue();
    //         uint256 target = PoolToConcentration[pool];
    //         uint256 poolTarget = aum*target/PRECISION;
    //         if(poolBalance < poolTarget){
    //             uint256 amt = poolBalance - poolTarget;
    //             deposit[i]=(Rebalancing({pool: pool, amt: amt}));
    //             total += amt;
    //         }
    //         else{
    //             deposit[i]=(Rebalancing({pool: pool, amt: 0}));
    //         }
    //         unchecked{++i;}
    //     }
    //     return (deposit,total);
        
    // }

    }
    

