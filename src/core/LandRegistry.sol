// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ILandRegistry } from "../interfaces/ILandRegistry.sol";
import { IStakingVault } from "../interfaces/IStakingVault.sol";
import { ITokenFactory } from "../interfaces/ITokenFactory.sol";
import { ILandToken } from "../interfaces/ILandToken.sol";
import { LandLib } from "../libraries/LandLib.sol";
import { ValidationLib } from "../libraries/ValidationLib.sol";

/**
 * @title LandRegistry
 * @notice Central registry for all tokenized properties
 * @dev Manages property registration, verification, and tokenization workflow
 */
contract LandRegistry is ILandRegistry, Ownable, ReentrancyGuard {
    using LandLib for *;
    using ValidationLib for *;

    // Property tracking
    mapping(bytes32 => LandLib.PropertyData) public properties;
    mapping(address => bytes32[]) public ownerProperties;
    mapping(bytes32 => bool) public isBlacklisted;

    // Token tracking
    mapping(address => bytes32) public tokenToProperty;
    address[] private _allTokens;

    // Agency control
    mapping(address => bool) public isVerifier;
    address public stakingVault;
    address public tokenFactory;

    // Statistics
    uint256 public totalPropertiesRegistered;
    uint256 public totalPropertiesVerified;
    uint256 public totalPropertiesSlashed;
    uint256 public totalValueTokenized;

    // Errors
    error NotVerifier();
    error PropertyAlreadyExists(bytes32 propertyId);
    error PropertyNotFound(bytes32 propertyId);
    error InvalidStatus(LandLib.PropertyStatus current, LandLib.PropertyStatus required);
    error PropertyBlacklisted(bytes32 propertyId);
    error InsufficientStake(uint256 provided, uint256 required);
    error InvalidStatusTransition(LandLib.PropertyStatus from, LandLib.PropertyStatus to);

    // Modifiers
    modifier onlyVerifier() {
        if (!isVerifier[msg.sender]) revert NotVerifier();
        _;
    }

    modifier propertyExists(bytes32 propertyId) {
        if (properties[propertyId].status == LandLib.PropertyStatus.None) {
            revert PropertyNotFound(propertyId);
        }
        _;
    }

    /**
     * @notice Constructor
     */
    constructor() Ownable(msg.sender) {
        // Owner is initial verifier
        isVerifier[msg.sender] = true;
    }

    /**
     * @notice Register a new property for tokenization
     * @param metadata Property metadata
     * @param stakeAmount USDC stake amount
     * @return propertyId Unique property identifier
     */
    function registerProperty(LandLib.PropertyMetadata calldata metadata, uint256 stakeAmount)
        external
        nonReentrant
        returns (bytes32 propertyId)
    {
        // Validate metadata
        LandLib.validateMetadata(metadata);

        // Generate unique property ID
        propertyId = LandLib.generatePropertyId(metadata, block.timestamp);

        // Check if already exists
        if (properties[propertyId].status != LandLib.PropertyStatus.None) {
            revert PropertyAlreadyExists(propertyId);
        }

        // Check if blacklisted
        if (isBlacklisted[propertyId]) {
            revert PropertyBlacklisted(propertyId);
        }

        // Validate stake amount (minimum 5%)
        uint256 minStake = LandLib.calculateMinStake(metadata.valuation);
        if (stakeAmount < minStake) {
            revert InsufficientStake(stakeAmount, minStake);
        }

        // Create property data
        properties[propertyId] = LandLib.PropertyData({
            id: propertyId,
            owner: msg.sender,
            metadata: metadata,
            status: LandLib.PropertyStatus.Pending,
            stakeAmount: stakeAmount,
            tokenAddress: address(0),
            registeredAt: block.timestamp,
            verifiedAt: 0
        });

        // Track ownership
        ownerProperties[msg.sender].push(propertyId);

        // Update statistics
        totalPropertiesRegistered++;

        emit PropertyRegistered(propertyId, msg.sender, metadata.valuation);

        return propertyId;
    }

    /**
     * @notice Verify or reject a property (only callable by verifiers)
     * @param propertyId Property to verify
     * @param approved True to approve, false to reject
     */
    function verifyProperty(bytes32 propertyId, bool approved)
        external
        onlyVerifier
        nonReentrant
        propertyExists(propertyId)
    {
        LandLib.PropertyData storage prop = properties[propertyId];

        // Must be in Pending status
        if (prop.status != LandLib.PropertyStatus.Pending) {
            revert InvalidStatus(prop.status, LandLib.PropertyStatus.Pending);
        }

        if (approved) {
            // Approve property
            prop.status = LandLib.PropertyStatus.Verified;
            prop.verifiedAt = block.timestamp;
            totalPropertiesVerified++;

            // Create token via factory
            address tokenAddress = ITokenFactory(tokenFactory).createLandToken(prop.owner, prop.metadata, propertyId);

            prop.tokenAddress = tokenAddress;
            tokenToProperty[tokenAddress] = propertyId;
            _allTokens.push(tokenAddress);

            // Update total value
            totalValueTokenized += prop.metadata.valuation;

            // Release stake with bonus
            IStakingVault(stakingVault).releaseStake(prop.owner, prop.stakeAmount, true);

            // Activate token trading
            ILandToken(tokenAddress).activateTrading();

            emit PropertyVerified(propertyId, tokenAddress);
        } else {
            // Reject property
            prop.status = LandLib.PropertyStatus.Rejected;

            // Return stake minus fee
            IStakingVault(stakingVault).releaseStake(prop.owner, prop.stakeAmount, false);

            emit PropertyRejected(propertyId, "Property verification failed");
        }
    }

    /**
     * @notice Slash a fraudulent property
     * @param propertyId Property to slash
     * @param evidence IPFS hash or description of fraud evidence
     */
    function slashProperty(bytes32 propertyId, string calldata evidence)
        external
        onlyVerifier
        nonReentrant
        propertyExists(propertyId)
    {
        LandLib.PropertyData storage prop = properties[propertyId];

        // Can only slash pending properties
        if (prop.status != LandLib.PropertyStatus.Pending) {
            revert InvalidStatus(prop.status, LandLib.PropertyStatus.Pending);
        }

        // Update status
        prop.status = LandLib.PropertyStatus.Slashed;
        isBlacklisted[propertyId] = true;
        totalPropertiesSlashed++;

        // Slash stake (funds go to treasury)
        IStakingVault(stakingVault).slashStake(prop.owner, prop.stakeAmount);

        emit PropertySlashed(propertyId, prop.stakeAmount);
    }

    /**
     * @notice Activate trading for a verified property
     * @param propertyId Property identifier
     */
    function activateTrading(bytes32 propertyId) external onlyVerifier propertyExists(propertyId) {
        LandLib.PropertyData storage prop = properties[propertyId];

        if (prop.status != LandLib.PropertyStatus.Verified) {
            revert InvalidStatus(prop.status, LandLib.PropertyStatus.Verified);
        }

        prop.status = LandLib.PropertyStatus.Trading;

        // Activate token trading
        if (prop.tokenAddress != address(0)) {
            ILandToken(prop.tokenAddress).activateTrading();
        }
    }

    /**
     * @notice Add a verifier
     * @param verifier Address to add as verifier
     */
    function addVerifier(address verifier) external onlyOwner {
        ValidationLib.validateAddress(verifier);
        isVerifier[verifier] = true;
        emit VerifierAdded(verifier);
    }

    /**
     * @notice Remove a verifier
     * @param verifier Address to remove
     */
    function removeVerifier(address verifier) external onlyOwner {
        isVerifier[verifier] = false;
        emit VerifierRemoved(verifier);
    }

    /**
     * @notice Set staking vault address
     * @param vault Address of StakingVault contract
     */
    function setStakingVault(address vault) external onlyOwner {
        ValidationLib.validateAddress(vault);
        address oldVault = stakingVault;
        stakingVault = vault;
        emit StakingVaultUpdated(oldVault, vault);
    }

    /**
     * @notice Set token factory address
     * @param factory Address of TokenFactory contract
     */
    function setTokenFactory(address factory) external onlyOwner {
        ValidationLib.validateAddress(factory);
        address oldFactory = tokenFactory;
        tokenFactory = factory;
        emit TokenFactoryUpdated(oldFactory, factory);
    }

    /**
     * @notice Get property data
     * @param propertyId Property identifier
     * @return PropertyData struct
     */
    function getPropertyData(bytes32 propertyId) external view returns (LandLib.PropertyData memory) {
        return properties[propertyId];
    }

    /**
     * @notice Get property status
     * @param propertyId Property identifier
     * @return PropertyStatus enum
     */
    function getPropertyStatus(bytes32 propertyId) external view returns (LandLib.PropertyStatus) {
        return properties[propertyId].status;
    }

    /**
     * @notice Get all properties owned by an address
     * @param owner Owner address
     * @return bytes32[] Array of property IDs
     */
    function getOwnerProperties(address owner) external view returns (bytes32[] memory) {
        return ownerProperties[owner];
    }

    /**
     * @notice Get all tokenized properties
     * @return address[] Array of token addresses
     */
    function getAllTokens() external view returns (address[] memory) {
        return _allTokens;
    }

    /**
     * @notice Calculate minimum stake required
     * @param valuation Property valuation
     * @return uint256 Minimum stake (5% of valuation)
     */
    function calculateMinStake(uint256 valuation) external pure returns (uint256) {
        return LandLib.calculateMinStake(valuation);
    }

    /**
     * @notice Get registry statistics
     * @return registered Total properties registered
     * @return verified Total properties verified
     * @return slashed Total properties slashed
     * @return totalValue Total value tokenized
     */
    function getStatistics()
        external
        view
        returns (uint256 registered, uint256 verified, uint256 slashed, uint256 totalValue)
    {
        return (totalPropertiesRegistered, totalPropertiesVerified, totalPropertiesSlashed, totalValueTokenized);
    }
}
