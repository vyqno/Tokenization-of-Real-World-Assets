// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IPriceOracle } from "../interfaces/IPriceOracle.sol";
import { ValidationLib } from "../libraries/ValidationLib.sol";
import { MathLib } from "../libraries/MathLib.sol";

// Uniswap interface for price comparison
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/**
 * @title PriceOracle
 * @notice Tracks real-world land valuation and compares with DEX prices
 * @dev Integrates Chainlink for price feeds with manual fallback
 */
contract PriceOracle is IPriceOracle, Ownable {
    using ValidationLib for *;
    using MathLib for *;

    // Price tracking
    mapping(address => uint256) public landPrices; // Off-chain property valuation
    mapping(address => uint256) public lastUpdated; // Last update timestamp
    mapping(address => address) public chainlinkFeeds; // Chainlink price feed per token

    // DEX configuration
    IUniswapV2Factory public immutable uniswapFactory;
    address public immutable USDC;

    // Constants
    uint256 public constant UPDATE_THRESHOLD = 30 days; // Max time between updates
    uint256 public constant STALENESS_THRESHOLD = 3600; // 1 hour for Chainlink data
    uint256 public constant MAX_PRICE_CHANGE = 50; // 50% max daily change

    // Errors
    error PriceNotSet(address landToken);
    error StalePrice(address landToken, uint256 lastUpdate);
    error PriceChangeTooLarge(uint256 oldPrice, uint256 newPrice, uint256 maxChange);
    error ChainlinkDataStale(uint256 updatedAt);
    error InvalidChainlinkPrice(int256 price);

    /**
     * @notice Constructor
     * @param _uniswapFactory Address of Uniswap V2 Factory
     * @param _usdc Address of USDC token
     */
    constructor(address _uniswapFactory, address _usdc) Ownable(msg.sender) {
        ValidationLib.validateAddress(_uniswapFactory);
        ValidationLib.validateAddress(_usdc);

        uniswapFactory = IUniswapV2Factory(_uniswapFactory);
        USDC = _usdc;
    }

    /**
     * @notice Update land token price manually
     * @param landToken Address of land token
     * @param newPrice New price in USDC (scaled by 1e6)
     */
    function updatePrice(address landToken, uint256 newPrice) external onlyOwner {
        ValidationLib.validateAddress(landToken);
        ValidationLib.validateNonZero(newPrice);

        uint256 oldPrice = landPrices[landToken];

        // Circuit breaker: prevent >50% daily changes
        if (oldPrice > 0 && block.timestamp < lastUpdated[landToken] + 1 days) {
            uint256 maxChange = (oldPrice * MAX_PRICE_CHANGE) / 100;

            // Check both increase and decrease
            if (newPrice > oldPrice) {
                uint256 increase = newPrice - oldPrice;
                if (increase > maxChange) {
                    revert PriceChangeTooLarge(oldPrice, newPrice, maxChange);
                }
            } else {
                uint256 decrease = oldPrice - newPrice;
                if (decrease > maxChange) {
                    revert PriceChangeTooLarge(oldPrice, newPrice, maxChange);
                }
            }
        }

        landPrices[landToken] = newPrice;
        lastUpdated[landToken] = block.timestamp;

        emit PriceUpdated(landToken, newPrice, block.timestamp);
    }

    /**
     * @notice Set Chainlink price feed for a land token
     * @param landToken Address of land token
     * @param priceFeed Address of Chainlink price feed
     */
    function setChainlinkFeed(address landToken, address priceFeed) external onlyOwner {
        ValidationLib.validateAddress(landToken);
        ValidationLib.validateAddress(priceFeed);

        chainlinkFeeds[landToken] = priceFeed;

        emit ChainlinkFeedSet(landToken, priceFeed);
    }

    /**
     * @notice Get current price from oracle or Chainlink
     * @param landToken Address of land token
     * @return price Current price
     */
    function getPrice(address landToken) external view returns (uint256 price) {
        // Try Chainlink first
        address feed = chainlinkFeeds[landToken];

        if (feed != address(0)) {
            try this.getChainlinkPrice(feed) returns (uint256 chainlinkPrice) {
                return chainlinkPrice;
            } catch {
                // Fall through to manual price
            }
        }

        // Use manual price
        price = landPrices[landToken];

        if (price == 0) revert PriceNotSet(landToken);

        // Check if price is stale
        if (block.timestamp > lastUpdated[landToken] + UPDATE_THRESHOLD) {
            revert StalePrice(landToken, lastUpdated[landToken]);
        }

        return price;
    }

    /**
     * @notice Get price from Chainlink feed
     * @param feed Address of Chainlink feed
     * @return price Price from Chainlink
     */
    function getChainlinkPrice(address feed) external view returns (uint256 price) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed);

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

        // Validate data
        if (answeredInRound < roundId) revert ChainlinkDataStale(updatedAt);
        if (block.timestamp > updatedAt + STALENESS_THRESHOLD) revert ChainlinkDataStale(updatedAt);
        if (answer <= 0) revert InvalidChainlinkPrice(answer);

        // Convert to uint256 and scale to USDC decimals (6)
        uint8 decimals = priceFeed.decimals();
        price = MathLib.scaleDecimals(uint256(answer), decimals, 6);

        return price;
    }

    /**
     * @notice Get price from DEX (Uniswap)
     * @param landToken Address of land token
     * @return dexPrice Price from DEX
     */
    function getDexPrice(address landToken) public view returns (uint256 dexPrice) {
        address pair = uniswapFactory.getPair(landToken, USDC);

        if (pair == address(0)) return 0;

        IUniswapV2Pair uniPair = IUniswapV2Pair(pair);
        (uint112 reserve0, uint112 reserve1,) = uniPair.getReserves();

        // Determine token order
        bool isToken0 = uniPair.token0() == landToken;

        uint256 tokenReserve = isToken0 ? uint256(reserve0) : uint256(reserve1);
        uint256 usdcReserve = isToken0 ? uint256(reserve1) : uint256(reserve0);

        if (tokenReserve == 0) return 0;

        // Price = USDC reserve / Token reserve
        // Token has 18 decimals, USDC has 6, so we need to adjust
        dexPrice = (usdcReserve * 1e18) / tokenReserve;

        return dexPrice;
    }

    /**
     * @notice Calculate price divergence between oracle and DEX
     * @param landToken Address of land token
     * @return divergencePercent Divergence as percentage (can be negative)
     */
    function getPriceDivergence(address landToken) external view returns (int256 divergencePercent) {
        uint256 oraclePrice = landPrices[landToken];
        uint256 dexPrice = getDexPrice(landToken);

        if (oraclePrice == 0 || dexPrice == 0) return 0;

        // Calculate percentage difference
        divergencePercent = MathLib.calculateDivergence(dexPrice, oraclePrice);

        return divergencePercent;
    }

    /**
     * @notice Get comprehensive price data
     * @param landToken Address of land token
     * @return oraclePrice Price from oracle
     * @return dexPrice Price from DEX
     * @return divergence Divergence percentage
     * @return lastUpdate Last update timestamp
     */
    function getPriceData(address landToken)
        external
        view
        returns (uint256 oraclePrice, uint256 dexPrice, int256 divergence, uint256 lastUpdate)
    {
        oraclePrice = landPrices[landToken];
        dexPrice = getDexPrice(landToken);
        divergence = (oraclePrice > 0 && dexPrice > 0) ? MathLib.calculateDivergence(dexPrice, oraclePrice) : int256(0);
        lastUpdate = lastUpdated[landToken];

        return (oraclePrice, dexPrice, divergence, lastUpdate);
    }

    /**
     * @notice Check if price is stale
     * @param landToken Address of land token
     * @return bool True if stale
     */
    function isPriceStale(address landToken) external view returns (bool) {
        if (landPrices[landToken] == 0) return true;

        return block.timestamp > lastUpdated[landToken] + UPDATE_THRESHOLD;
    }

    /**
     * @notice Get time until price becomes stale
     * @param landToken Address of land token
     * @return uint256 Seconds until stale (0 if already stale)
     */
    function getTimeUntilStale(address landToken) external view returns (uint256) {
        if (landPrices[landToken] == 0) return 0;

        uint256 staleTime = lastUpdated[landToken] + UPDATE_THRESHOLD;

        if (block.timestamp >= staleTime) return 0;

        return staleTime - block.timestamp;
    }
}
