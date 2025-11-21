// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStakingVault
 * @notice Interface for the StakingVault contract
 */
interface IStakingVault {
    // Events
    event StakeDeposited(address indexed owner, uint256 amount);
    event StakeReleased(address indexed owner, uint256 amount, bool withBonus);
    event StakeSlashed(address indexed owner, uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event EmergencyWithdrawal(address indexed owner, uint256 amount);
    event BonusPoolFunded(address indexed funder, uint256 amount, uint256 newTotal);

    // Functions
    function depositStake(uint256 amount) external;

    function fundBonusPool(uint256 amount) external;

    function releaseStake(address owner, uint256 amount, bool approved) external;

    function slashStake(address owner, uint256 amount) external;

    function emergencyWithdraw() external;

    function stakes(address owner) external view returns (uint256);

    function stakeTimestamp(address owner) external view returns (uint256);

    function bonusPool() external view returns (uint256);

    function totalBonusPaid() external view returns (uint256);

    function totalStaked() external view returns (uint256);

    function totalSlashed() external view returns (uint256);

    function totalReturned() external view returns (uint256);

    function getBonusPoolStatus() external view returns (uint256 available, uint256 totalPaid);

    function setTreasury(address newTreasury) external;
}
