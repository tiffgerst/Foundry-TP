//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./TRSYERC20.sol";
import "./TokenPool.sol";
import "./interfaces/IRegistry.sol";
import "./interfaces/ITokenPool.sol";
import "./Registry.sol";


contract Treasury {

// State Variables
TRSYERC20 public immutable TRSY;
mapping (address => bool) public whitelistedUsers;
mapping (address => bool) public whitelistedTokens;
address public owner;
address public registry;
uint256 constant PRECISION = 1e6;

//Errors
error Error_Unauthorized();
error InsufficientBalance(uint256 available, uint256 required);


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

    function deposit(uint256 _amount, address _token) public {
        require(whitelistedUsers[msg.sender], "User is not whitelisted");
        require(whitelistedTokens[_token], "Token is not whitelisted");
        require(_amount > 0, "Amount must be greater than 0");
        address pool = IRegistry(registry).tokenToPool(_token);
        (uint256 USDValue,) = ITokenPool(_token).getDepositValue(_amount);
        uint256 trsyamt = getTRSYAmount(USDValue);
        bool success = IERC20(_token).transferFrom(msg.sender, pool, _amount);
        require(success);
        TRSY.mint(msg.sender, trsyamt);
        emit TokenDeposited(msg.sender, _token, _amount, USDValue, trsyamt);
    }
    function getTRSYAmount(uint256 _amount) public view returns (uint256){
        uint256 tvl = IRegistry(registry).getTotalPoolsAUMinUSD();
        uint256 supply = TRSY.totalSupply();
        return supply == 0 ? _amount : _amount * (supply / tvl);
    
    }

    function withdraw(uint256 _amount) public {
        require(whitelistedUsers[msg.sender], "User is not whitelisted");
        require(_amount > 0, "Amount must be greater than 0");
        uint256 trsyamt = TRSY.balanceOf(msg.sender);
        // if (trsyamt < _amount) {
        //     revert InsufficientBalance({available: trsyamt, required: _amount});
        // }
        require(_amount <= trsyamt, "Amount must be less than balance");

        uint256 usdamt = getWithdrawAmount(_amount);
        (address[] memory pools, uint256[] memory amt) = IRegistry(registry).tokensToWithdraw(usdamt);
        TRSY.burn(msg.sender, _amount);
        uint len = pools.length;
        for (uint i; i<len;){
            address pool = pools[i];
            ITokenPool(pool).withdrawToken(msg.sender,amt[i]);
            unchecked{++i;}
        }
        
        
        

    }

    function getWithdrawAmount(uint256 trsyamt) public view returns(uint256) {
        uint256 trsy = (PRECISION * trsyamt) / TRSY.totalSupply();
        uint256 tvl = IRegistry(registry).getTotalPoolsAUMinUSD();
        uint256 usdAmount = (tvl * trsy) / PRECISION;
        return usdAmount;
    }

    function getPoolsToDepositInto() public{

    }


}