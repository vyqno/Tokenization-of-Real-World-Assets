// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ILandToken } from "../interfaces/ILandToken.sol";
import { ILandRegistry } from "../interfaces/ILandRegistry.sol";
import { ValidationLib } from "../libraries/ValidationLib.sol";
import { MathLib } from "../libraries/MathLib.sol";

/**
 * @title PrimaryMarket
 * @notice Initial token sale for newly created land tokens
 * @dev Manages fixed-price sales before DEX listing with emergency pause capability
 */
contract PrimaryMarket is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ValidationLib for *;
    using MathLib for *;

    // State variables
    address public immutable LAND_REGISTRY;
    IERC20 public immutable PAYMENT_TOKEN; // USDC

    /**
     * @notice Sale configuration for a land token
     */
    struct Sale {
        address tokenAddress;
        uint256 tokensForSale;
        uint256 tokensSold;
        uint256 pricePerToken; // Price in payment token (e.g., USDC)
        uint256 startTime;
        uint256 endTime;
        address beneficiary; // Property owner who receives funds
        bool active;
        bool finalized;
    }

    // Sale tracking
    mapping(address => Sale) public sales;
    mapping(address => mapping(address => uint256)) public purchases; // token => buyer => amount

    // Configuration
    uint256 public constant SALE_DURATION = 72 hours;
    uint256 public constant MAX_PURCHASE_PERCENTAGE = 10; // 10% max per buyer
    uint256 public constant MIN_PURCHASE = 1e18; // Minimum 1 token

    // Events
    event SaleStarted(address indexed tokenAddress, uint256 tokensForSale, uint256 pricePerToken, uint256 endTime);
    event TokensPurchased(address indexed buyer, address indexed tokenAddress, uint256 amount, uint256 payment);
    event SaleFinalized(address indexed tokenAddress, uint256 tokensSold, uint256 unsoldTokens);
    event SaleCancelled(address indexed tokenAddress, string reason);

    // Errors
    error SaleNotActive();
    error SaleAlreadyActive();
    error SaleEnded();
    error SaleNotEnded();
    error BelowMinimumPurchase(uint256 amount, uint256 minimum);
    error ExceedsMaxPurchase(uint256 requested, uint256 maximum);
    error ExceedsAvailableSupply(uint256 requested, uint256 available);
    error AlreadyFinalized();

    /**
     * @notice Constructor
     * @param _landRegistry Address of LandRegistry
     * @param _paymentToken Address of payment token (USDC)
     */
    constructor(address _landRegistry, address _paymentToken) Ownable(msg.sender) {
        ValidationLib.validateAddress(_landRegistry);
        ValidationLib.validateAddress(_paymentToken);

        LAND_REGISTRY = _landRegistry;
        PAYMENT_TOKEN = IERC20(_paymentToken);
    }

    /**
     * @notice Start a new token sale
     * @param tokenAddress Address of land token to sell
     * @param tokensForSale Amount of tokens to sell
     * @param pricePerToken Price per token in payment token
     * @param beneficiary Address to receive sale proceeds
     */
    function startSale(address tokenAddress, uint256 tokensForSale, uint256 pricePerToken, address beneficiary)
        external
        onlyOwner
    {
        ValidationLib.validateAddress(tokenAddress);
        ValidationLib.validateNonZero(tokensForSale);
        ValidationLib.validateNonZero(pricePerToken);
        ValidationLib.validateAddress(beneficiary);

        if (sales[tokenAddress].active) revert SaleAlreadyActive();

        // Transfer tokens to this contract
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), tokensForSale);

        // Create sale
        sales[tokenAddress] = Sale({
            tokenAddress: tokenAddress,
            tokensForSale: tokensForSale,
            tokensSold: 0,
            pricePerToken: pricePerToken,
            startTime: block.timestamp,
            endTime: block.timestamp + SALE_DURATION,
            beneficiary: beneficiary,
            active: true,
            finalized: false
        });

        emit SaleStarted(tokenAddress, tokensForSale, pricePerToken, block.timestamp + SALE_DURATION);
    }

    /**
     * @notice Buy tokens from primary sale
     * @param tokenAddress Address of token to buy
     * @param amount Amount of tokens to buy
     */
    function buyTokens(address tokenAddress, uint256 amount) external nonReentrant whenNotPaused {
        Sale storage sale = sales[tokenAddress];

        // Validate sale
        if (!sale.active) revert SaleNotActive();
        if (block.timestamp > sale.endTime) revert SaleEnded();

        // Validate amount
        if (amount < MIN_PURCHASE) revert BelowMinimumPurchase(amount, MIN_PURCHASE);

        // Check max purchase limit (10% per buyer)
        uint256 maxPurchase = (sale.tokensForSale * MAX_PURCHASE_PERCENTAGE) / 100;
        uint256 totalPurchased = purchases[tokenAddress][msg.sender] + amount;

        if (totalPurchased > maxPurchase) {
            revert ExceedsMaxPurchase(totalPurchased, maxPurchase);
        }

        // Check available supply
        uint256 available = sale.tokensForSale - sale.tokensSold;
        if (amount > available) {
            revert ExceedsAvailableSupply(amount, available);
        }

        // Calculate payment (price is per token with 18 decimals)
        uint256 payment = (amount * sale.pricePerToken) / 1e18;

        // Update state
        sale.tokensSold += amount;
        purchases[tokenAddress][msg.sender] += amount;

        // Transfer payment from buyer
        PAYMENT_TOKEN.safeTransferFrom(msg.sender, address(this), payment);

        // Transfer tokens to buyer
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);

        emit TokensPurchased(msg.sender, tokenAddress, amount, payment);
    }

    /**
     * @notice Finalize sale after end time
     * @param tokenAddress Address of token sale to finalize
     */
    function finalizeSale(address tokenAddress) external nonReentrant {
        Sale storage sale = sales[tokenAddress];

        if (!sale.active) revert SaleNotActive();
        if (sale.finalized) revert AlreadyFinalized();

        // Can finalize if: sale ended OR all tokens sold
        bool saleEnded = block.timestamp > sale.endTime;
        bool allSold = sale.tokensSold == sale.tokensForSale;

        if (!saleEnded && !allSold) revert SaleNotEnded();

        sale.active = false;
        sale.finalized = true;

        uint256 unsoldTokens = sale.tokensForSale - sale.tokensSold;

        // Burn unsold tokens
        if (unsoldTokens > 0) {
            ILandToken(tokenAddress).burn(unsoldTokens);
        }

        // Transfer collected funds to beneficiary
        uint256 collectedFunds = (sale.tokensSold * sale.pricePerToken) / 1e18;
        if (collectedFunds > 0) {
            PAYMENT_TOKEN.safeTransfer(sale.beneficiary, collectedFunds);
        }

        emit SaleFinalized(tokenAddress, sale.tokensSold, unsoldTokens);
    }

    /**
     * @notice Cancel an active sale (emergency only)
     * @param tokenAddress Address of token sale to cancel
     * @param reason Reason for cancellation
     */
    function cancelSale(address tokenAddress, string calldata reason) external onlyOwner {
        Sale storage sale = sales[tokenAddress];

        if (!sale.active) revert SaleNotActive();
        if (sale.tokensSold > 0) revert("Cannot cancel sale with purchases");

        sale.active = false;
        sale.finalized = true;

        // Return tokens to owner
        IERC20(tokenAddress).safeTransfer(msg.sender, sale.tokensForSale);

        emit SaleCancelled(tokenAddress, reason);
    }

    /**
     * @notice Get sale information
     * @param tokenAddress Token address
     * @return Sale struct
     */
    function getSale(address tokenAddress) external view returns (Sale memory) {
        return sales[tokenAddress];
    }

    /**
     * @notice Check if sale is active
     * @param tokenAddress Token address
     * @return bool True if active
     */
    function isSaleActive(address tokenAddress) external view returns (bool) {
        Sale memory sale = sales[tokenAddress];
        return sale.active && block.timestamp <= sale.endTime;
    }

    /**
     * @notice Get remaining tokens in sale
     * @param tokenAddress Token address
     * @return uint256 Remaining tokens
     */
    function getRemainingTokens(address tokenAddress) external view returns (uint256) {
        Sale memory sale = sales[tokenAddress];
        return sale.tokensForSale - sale.tokensSold;
    }

    /**
     * @notice Get buyer's purchase amount
     * @param tokenAddress Token address
     * @param buyer Buyer address
     * @return uint256 Amount purchased
     */
    function getBuyerPurchase(address tokenAddress, address buyer) external view returns (uint256) {
        return purchases[tokenAddress][buyer];
    }

    /**
     * @notice Get max purchase amount for buyer
     * @param tokenAddress Token address
     * @param buyer Buyer address
     * @return uint256 Max amount buyer can purchase
     */
    function getMaxPurchaseFor(address tokenAddress, address buyer) external view returns (uint256) {
        Sale memory sale = sales[tokenAddress];
        uint256 maxPurchase = (sale.tokensForSale * MAX_PURCHASE_PERCENTAGE) / 100;
        uint256 alreadyPurchased = purchases[tokenAddress][buyer];

        if (alreadyPurchased >= maxPurchase) return 0;

        return maxPurchase - alreadyPurchased;
    }

    /**
     * @notice Pause the primary market (emergency only)
     * @dev Prevents new token purchases
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the primary market
     * @dev Resumes normal operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
