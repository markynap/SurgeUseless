pragma solidity 0.8.4;

/**
 * Created September 1st 2021
 * Developed by Markymark (DeFi Mark)
 * Swapper Contract to Accept BNB and return Useless to SurgeUseless
 * Splitting off a tax to fuel the Useless Furnace
 */
// SPDX-License-Identifier: Unlicensed

import "./IERC20.sol";
import "./Address.sol";
import "./SafeMath.sol";
import "./IUniswapV2Router02.sol";
import "./ReentrantGuard.sol";

/**
 * BNB Sent to this contract will be used to automatically buy Useless and send it back to SurgeUseless
 */
contract UselessSwapper is ReentrancyGuard {
    
    using Address for address;
    using SafeMath for uint256;

    // Initialize Pancakeswap Router
    IUniswapV2Router02 public _router;
  
    // Receive Token From Swap 
    address public _token;
    
    // path of BNB -> Token 
    address[] buyPath;

    // Useless Furnace Address
    address public _uselessFurnace;
    
    address public _surgeUseless;

    // owner of Swapper
    address public _owner;
    
    // fees
    uint256 public _buyFee;
    uint256 public _sellFee;
    
    // locks updating the SUSELESS contract
    bool public _updatingLocked;
    
    modifier onlyOwner() {require(msg.sender == _owner, 'Only Owner Function!'); _;}
  
    // initialize variables
    constructor() {
        _token = 0x2cd2664Ce5639e46c6a3125257361e01d0213657;
        _router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        _uselessFurnace = 0x16F21Ae97D967E87792A40c826c0AA943b78A6ec;
        _owner = msg.sender;
        buyPath = new address[](2);
        buyPath[0] = _router.WETH();
        buyPath[1] = _token;
        _buyFee = 66;
        _sellFee = 66;
    }
    
    function setSurgeUselessAddress(address surgeUseless) external onlyOwner {
        require(!_updatingLocked, 'Updating Address Is Locked');
        _surgeUseless = surgeUseless;
        emit UpdatedSurgeUselessAddress(surgeUseless);
    }
    
    function lockUpdates() external onlyOwner {
        require(!_updatingLocked, 'Already Locked');
        _updatingLocked = true;
        emit UpdatesLocked();
    }
    
    /** Updates the Pancakeswap Router and Pancakeswap pairing for BNB In Case of migration */
    function updatePancakeswapRouter(address newPCSRouter) external onlyOwner {
        require(newPCSRouter != address(0), 'Cannot Set Pancakeswap Router To Zero Address');
        _router = IUniswapV2Router02(newPCSRouter);
        buyPath[0] = _router.WETH();
        emit UpdatedPancakeswapRouter(newPCSRouter);
    }
    
    /** Updates The Useless Furnace in Case of Migration */
    function updateFurnaceContractAddress(address newFurnace) external onlyOwner {
        require(newFurnace != address(0), 'Cannot Set Furnace To Zero Address');
        _uselessFurnace = newFurnace;
        emit UpdateFurnaceContractAddress(newFurnace);
    }
    
    function updateUselessContractAddress(address newUselessAddress) external onlyOwner {
        require(newUselessAddress != address(0), 'CANNOT ASSIGN THE ZERO ADDRESS');
        require(!_updatingLocked, 'Updating Address Is Locked');
        _token = newUselessAddress;
        buyPath[1] = newUselessAddress;
        emit UpdatedUselessContractAddress(newUselessAddress);
    }

    function setFees(uint256 buyFee, uint256 sellFee) external onlyOwner {
        require(!_updatingLocked, 'Updating Address Is Locked');
        _sellFee = sellFee;
        _buyFee = buyFee;
        emit UpdatedFees(buyFee, sellFee);
    }

    /** Transfers Ownership To New Address */
    function transferOwnership(address newOwner) external onlyOwner {
        _owner = newOwner;
        emit OwnershipTransfered(newOwner);
    }
    
    function uselessBypass(address receiver, uint256 numTokens) external nonReentrant returns (bool){
        require(msg.sender == _surgeUseless, 'Only Surge Useless Can Call Function');
        // balance of Useless
        uint256 balance = IERC20(_token).balanceOf(msg.sender);
        // check balances
        require(numTokens <= balance && balance > 0, 'Insufficient Balance');
        // balance before transfer
        uint256 contractBalanceBefore = IERC20(_token).balanceOf(address(this));
        // transfer to this contract
        bool succOne = IERC20(_token).transferFrom(msg.sender, address(this), numTokens);
        // require success
        require(succOne, 'Failure on Transfer From');
        // transfer received tokens to recipient
        uint256 diff = IERC20(_token).balanceOf(address(this)).sub(contractBalanceBefore);
        // ensure it matches
        require(diff >= numTokens, 'Transfer was taxed');
        // apply fee to tokens
        uint256 tokensForFurnace = numTokens.div(_sellFee);
        // tokens for Furnace
        uint256 tokensToTransfer = numTokens.sub(tokensForFurnace);
        // transfer tokens to recipient
        bool succTwo = IERC20(_token).transfer(receiver, tokensToTransfer);
        // transfer tokens to furnace
        bool success = IERC20(_token).transfer(_uselessFurnace, tokensForFurnace);
        // require success
        require(succTwo, 'Failure on Transfer To Recipient');
        require(success, 'Failure on Transfer To Furnace');
        return true;
    }
    
    /** Swaps BNB For Useless, sending fee to furnace */
    function purchaseToken() private nonReentrant {
        // fee removed for Useless Furnace
        uint256 furnaceFee = msg.value.div(_buyFee);
        // amount to swap for USELESS
        uint256 bnbToSwap = msg.value.sub(furnaceFee);
        // Swap BNB for Token
        try _router.swapExactETHForTokens{value: bnbToSwap}(
            0,
            buyPath,
            address(this),
            block.timestamp.add(30)
        ) {} catch{revert();}
        // balance after
        uint256 balance = IERC20(_token).balanceOf(address(this));
        // transfer balance after to sender
        bool successful = IERC20(_token).transfer(_surgeUseless, balance);
        // ensure transfer was successful
        require(successful, 'Failed on Token Transfer');
        // send proceeds to furnace
        (bool success,) = payable(_uselessFurnace).call{value: furnaceFee}("");
        require(success, 'Furnace Payment Failed');
    }
    
    // Swap For Useless
    receive() external payable {
        purchaseToken();
    }

    // EVENTS
    event UpdatesLocked();
    event OwnerWithdrawBNB(uint256 numBNB);
    event OwnershipTransfered(address newOwner);
    event UpdatedPancakeswapRouter(address newRouter);
    event UpdatedFees(uint256 buyFee, uint256 sellFee);
    event UpdatedSurgeUselessAddress(address newSurgeUseless);
    event UpdateFurnaceContractAddress(address newFurnaceContractAddrss);
    event UpdatedUselessContractAddress(address newUselessContractAddress);
  
}  