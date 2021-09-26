pragma solidity 0.8.4;
// SPDX-License-Identifier: Unlicensed

import "./IUniswapV2Router02.sol";
import "./IEmergencySurge.sol";

contract SurgeDatabase {

    address public _owner;

    address public _dexRouterV2;

    address public _fundingReceiver;

    mapping ( address => address ) pcsRouter;
    mapping ( address => bool ) allowFunding;
    mapping ( address => bool ) isApprovedLP;
    mapping ( address => bool ) isVerifiedToken;
    mapping ( address => uint256) fundBuyFee;
    mapping ( address => uint256) fundTransferFee;
    
    uint256 defaultFundFeeBuys = 100;
    uint256 defaultFundFeeTransfers = 4;
    
    address busd;

    modifier onlyOwner(){require(msg.sender == _owner, 'Only Owner'); _;}

    constructor() {
        _owner = msg.sender;
        _dexRouterV2 = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        _fundingReceiver = 0x95c8eE08b40107f5bd70c28c4Fd96341c8eaD9c7;
        isApprovedLP[0x2eC1108d6b86846b845eb9Ec80a01be98C90a2ec] = true;
        busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    }
    
    function setFundingBuyFeeForToken(address token, uint256 fee) external onlyOwner {
        fundBuyFee[token] = fee;
    }
    
    function setFundingTransferFeeForToken(address token, uint256 fee) external onlyOwner {
        fundTransferFee[token] = fee;
    }
    
    function getFundingBuyFeeForToken(address token) external view returns (uint256) {
        return fundBuyFee[token] == 0 ? defaultFundFeeBuys : fundBuyFee[token];
    }
    
    function getFundingTransferFeeForToken(address token) external view returns (uint256) {
        return fundTransferFee[token] == 0 ? defaultFundFeeTransfers : fundTransferFee[token];
    }
 
    function allowFundingForToken(address token) external view returns (bool) {
        return allowFunding[token];
    }

    function getPCSRouterForToken(address token) public view returns (address) {
        address addr = pcsRouter[token];
        return addr == address(0) ? _dexRouterV2 : addr;
    }

    function getFundingReceiver() external view returns (address) {
        return _fundingReceiver;
    }

    function getIsApprovedLP(address potentialLP) external view returns (bool) {
        return isApprovedLP[potentialLP];
    }
        
    function isTokenVerified(address _token) external view returns (bool) {
        return isVerifiedToken[_token];
    }

    /** Returns Value of Holdings in USD */
    function getValueOfHoldingsInUSD(address underlyingAsset, uint256 amount) public view returns(uint256) {
        if (amount == 0) return 0;
        IUniswapV2Router02 router = IUniswapV2Router02(getPCSRouterForToken(msg.sender));
        address[] memory path = new address[](2);
        path[0] = underlyingAsset;
        path[1] = router.WETH();
        
        address[] memory bnbToBusd = new address[](2);
        path[0] = router.WETH();
        path[1] = busd;
        
        uint256 assetInBNB = router.getAmountsOut(amount, path)[1];
        return router.getAmountsOut(assetInBNB, bnbToBusd)[1]; 
    }
    
    /** Returns Value of Underlying Asset in USD */
    function getValueOfUnderlyingAssetInUSD(address token) public view returns(uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(getPCSRouterForToken(msg.sender)); 
        
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = router.WETH();
        
        address[] memory bnbToBusd = new address[](2);
        path[0] = router.WETH();
        path[1] = busd;
        
        uint256 assetInBNB = router.getAmountsOut(10**18, path)[1];
        return router.getAmountsOut(assetInBNB, bnbToBusd)[1];
    }
    
    function verifyToken(address token, bool isVerified) external onlyOwner {
        isVerifiedToken[token] = isVerified;
    }
        
    function updateBUSDAddress(address newBUSD) external onlyOwner {
        busd = newBUSD;
    }

    function setIsApprovedLP(address lp, bool approved) external onlyOwner {
        isApprovedLP[lp] = approved;
    }

    function setFundingReceiver(address newReceiver) external onlyOwner {
        _fundingReceiver = newReceiver;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        _owner = newOwner;
    }
    
    function enableEmergencyModeForToken(address token) external onlyOwner {
        IEmergencySurge(token).enableEmergencyMode();
    }
    
    function setAllowFundingForToken(address token, bool allow) external {
        require(msg.sender == _owner || msg.sender == token, 'Invalid Entry');
        allowFunding[token] = allow;
    }

}