//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "./IERC20.sol";

/**
 * Exempt Surge Interface
 */
interface IStakableSurge is IERC20 {
    function sell(uint256 amount) external;
    function getUnderlyingAsset() external returns(address);
    function stakeUnderlyingAsset(uint256 numTokens) external returns(bool);
    function enableEmergencyMode() external;
}
