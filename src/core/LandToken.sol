// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ILandToken } from "../interfaces/ILandToken.sol";
import { LandLib } from "../libraries/LandLib.sol";
import { ValidationLib } from "../libraries/ValidationLib.sol";

/**
 * @title LandToken
 * @notice ERC20 token representing fractional ownership of a specific property
 * @dev Each property gets its own ERC20 token with transfer restrictions
 */
contract LandToken is ERC20, ERC20Burnable, Pausable, Ownable, ILandToken {
    using ValidationLib for *;

    // Immutable data
    address public immutable LAND_REGISTRY;
    bytes32 public immutable PROPERTY_ID;

    // Property metadata
    string public ipfsDocumentHash;
    int256 public latitude;
    int256 public longitude;
    uint256 public landAreaSqFt;
    uint256 public initialValuation;

    // Time locks
    uint256 public constant VERIFICATION_LOCK_PERIOD = 72 hours;
    uint256 public constant OWNER_LOCK_PERIOD = 180 days;
    uint256 public deploymentTimestamp;

    // Allocation tracking
    address public originalOwner;
    uint256 public ownerAllocation; // Minimum tokens owner must hold
    mapping(address => bool) public isExemptFromLock;

    // Status
    TokenStatus public status;

    // Initialization guard
    bool private initialized;

    // Errors
    error AlreadyInitialized();
    error NotInitialized();
    error OnlyRegistry();
    error OnlyFactory();
    error TradingNotActive();
    error VerificationPending();
    error OwnerLockActive(uint256 unlockTime);
    error BelowMinimumOwnership(uint256 required, uint256 remaining);

    // Modifiers
    modifier onlyRegistry() {
        if (msg.sender != LAND_REGISTRY) revert OnlyRegistry();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != owner()) revert OnlyFactory();
        _;
    }

    modifier whenInitialized() {
        if (!initialized) revert NotInitialized();
        _;
    }

    /**
     * @notice Constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param _landRegistry Address of LandRegistry contract
     */
    constructor(string memory name_, string memory symbol_, address _landRegistry, bytes32 _propertyId)
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {
        ValidationLib.validateAddress(_landRegistry);

        LAND_REGISTRY = _landRegistry;
        PROPERTY_ID = _propertyId;
        deploymentTimestamp = block.timestamp;
    }

    /**
     * @notice Initialize token with property data (called by factory)
     * @param _owner Property owner address
     * @param _totalSupply Total token supply
     * @param _ownerAllocation Tokens for owner (51%)
     * @param metadata Property metadata
     * @param _propertyId Property identifier
     */
    function initialize(
        address _owner,
        uint256 _totalSupply,
        uint256 _ownerAllocation,
        LandLib.PropertyMetadata memory metadata,
        bytes32 _propertyId
    ) external onlyFactory {
        if (initialized) revert AlreadyInitialized();

        ValidationLib.validateAddress(_owner);
        ValidationLib.validateNonZero(_totalSupply);
        ValidationLib.validateNonZero(_ownerAllocation);

        // Store metadata
        ipfsDocumentHash = metadata.ipfsHash;
        latitude = metadata.latitude;
        longitude = metadata.longitude;
        landAreaSqFt = metadata.areaSqFt;
        initialValuation = metadata.valuation;

        // Store owner info
        originalOwner = _owner;
        ownerAllocation = _ownerAllocation;

        // Exempt factory from locks (for initial distribution)
        isExemptFromLock[msg.sender] = true;
        isExemptFromLock[address(this)] = true;

        // Set initial status
        status = TokenStatus.Pending;

        initialized = true;
    }

    /**
     * @notice Mint tokens (only callable by factory during initialization)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyFactory {
        ValidationLib.validateAddress(to);
        ValidationLib.validateNonZero(amount);
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) public override(ERC20Burnable, ILandToken) {
        ValidationLib.validateNonZero(amount);
        super.burn(amount);
    }

    /**
     * @notice Activate trading after verification (only callable by registry)
     */
    function activateTrading() external onlyRegistry whenInitialized {
        if (status == TokenStatus.Pending) {
            status = TokenStatus.Verified;
        } else if (status == TokenStatus.Verified) {
            status = TokenStatus.Trading;
        }

        emit StatusChanged(status, TokenStatus.Trading);
    }

    /**
     * @notice Pause all token transfers
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Update IPFS document hash
     * @param newHash New IPFS hash
     */
    function updateIPFSHash(string memory newHash) external onlyOwner {
        ValidationLib.validateIPFSHash(newHash);
        ipfsDocumentHash = newHash;
        emit PropertyMetadataUpdated(newHash);
    }

    /**
     * @notice Exempt an address from transfer locks (e.g., DEX contracts)
     * @param account Address to exempt
     * @param exempt True to exempt, false to remove exemption
     */
    function setTransferLockExemption(address account, bool exempt) external onlyOwner {
        ValidationLib.validateAddress(account);
        isExemptFromLock[account] = exempt;
    }

    /**
     * @notice Override transfer to enforce restrictions
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function _update(address from, address to, uint256 amount) internal override whenNotPaused {
        // Allow minting and burning
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // Check verification lock
        if (status == TokenStatus.Pending && !isExemptFromLock[from]) {
            revert VerificationPending();
        }

        // Check owner lock period (180 days)
        if (from == originalOwner && !isExemptFromLock[from]) {
            uint256 unlockTime = deploymentTimestamp + OWNER_LOCK_PERIOD;

            if (block.timestamp < unlockTime) {
                // Owner can only transfer excess beyond their minimum allocation
                uint256 balanceAfter = balanceOf(originalOwner) - amount;

                if (balanceAfter < ownerAllocation) {
                    revert OwnerLockActive(unlockTime);
                }
            }
        }

        super._update(from, to, amount);
    }

    /**
     * @notice Get token information
     * @return name_ Token name
     * @return symbol_ Token symbol
     * @return totalSupply_ Total token supply
     * @return owner_ Original property owner
     * @return status_ Current token status
     * @return valuation_ Initial property valuation
     */
    function getTokenInfo()
        external
        view
        returns (
            string memory name_,
            string memory symbol_,
            uint256 totalSupply_,
            address owner_,
            TokenStatus status_,
            uint256 valuation_
        )
    {
        return (name(), symbol(), totalSupply(), originalOwner, status, initialValuation);
    }

    /**
     * @notice Get property metadata
     * @return ipfs IPFS hash of property documents
     * @return lat Latitude coordinate
     * @return lon Longitude coordinate
     * @return area Land area in square feet
     * @return valuation Property valuation
     */
    function getPropertyMetadata()
        external
        view
        returns (string memory ipfs, int256 lat, int256 lon, uint256 area, uint256 valuation)
    {
        return (ipfsDocumentHash, latitude, longitude, landAreaSqFt, initialValuation);
    }

    /**
     * @notice Check if trading is active
     * @return bool True if trading is active
     */
    function isTradingActive() external view returns (bool) {
        return status == TokenStatus.Trading;
    }

    /**
     * @notice Get time until owner lock expires
     * @return uint256 Seconds until unlock (0 if already unlocked)
     */
    function getOwnerLockTimeRemaining() external view returns (uint256) {
        uint256 unlockTime = deploymentTimestamp + OWNER_LOCK_PERIOD;

        if (block.timestamp >= unlockTime) {
            return 0;
        }

        return unlockTime - block.timestamp;
    }
}
