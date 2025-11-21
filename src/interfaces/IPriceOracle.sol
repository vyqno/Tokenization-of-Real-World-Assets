// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPriceOracle
 * @notice Interface for the PriceOracle contract
 */
interface IPriceOracle {
    // Events
    event PriceUpdated(address indexed landToken, uint256 newPrice, uint256 timestamp);
    event ChainlinkFeedSet(address indexed landToken, address indexed priceFeed);

    // Functions
    function updatePrice(address landToken, uint256 newPrice) external;

    function setChainlinkFeed(address landToken, address priceFeed) external;

    function getPrice(address landToken) external view returns (uint256);

    function getPriceDivergence(address landToken) external view returns (int256 divergencePercent);

    function getDexPrice(address landToken) external view returns (uint256);

    function landPrices(address landToken) external view returns (uint256);

    function lastUpdated(address landToken) external view returns (uint256);
}
