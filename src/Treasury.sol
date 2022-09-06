//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./TRSYERC20.sol";
import "./TokenPool.sol";
import "./interfaces/IRegistry.sol";
import "./interfaces/ITokenPool.sol";
import "./Registry.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";



contract Treasury {

// State Variables
TRSYERC20 public immutable TRSY;
mapping (address => uint256) public timestamp;
mapping (address => bool) public whitelistedUsers;
mapping (address => bool) public whitelistedTokens;
address public owner;
address public registry;
uint256 constant PRECISION = 1e6;

//Errors
error Error_Unauthorized();
error InsufficientBalance(uint256 available, uint256 required);

//enum
enum INCENTIVE{
        OPEN,
        CLOSED
    }
INCENTIVE public incentive;
//struct
struct Concentrations{
        uint256 currentConcentration;
        uint256 targetConcentration;
        uint256 newConcentration;
        uint256 aum;
    }

modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Error_Unauthorized();
        }
        _;
    }
event TokenDeposited(
        address indexed depositor,
        address token,
        uint256 amount,
        uint256 usdValueDeposited,
        uint256 sharesMinted
    );
constructor(
        address _trsy,
        address _registry
    ) {
    owner = msg.sender;
    registry = _registry;
    TRSY = TRSYERC20(_trsy);
    }
    
    function whitelistUser(address _user) public onlyOwner {
        whitelistedUsers[_user] =true;
    }
    
    function whitelistToken(address _token) public onlyOwner {
         whitelistedTokens[_token] =true;
    }

    function makeConcentrationStruct(address pool, uint amount) public view returns (Concentrations memory){
        Concentrations memory concentration;
        concentration.currentConcentration = Registry(registry).getConcentration(pool);
        concentration.targetConcentration = Registry(registry).PoolToConcentration(pool);
        concentration.newConcentration = Registry(registry).getNewConcentration(pool, amount);
        concentration.aum = Registry(registry).getTotalAUMinUSD();
        return concentration;
    }
    function deposit(uint256 _amount, address _token) public {
        require(whitelistedUsers[msg.sender], "User is not whitelisted");
        require(whitelistedTokens[_token], "Token is not whitelisted");
        address pool = IRegistry(registry).tokenToPool(_token);
        uint256 USDValue = ITokenPool(pool).getDepositValue(_amount);
        require(USDValue > 1e18, "Amount must be greater than $1");
        Concentrations memory c = makeConcentrationStruct(pool,USDValue);
        if (c.aum>100000e18 && c.aum!=0){
        require(c.currentConcentration < (c.targetConcentration*1200000)/PRECISION, "Concentration is too high");
        require(c.newConcentration < (c.targetConcentration * 1300000 / PRECISION));}
        uint taxamt = USDValue * 50000 / PRECISION;
        if ((c.newConcentration>c.targetConcentration) && (c.newConcentration >= c.currentConcentration)){
           uint change =  c.targetConcentration < c.currentConcentration ? USDValue * 75000 / PRECISION : USDValue * (c.newConcentration - c.targetConcentration)/PRECISION * 75000 / PRECISION ;
           taxamt += change;
        }
        uint256 trsyamt = getTRSYAmount(USDValue);
        uint256 trsytaxamt = getTRSYAmount(taxamt);
        bool success = IERC20(_token).transferFrom(msg.sender, pool, _amount);
        require(success);
        timestamp[msg.sender] = block.timestamp;
        TRSY.mint(msg.sender, trsyamt-trsytaxamt);
        TRSY.mint(address(this), trsytaxamt);
        emit TokenDeposited(msg.sender, _token, _amount, USDValue, trsyamt-trsytaxamt);
        if (Registry(registry).checkDeposit()){
            incentive == INCENTIVE.OPEN;
        }
        else{
            incentive == INCENTIVE.CLOSED;
        }
    }
    function getTRSYAmount(uint256 _amount) public view returns (uint256){
        uint256 tvl = IRegistry(registry).getTotalAUMinUSD();
        uint256 supply = TRSY.totalSupply();
        return tvl == 0 ? _amount : (_amount * supply) / tvl;
    }

    function withdraw(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        uint256 trsyamt = TRSY.balanceOf(msg.sender);
        if (trsyamt < _amount) {
            revert InsufficientBalance({available: trsyamt, required: _amount});
        }
        uint tax = calculateTax(_amount, msg.sender);
        uint postTax = _amount -tax;
        uint256 usdamt = getWithdrawAmount(postTax);
        (address[] memory pools, uint256[] memory amt) = IRegistry(registry).tokensToWithdraw(usdamt);
        TRSY.burn(msg.sender, _amount);
        TRSY.mint(address(this), tax);
        uint len = pools.length;
        for (uint i; i<len;){
            if( pools[i]!= address(0)){
            address pool = pools[i];
            uint256 amount = getTokenAmount(amt[i], pools[i]);
            ITokenPool(pool).withdrawToken(msg.sender,amount);
            }
            unchecked{++i;}
        }
        if (Registry(registry).checkDeposit()){
            incentive == INCENTIVE.OPEN;
        }
        else{
            incentive == INCENTIVE.CLOSED;
        }
    }
    function calculateTax(uint256 _amount, address sender) public view returns (uint256){
        uint256 tax = _amount * 50000 / PRECISION;
        uint time = block.timestamp - timestamp[sender];
        int numdays = int(time / 86400);
        if(numdays <= 30){
             int calcTax =  ((200000 * numdays / 30) - 200000);
             int taxamt = 0 - calcTax;
             tax += _amount * uint(taxamt) / PRECISION;
        }
             return tax;
        }
        //(uint today, uint mean, uint std) = volatilityCheck();
        
    // function volatilityCheck () public view returns (uint, uint, uint){
    //     uint today = 0;
    //     uint mean = 0;
    //     uint std = 0;
    //     return (today, mean, std);
    // }
    function getTokenAmount(uint usdamt, address pool) public returns (uint256){
        uint price = ITokenPool(pool).getPrice();
        return ((usdamt * 10**18)/price);
    }

    function getWithdrawAmount(uint256 trsyamt) public view returns(uint256) {
        uint256 trsy = (PRECISION * trsyamt) / TRSY.totalSupply();
        uint256 tvl = IRegistry(registry).getTotalAUMinUSD();
        uint256 usdAmount = (tvl * trsy) / PRECISION;
        return usdAmount;
    }
    // function incentivize() public view{
    //     require(incentive==INCENTIVE.OPEN, "There is no incentive at the moment");
    //     uint256 trsyamt = TRSY.balanceOf(address(this));
    //     uint usdTrsy = getWithdrawAmount(trsyamt);
    //     uint max = usdTrsy * PRECISION/50000;
        
        
    //     // (Registry.Rebalancing [] memory rebalancing, uint total) = Registry(registry).checkDeposit();
    //     // uint len = rebalancing.length;
    //     // if ((total * 500000 / PRECISION) >= getWithdrawAmount(trsyamt)){

    //     // }
    //     // for (uint i; i<len;){
            
    //     //     unchecked{++i;}
    //     // }
    // }


}