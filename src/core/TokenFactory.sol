// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ITokenFactory } from "../interfaces/ITokenFactory.sol";
import { ILandToken } from "../interfaces/ILandToken.sol";
import { LandToken } from "./LandToken.sol";
import { LandLib } from "../libraries/LandLib.sol";
import { ValidationLib } from "../libraries/ValidationLib.sol";

/**
 * @title TokenFactory
 * @notice Factory contract for deploying LandToken contracts
 * @dev Uses CREATE2 for deterministic addresses
 */
contract TokenFactory is ITokenFactory, Ownable {
    using LandLib for *;
    using ValidationLib for *;

    // State variables
    address public immutable LAND_REGISTRY;
    address public feeRecipient;

    // Constants
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 250; // 2.5% in basis points
    uint256 public constant TOKEN_PRICE = 10e6; // 10 USDC per token (6 decimals)

    // Tracking
    mapping(bytes32 => address) public propertyToToken;
    mapping(address => bool) public isFactoryToken; // Track tokens created by this factory
    address[] private _allTokens;

    // Errors
    error OnlyRegistry();
    error TokenAlreadyExists(bytes32 propertyId, address existingToken);
    error InvalidTokenPrice();
    error TokenNotFromFactory(address token);
    error InsufficientFactoryBalance(uint256 available, uint256 required);

    // Modifiers
    modifier onlyRegistry() {
        if (msg.sender != LAND_REGISTRY) revert OnlyRegistry();
        _;
    }

    /**
     * @notice Constructor
     * @param _landRegistry Address of LandRegistry contract
     * @param _feeRecipient Address to receive platform fees
     */
    constructor(address _landRegistry, address _feeRecipient) Ownable(msg.sender) {
        ValidationLib.validateAddress(_landRegistry);
        ValidationLib.validateAddress(_feeRecipient);

        LAND_REGISTRY = _landRegistry;
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice Create a new LandToken for a verified property
     * @param owner Property owner
     * @param metadata Property metadata
     * @param propertyId Unique property identifier
     * @return tokenAddress Address of deployed token
     */
    function createLandToken(address owner, LandLib.PropertyMetadata memory metadata, bytes32 propertyId)
        external
        onlyRegistry
        returns (address tokenAddress)
    {
        ValidationLib.validateAddress(owner);
        LandLib.validateMetadata(metadata);

        // Check if token already exists
        if (propertyToToken[propertyId] != address(0)) {
            revert TokenAlreadyExists(propertyId, propertyToToken[propertyId]);
        }

        // Calculate token allocation
        LandLib.TokenAllocation memory allocation = LandLib.calculateTokenAllocation(metadata.valuation, TOKEN_PRICE);

        // Generate token name and symbol
        string memory tokenName = _generateTokenName(metadata);
        string memory tokenSymbol = _generateTokenSymbol(metadata);

        // Deploy token using CREATE2 for deterministic address
        bytes32 salt = keccak256(abi.encodePacked(propertyId, block.timestamp));

        LandToken newToken = new LandToken{ salt: salt }(tokenName, tokenSymbol, LAND_REGISTRY, propertyId);

        tokenAddress = address(newToken);

        // Initialize token
        newToken.initialize(owner, allocation.totalSupply, allocation.ownerAllocation, metadata, propertyId);

        // Mint tokens
        newToken.mint(owner, allocation.ownerAllocation); // Owner's 51%
        newToken.mint(feeRecipient, allocation.platformFee); // Platform fee 2.5%
        newToken.mint(address(this), allocation.publicSale); // For primary market

        // Exempt factory and primary market from transfer locks
        newToken.setTransferLockExemption(address(this), true);

        // Transfer ownership to registry for management
        newToken.transferOwnership(LAND_REGISTRY);

        // Track token
        propertyToToken[propertyId] = tokenAddress;
        isFactoryToken[tokenAddress] = true; // Mark as factory-created
        _allTokens.push(tokenAddress);

        emit TokenCreated(tokenAddress, propertyId, owner, allocation.totalSupply);

        return tokenAddress;
    }

    /**
     * @notice Transfer tokens held by factory to primary market
     * @param tokenAddress Token to transfer
     * @param primaryMarket Address of primary market
     * @param amount Amount to transfer
     * @dev Only works with tokens created by this factory
     */
    function transferToPrimaryMarket(address tokenAddress, address primaryMarket, uint256 amount) external onlyOwner {
        ValidationLib.validateAddress(tokenAddress);
        ValidationLib.validateAddress(primaryMarket);
        ValidationLib.validateNonZero(amount);

        // Verify token was created by this factory
        if (!isFactoryToken[tokenAddress]) {
            revert TokenNotFromFactory(tokenAddress);
        }

        // Verify we have sufficient balance
        uint256 balance = ILandToken(tokenAddress).balanceOf(address(this));
        if (balance < amount) {
            revert InsufficientFactoryBalance(balance, amount);
        }

        ILandToken(tokenAddress).transfer(primaryMarket, amount);
    }

    /**
     * @notice Set fee recipient address
     * @param newRecipient New fee recipient
     */
    function setFeeRecipient(address newRecipient) external onlyOwner {
        ValidationLib.validateAddress(newRecipient);

        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;

        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /**
     * @notice Get all deployed tokens
     * @return address[] Array of token addresses
     */
    function getAllTokens() external view returns (address[] memory) {
        return _allTokens;
    }

    /**
     * @notice Get token at specific index
     * @param index Index in array
     * @return address Token address
     */
    function allTokens(uint256 index) external view returns (address) {
        return _allTokens[index];
    }

    /**
     * @notice Get total number of deployed tokens
     * @return uint256 Token count
     */
    function getTokenCount() external view returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @notice Compute the address where a token will be deployed
     * @param propertyId Property identifier
     * @return address Predicted token address
     * @dev Note: This is approximate as it doesn't include timestamp in salt
     */
    function computeTokenAddress(bytes32 propertyId) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(propertyId, block.timestamp));

        bytes memory bytecode = type(LandToken).creationCode;
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(abi.encodePacked(bytecode, abi.encode("", "", LAND_REGISTRY, propertyId)))
            )
        );

        return address(uint160(uint256(hash)));
    }

    /**
     * @notice Generate token name from metadata
     * @param metadata Property metadata
     * @return string Token name
     */
    function _generateTokenName(LandLib.PropertyMetadata memory metadata) internal pure returns (string memory) {
        return string(abi.encodePacked("Land Token - ", metadata.location));
    }

    /**
     * @notice Generate token symbol from metadata
     * @param metadata Property metadata
     * @return string Token symbol
     */
    function _generateTokenSymbol(LandLib.PropertyMetadata memory metadata) internal pure returns (string memory) {
        string memory prefix = LandLib.extractLocationPrefix(metadata.location);
        return string(abi.encodePacked(prefix, "LAND"));
    }
}
