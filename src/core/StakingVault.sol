// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IStakingVault } from "../interfaces/IStakingVault.sol";
import { ValidationLib } from "../libraries/ValidationLib.sol";

/**
 * @title StakingVault
 * @notice Manages USDC stakes for property verification
 * @dev Property owners stake USDC which is held in escrow during verification
 */
contract StakingVault is IStakingVault, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ValidationLib for *;

    // State variables
    IERC20 public immutable STAKE_TOKEN; // USDC or other stablecoin
    address public immutable LAND_REGISTRY; // Only registry can release/slash
    address public treasury; // Receives slashed funds and fees

    // Stake tracking
    mapping(address => uint256) public stakes;
    mapping(address => uint256) public stakeTimestamp;

    // Bonus pool tracking (separate from stakes)
    uint256 public bonusPool; // Treasury-funded bonus pool
    uint256 public totalBonusPaid; // Track total bonuses paid out

    // Constants
    uint256 public constant VERIFICATION_PERIOD = 72 hours;
    uint256 public constant BONUS_PERCENTAGE = 2; // 2% bonus on approval
    uint256 public constant REJECT_FEE = 1; // 1% fee on rejection

    // Statistics
    uint256 public totalStaked;
    uint256 public totalSlashed;
    uint256 public totalReturned;

    // Errors
    error OnlyRegistry();
    error InsufficientStake(uint256 available, uint256 required);
    error TooEarlyToWithdraw(uint256 availableAt, uint256 currentTime);
    error InsufficientBonusPool(uint256 required, uint256 available);

    // Modifiers
    modifier onlyRegistry() {
        if (msg.sender != LAND_REGISTRY) revert OnlyRegistry();
        _;
    }

    /**
     * @notice Constructor
     * @param _stakeToken Address of staking token (USDC)
     * @param _landRegistry Address of LandRegistry contract
     * @param _treasury Address to receive fees and slashed stakes
     */
    constructor(address _stakeToken, address _landRegistry, address _treasury) Ownable(msg.sender) {
        ValidationLib.validateAddress(_stakeToken);
        ValidationLib.validateAddress(_landRegistry);
        ValidationLib.validateAddress(_treasury);

        STAKE_TOKEN = IERC20(_stakeToken);
        LAND_REGISTRY = _landRegistry;
        treasury = _treasury;
    }

    /**
     * @notice Deposit stake for property verification
     * @param amount Amount of USDC to stake
     */
    function depositStake(uint256 amount) external nonReentrant {
        ValidationLib.validateNonZero(amount);

        stakes[msg.sender] += amount;
        stakeTimestamp[msg.sender] = block.timestamp;
        totalStaked += amount;

        STAKE_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        emit StakeDeposited(msg.sender, amount);
    }

    /**
     * @notice Fund the bonus pool (callable by treasury/owner)
     * @param amount Amount of USDC to add to bonus pool
     * @dev Rejection fees and slashes automatically replenish this pool
     */
    function fundBonusPool(uint256 amount) external onlyOwner nonReentrant {
        ValidationLib.validateNonZero(amount);

        bonusPool += amount;

        STAKE_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        emit BonusPoolFunded(msg.sender, amount, bonusPool);
    }

    /**
     * @notice Release stake after verification (only callable by LandRegistry)
     * @param owner Property owner
     * @param amount Stake amount to release
     * @param approved True if property was approved, false if rejected
     */
    function releaseStake(address owner, uint256 amount, bool approved) external onlyRegistry nonReentrant {
        ValidationLib.validateAddress(owner);
        ValidationLib.validateNonZero(amount);

        if (stakes[owner] < amount) {
            revert InsufficientStake(stakes[owner], amount);
        }

        stakes[owner] -= amount;
        uint256 returnAmount;

        if (approved) {
            // Add 2% bonus for approved property (comes from bonus pool)
            uint256 bonus = (amount * BONUS_PERCENTAGE) / 100;

            // Ensure bonus pool has sufficient funds
            if (bonusPool < bonus) {
                revert InsufficientBonusPool(bonus, bonusPool);
            }

            returnAmount = amount + bonus;
            bonusPool -= bonus; // Deduct from bonus pool
            totalBonusPaid += bonus;
            totalReturned += returnAmount;

            emit StakeReleased(owner, returnAmount, true);
        } else {
            // Deduct 1% fee for rejected property
            uint256 fee = (amount * REJECT_FEE) / 100;
            returnAmount = amount - fee;

            // Add rejection fee to bonus pool (auto-replenishes)
            if (fee > 0) {
                bonusPool += fee;
            }

            emit StakeReleased(owner, returnAmount, false);
        }

        // Transfer stake back to owner
        STAKE_TOKEN.safeTransfer(owner, returnAmount);
    }

    /**
     * @notice Slash stake for fraudulent property (only callable by LandRegistry)
     * @param owner Property owner
     * @param amount Stake amount to slash
     */
    function slashStake(address owner, uint256 amount) external onlyRegistry nonReentrant {
        ValidationLib.validateAddress(owner);
        ValidationLib.validateNonZero(amount);

        if (stakes[owner] < amount) {
            revert InsufficientStake(stakes[owner], amount);
        }

        stakes[owner] -= amount;
        totalSlashed += amount;

        // Split slashed funds: 50% to bonus pool, 50% to treasury
        uint256 toBonus = amount / 2;
        uint256 toTreasury = amount - toBonus;

        bonusPool += toBonus;

        if (toTreasury > 0) {
            STAKE_TOKEN.safeTransfer(treasury, toTreasury);
        }

        emit StakeSlashed(owner, amount);
    }

    /**
     * @notice Emergency withdrawal after verification period + 7 days
     * @dev Allows users to withdraw if verification is stuck
     */
    function emergencyWithdraw() external nonReentrant {
        uint256 amount = stakes[msg.sender];
        ValidationLib.validateNonZero(amount);

        uint256 withdrawalAvailable = stakeTimestamp[msg.sender] + VERIFICATION_PERIOD + 7 days;

        if (block.timestamp < withdrawalAvailable) {
            revert TooEarlyToWithdraw(withdrawalAvailable, block.timestamp);
        }

        stakes[msg.sender] = 0;

        STAKE_TOKEN.safeTransfer(msg.sender, amount);

        emit EmergencyWithdrawal(msg.sender, amount);
    }

    /**
     * @notice Update treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        ValidationLib.validateAddress(newTreasury);

        address oldTreasury = treasury;
        treasury = newTreasury;

        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Get total USDC balance in vault
     * @return uint256 Total balance
     */
    function getTotalBalance() external view returns (uint256) {
        return STAKE_TOKEN.balanceOf(address(this));
    }

    /**
     * @notice Get bonus pool status
     * @return available Available bonus funds
     * @return totalPaid Total bonuses paid historically
     */
    function getBonusPoolStatus() external view returns (uint256 available, uint256 totalPaid) {
        return (bonusPool, totalBonusPaid);
    }

    /**
     * @notice Emergency withdraw from bonus pool (owner only)
     * @param amount Amount to withdraw
     * @dev Only for emergency situations, should not be used in normal operations
     */
    function emergencyWithdrawBonusPool(uint256 amount) external onlyOwner nonReentrant {
        ValidationLib.validateNonZero(amount);

        if (amount > bonusPool) {
            revert InsufficientBonusPool(amount, bonusPool);
        }

        bonusPool -= amount;
        STAKE_TOKEN.safeTransfer(treasury, amount);
    }
}
