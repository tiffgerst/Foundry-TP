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

    function tokensToWithdraw(uint256 _amount) public view returns (address[] memory, uint256[] memory){
        (address[] memory pools, uint256[] memory tokenAmt) = checkWithdraw(_amount);
        return (pools, tokenAmt);
    }


    function liquidityCheck(uint256 _amount) public view returns(Rebalancing[] memory, Rebalancing[] memory)  {
        Rebalancing[] memory deposit = new Rebalancing[](tokenPools.length);
        Rebalancing[] memory withdraw = new Rebalancing[](tokenPools.length);
        uint aum = getTotalAUMinUSD();
        uint newAUM = aum - _amount;
        uint len = tokenPools.length;
        for (uint i = 0; i < len;) {
            address pool = tokenPools[i];
            uint256 poolBalance = ITokenPool(pool).getPoolValue();
            uint256 target = PoolToConcentration[pool];
            uint256 poolTarget = newAUM*target/PRECISION;
            if(poolBalance > poolTarget){
                uint256 amt = poolBalance - poolTarget;
                withdraw[i]=(Rebalancing({pool: pool, amt: amt}));
            }
            else if (poolBalance < poolTarget){
                uint256 amt = poolTarget - poolBalance;
                deposit[i]= (Rebalancing({pool: pool, amt: amt}));
            }
            else{
                deposit[i]= (Rebalancing({pool: pool, amt: 0}));
                withdraw[i]=(Rebalancing({pool: pool, amt: 0}));
            }
            unchecked{++i;}
        }
        return(deposit, withdraw);
        }
    
    function checkWithdraw(uint _amount)public view returns (address[] memory, uint256[] memory){
        (,Rebalancing[] memory withdraw) = liquidityCheck(_amount);
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

    function getConcentration(address pool) view public returns(uint){
            uint256 total = getTotalAUMinUSD();
            uint256 poolBalance = ITokenPool(pool).getPoolValue();     
            uint current = poolBalance*PRECISION/total;   
            return current;
        }
    
}
