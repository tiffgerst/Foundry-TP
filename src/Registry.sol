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
mapping(address => uint256) public poolsToDepositInto;
mapping(address => uint256) public poolsToWithdrawFrom;
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

    function setFactory(address _factory) public onlyOwner{
        factory = _factory;
    }
    function addTokenPool(address _tokenPool, address _token, uint256 concentration) public {
        require(msg.sender == factory, "Only the factory can add token pools");
        tokenPools.push(_tokenPool);
        tokenToPool[_token] = _tokenPool;
        PoolToToken[_tokenPool] = _token;
        PoolToConcentration[_tokenPool] = concentration;
    }

    function setTargetConcentration(address _pool, uint256 _target)
        external
        onlyOwner
    {
        PoolToConcentration[_pool] = _target;
    }

    function getConcentrationDifference(address pool) view public returns(int){
        uint256 total = getTotalAUMinUSD();
        (uint256 poolBalance, uint256 target) = ITokenPool(pool).getPoolValue();            
        int difference = int(poolBalance)*int(PRECISION)/int(total) - int(target);
        return difference;
    }


    function getTotalAUMinUSD() public view returns (uint256) {
        uint256 total = 0;
        uint256 len = tokenPools.length;
        for (uint i = 0; i < len;) {
            address pool = tokenPools[i];  
            (uint256 poolBalance, ) = ITokenPool(pool).getPoolValue();
            total += poolBalance;
            unchecked{++i;}
        }
        return total;
    }

    function tokensToWithdraw(uint256 _amount) public returns (address[] memory, uint256[] memory){
        (address[] memory pools, uint256[] memory tokenAmt) = liquidityCheck(_amount);
        return (pools, tokenAmt);
    }

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

    function liquidityCheck(uint256 _amount) public  returns (address[] memory, uint256[] memory){
        Rebalancing[] memory rebalance = getWithdrawRebalancing();
        uint256 len = rebalance.length;
        uint256 total = 0;
        for (uint i = 0; i < len;){
            total += rebalance[i].amt;
            unchecked{++i;}
        }
        if (total < _amount) {
            (address[] memory pool , uint256[] memory amt ) = WithdrawWhenLiquidityIsLower(_amount, total);
            return (pool, amt);
        }
        else{
            (address[] memory pool , uint256[] memory amt ) = WithdrawWhenLiquidityIsHigher(rebalance, _amount);
            return (pool, amt);
        }
    }
    function WithdrawWhenLiquidityIsHigher(Rebalancing[] memory _rebalance, uint256 _amount) internal pure returns(address[] memory, uint256[] memory) {
        uint256 len = _rebalance.length;
        address[] memory pool = new address[](len);
        uint256[] memory tokenamt = new uint256[](len);
        uint256 total = 0;
        for (uint i; i<len;){
            (Rebalancing memory max, uint index) = findMax(_rebalance);
            if (total + max.amt > _amount){
                tokenamt[i]= (_amount - total);
                pool[i] = (max.pool);
                return (pool, tokenamt);
            }
            else{
                tokenamt[i] = (max.amt);
                pool[i] = (max.pool);
                total += max.amt;
                 _rebalance[index].amt = 0;
            }
            unchecked{++i;}
          
        }
        return (pool, tokenamt);
    }
       
    function WithdrawWhenLiquidityIsLower(uint256 _amount, uint256 _total) internal view returns(address[] memory, uint256[] memory) {
        uint256 len = tokenPools.length;
        address[] memory pool = new address[](len);
        uint256[] memory tokenamt = new uint256[](len);
        uint256 remainder = _amount - _total;
        for (uint i = 0; i<len;){
            address pools = tokenPools[i];
            uint aum = getTotalAUMinUSD();
            uint256 total = aum - _total;
            uint extra = 0;
            (uint256 pre, uint256 target) = ITokenPool(pools).getPoolValue();  
            if (aum == pre) {
                pool[i] = tokenPools[i];
                tokenamt[i] = poolsToWithdrawFrom[tokenPools[i]]+ remainder;
                return (pool, tokenamt);
            }   
            else if (pre==0){
                pool[i] = tokenPools[i];
                tokenamt[i] = 0;
            }  
            
            else {
            uint post = pre - poolsToWithdrawFrom[tokenPools[i]]; 
            while ((remainder > 0) && (((post * PRECISION)/total) > target)){
                uint amt = ((((post * PRECISION)/total) - target) * post) / PRECISION;
                post -= amt;
                total -= amt;
                
                if (remainder - amt > 0) {
                    remainder -=amt;
                }
                else{
                    amt = remainder;
                }
                extra += amt;
            }  
        //     (uint poolBalance,) = ITokenPool(tokenPools[i]).getPoolValue();
        //     if ( poolBalance < liquidityPerPool){
        //         tokenamt[i] = poolBalance;
        //         pool[i] = tokenPools[i];
        //         uint extra = liquidityPerPool-poolBalance;
        //     }
            pool[i] = (tokenPools[i]);
            tokenamt[i] = poolsToWithdrawFrom[tokenPools[i]]+ extra;}
            unchecked{++i;}
        }
        return (pool, tokenamt);
    }

    // function hasToRebalanceDW(address pool) public returns (bool,bool){
    //      address pools = pool;
    //         int cD = getConcentrationDifference(pools);
    //         if (cD < 0){

    //         }
    // }
    function getWithdrawRebalancing() public returns(Rebalancing[] memory){
        uint256 len = tokenPools.length;
        Rebalancing[] memory rebalance = new Rebalancing[](len);
        uint j = 0;
        for (uint i = 0; i < len;) {
            address pools = tokenPools[i];
            poolsToWithdrawFrom[pools] = 0;
            int cD = getConcentrationDifference(pools);
            uint concentrationDifference = cD < 0 ? uint(0) : uint(cD);
            if (concentrationDifference>0){
                 (uint256 poolBalance, ) = ITokenPool(pools).getPoolValue();
                uint256 tokenamt = (uint256(concentrationDifference) * poolBalance) /PRECISION;
                rebalance[j] = Rebalancing({pool:pools, amt:tokenamt});
                j+=1;
                poolsToWithdrawFrom[pools] = tokenamt;
                
            }
           
        unchecked{++i;}
    }
    return rebalance;
    }
    
//     function SortPoolConcentrations(uint256 _amount) public{
//         uint256 len = tokenPools.length;
//         for (uint i = 0; i < len;) {
//             address pool = tokenPools[i];
//             uint256 difference = getConcentrationDifference(pool);
//             poolsToDepositInto[pool] = 0;
//             poolsToWithdrawFrom[pool] = 0;
//             if (difference > 0) {
//                 poolsToDepositInto[pool] = difference;
//             } 
//             if (difference < 0) {
//                 poolsToWithdrawFrom[pool] = difference;
//             }
//             unchecked{++i;}
//         }

//     }
// }
}
