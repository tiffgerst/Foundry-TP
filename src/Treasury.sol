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
uint public endTime;
address[] public rewardees;
mapping (address => bool) public isRewardee;

//Errors
error Error_Unauthorized();
error InsufficientBalance(uint256 available, uint256 required);

//enum
enum INCENTIVE{
        OPEN,
        CLOSED
    }

INCENTIVE public incentive = INCENTIVE.CLOSED;

//struct
struct Concentrations{
        uint256 currentConcentration;
        uint256 targetConcentration;
        uint256 newConcentration;
        uint256 aum;
    }
//modifier
modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Error_Unauthorized();
        }
        _;
    }

//events
event TokenDeposited(
        address indexed depositor,
        address token,
        uint256 amount,
        uint256 usdValueDeposited,
        uint256 sharesMinted
    );

event IncentiveOpen(
        uint256 endTime
    );

//constructor
constructor(
        address _trsy,
        address _registry
    ) {
    owner = msg.sender;
    registry = _registry;
    TRSY = TRSYERC20(_trsy);
    }
/**
@dev function that adds a user to the whitelist
 */
    function whitelistUser(address _user) public onlyOwner {
        whitelistedUsers[_user] =true;
    }

function getIncentiveStatus() public view returns (uint) {
     return uint(incentive);
}
/**
@dev function that adds a token to the whitelist
 */
    function whitelistToken(address _token) public onlyOwner {
         whitelistedTokens[_token] =true;
    }
/**
@dev function that makes a concentration struct by calculating the new, current, aum and target concentration 
@param pool - pool to make the struct for
@param amount - new amount to be added to pool
 */
    function makeConcentrationStruct(address pool, uint amount) public view returns (Concentrations memory){
        Concentrations memory concentration;
        concentration.currentConcentration = Registry(registry).getConcentration(pool);
        concentration.targetConcentration = Registry(registry).PoolToConcentration(pool);
        concentration.newConcentration = Registry(registry).getNewConcentration(pool, amount);
        concentration.aum = Registry(registry).getTotalAUMinUSD();
        return concentration;
    }
/**
@dev function that allows a whitelisted user to deposit a whitelisted token into the treasury in exchange for TRSY
@param _token - token to be deposited
@param _amount - amount of token to be deposited
 */
    function deposit(uint256 _amount, address _token) public {
        require(whitelistedUsers[msg.sender], "User is not whitelisted");
        require(whitelistedTokens[_token], "Token is not whitelisted");
        address pool = IRegistry(registry).tokenToPool(_token);
        uint256 USDValue = ITokenPool(pool).getDepositValue(_amount);
        require(USDValue > 1e18, "Amount must be greater than $1");
        Concentrations memory c = makeConcentrationStruct(pool,USDValue);
        if (c.aum>10000e18 && c.aum!=0){
        require(c.currentConcentration < (c.targetConcentration + 200000), "Concentration is too high"); //concentration is too high to deposit into pool
        require(c.newConcentration < (c.targetConcentration + 300000), "This will make the pool too concentrated");}

        uint taxamt = USDValue * 50000 / PRECISION; // tax user 5%
        //if users deposit makes concentration too high, tax them an addition 7.5% per dollar that is over the target concentration
        if ((c.newConcentration>c.targetConcentration) && (c.newConcentration >= c.currentConcentration)&&(c.aum>10000e18)){
           uint change =  c.targetConcentration < c.currentConcentration ? USDValue * 75000 / PRECISION : USDValue * (c.newConcentration - c.targetConcentration)/PRECISION * 75000 / PRECISION ;
           taxamt += change;
        } 
        uint256 trsyamt = getTRSYAmount(USDValue);
        uint256 trsytaxamt = getTRSYAmount(taxamt);
        bool success = IERC20(_token).transferFrom(msg.sender, pool, _amount);
        require(success);
        timestamp[msg.sender] = block.timestamp;
        TRSY.mint(msg.sender, trsyamt-trsytaxamt);
        TRSY.mint(address(this), trsytaxamt); //give this contract the tax 
        checkIncentive();
        emit TokenDeposited(msg.sender, _token, _amount, USDValue, trsyamt-trsytaxamt);
    }

    /**
    @dev function to get how much TRSY a user will get for a certain amount of USD
    @param _amount - amount of USD to be converted to TRSY
     */
    function getTRSYAmount(uint256 _amount) public view returns (uint256){
        uint256 tvl = IRegistry(registry).getTotalAUMinUSD();
        uint256 supply = TRSY.totalSupply();
        return tvl == 0 ? _amount : (_amount * supply) / tvl;
    }

/**
@dev function that allows a user to withdraw TRSY
@param _amount - amount of treasury to be withdrawn 
 */
    function withdraw(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        uint256 trsyamt = TRSY.balanceOf(msg.sender);
        if (trsyamt < _amount) {
            revert InsufficientBalance({available: trsyamt, required: _amount});
        }
        uint tax = calculateTax(_amount, msg.sender); //withdrawal tax 
        uint postTax = _amount -tax; // actualy trsy that will be withdrawn 
        uint256 usdamt = getWithdrawAmount(postTax);
        (address[] memory pools, uint256[] memory amt) = IRegistry(registry).tokensToWithdraw(usdamt);
        TRSY.burn(msg.sender, _amount); //burn total amount from user
        TRSY.mint(address(this), tax); // mint this address the tax
        uint len = pools.length;
        for (uint i; i<len;){
            if( pools[i]!= address(0)){
            address pool = pools[i];
            uint256 amount = getTokenAmount(amt[i], pools[i]);
            ITokenPool(pool).withdrawToken(msg.sender,amount);
            }
            unchecked{++i;}
        }
    }
    /**
    @dev function  that calculates how much tax a user will pay on a withdrawal
    @param _amount - amount of TRSY to be withdrawn
    @param sender - user that is withdrawing
     */
    function calculateTax(uint256 _amount, address sender) public view returns (uint256){
        uint256 tax = _amount * 10000 / PRECISION; //all withdrawals taxed at 1%
        uint time = block.timestamp - timestamp[sender];
        int numdays = int(time / 86400);
        if(numdays <= 30){ //if user withdraws within 30 days of depositing, it is taxed more
             int calcTax =  ((200000 * numdays / 30) - 200000);
             int taxamt = 0 - calcTax;
             tax += _amount * uint(taxamt) / PRECISION;
        }
             return tax;
        }
        

    /**
    @dev calculate how many tokens a certain usd amount is worth 
    @param usdamt - dollar amount
    @param pool - tokenPool
     */
    function getTokenAmount(uint usdamt, address pool) public returns (uint256){
        uint price = ITokenPool(pool).getPrice();
        return ((usdamt * 10**18)/price);
    }

/**
@dev function to convert TRSY to usd
@param trsyamt - trsy amount 
 */
    function getWithdrawAmount(uint256 trsyamt) public view returns(uint256) {
        uint256 trsy = (PRECISION * trsyamt) / TRSY.totalSupply();
        uint256 tvl = IRegistry(registry).getTotalAUMinUSD();
        uint256 usdAmount = (tvl * trsy) / PRECISION;
        return usdAmount;
    }

    function checkIncentive() internal {
        if (Registry(registry).checkDeposit(50000)){
            incentivize();
         }
    }
    function ownerStartIncentive() public onlyOwner { 
       incentivize();
    }

    function incentivize() internal {
        if (incentive == INCENTIVE.CLOSED){
            incentive = INCENTIVE.OPEN;
            endTime = block.timestamp + 2 hours;
            emit IncentiveOpen (endTime);
        }
        
    }

    function closeIncentive() public onlyOwner {
        incentive = INCENTIVE.CLOSED;
        finishIncentive();
    }

    function depositIncentive(uint256 _amount, address _token) public {
        if (block.timestamp >= endTime){
            incentive = INCENTIVE.CLOSED;
            finishIncentive();
        }
        if (incentive == INCENTIVE.OPEN){
        require(whitelistedTokens[_token], "Token is not whitelisted");
        address pool = IRegistry(registry).tokenToPool(_token);
        uint256 USDValue = ITokenPool(pool).getDepositValue(_amount);
        require(USDValue > 1e18, "Amount must be greater than $1");
        require(USDValue * 50000/PRECISION < getWithdrawAmount(TRSY.balanceOf(address(this))), "Amount exceeds max incentive");
        Concentrations memory c = makeConcentrationStruct(pool,USDValue);
        require(c.currentConcentration<c.targetConcentration, "Pool is already above target concentration");
        require(c.newConcentration < (c.targetConcentration + 300000), "This will make the pool too concentrated");
        uint256 trsyamt = getTRSYAmount(USDValue);
        uint reward = trsyamt * 50000 / PRECISION;
        bool success = IERC20(_token).transferFrom(msg.sender, pool, _amount);
        require(success);
        timestamp[msg.sender] = block.timestamp;
        TRSY.mint(msg.sender, trsyamt);
        TRSY.transfer(msg.sender, reward);
        if (!isRewardee[msg.sender]){
            isRewardee[msg.sender] = true;
            rewardees.push(msg.sender);
        }
        if (!Registry(registry).checkDeposit(10000) || TRSY.balanceOf(address(this)) < 1e18){
            incentive = INCENTIVE.CLOSED;
            finishIncentive();
        }    }
    }

    function finishIncentive() internal {
        uint256 diff = Registry(registry).calcDeposit();
        if (diff < 30000){
            uint256 total = TRSY.balanceOf(address(this));
            uint256 len = rewardees.length;
            uint256 reward = total / len;
            for (uint i; i<len;){
                address person = rewardees[i];
                rewardees[i] = address(0);
                TRSY.transfer(person, reward);
                unchecked{++i;}
            }
        }
        rewardees = new address[](0);
        endTime = 0;
    }

   

}