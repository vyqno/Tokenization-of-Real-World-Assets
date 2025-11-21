// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MathLib
 * @notice Math utility library for Land Token Protocol
 * @dev Provides safe math operations and price calculations
 */
library MathLib {
    /**
     * @dev Custom errors
     */
    error DivisionByZero();
    error MultiplicationOverflow();
    error PercentageOutOfRange();

    /**
     * @notice Calculates percentage of a value
     * @param value Base value
     * @param percentage Percentage (0-100)
     * @return uint256 Calculated percentage
     */
    function percentageOf(uint256 value, uint256 percentage) internal pure returns (uint256) {
        if (percentage > 100) revert PercentageOutOfRange();
        return (value * percentage) / 100;
    }

    /**
     * @notice Calculates basis points of a value
     * @param value Base value
     * @param basisPoints Basis points (100 bps = 1%)
     * @return uint256 Calculated value
     */
    function basisPointsOf(uint256 value, uint256 basisPoints) internal pure returns (uint256) {
        if (basisPoints > 10_000) revert PercentageOutOfRange();
        return (value * basisPoints) / 10_000;
    }

    /**
     * @notice Calculates what percentage value1 is of value2
     * @param value1 Numerator
     * @param value2 Denominator
     * @return uint256 Percentage (scaled by 100)
     */
    function calculatePercentage(uint256 value1, uint256 value2) internal pure returns (uint256) {
        if (value2 == 0) revert DivisionByZero();
        return (value1 * 100) / value2;
    }

    /**
     * @notice Calculates price divergence between two values
     * @param price1 First price
     * @param price2 Second price (reference)
     * @return int256 Divergence percentage (can be negative)
     */
    function calculateDivergence(uint256 price1, uint256 price2) internal pure returns (int256) {
        if (price2 == 0) revert DivisionByZero();

        int256 diff = int256(price1) - int256(price2);
        return (diff * 100) / int256(price2);
    }

    /**
     * @notice Safely multiplies two numbers with overflow check
     * @param a First number
     * @param b Second number
     * @return uint256 Product
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        if (c / a != b) revert MultiplicationOverflow();
        return c;
    }

    /**
     * @notice Safely divides with zero check
     * @param a Numerator
     * @param b Denominator
     * @return uint256 Quotient
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) revert DivisionByZero();
        return a / b;
    }

    /**
     * @notice Calculates average of two numbers
     * @param a First number
     * @param b Second number
     * @return uint256 Average
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a + b) / 2;
    }

    /**
     * @notice Returns minimum of two numbers
     * @param a First number
     * @param b Second number
     * @return uint256 Minimum value
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Returns maximum of two numbers
     * @param a First number
     * @param b Second number
     * @return uint256 Maximum value
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @notice Calculates token price from liquidity pool reserves
     * @param reserveToken Token reserve
     * @param reserveStable Stablecoin reserve (e.g., USDC)
     * @param tokenDecimals Token decimals
     * @param stableDecimals Stablecoin decimals
     * @return uint256 Price per token in stablecoin (scaled)
     */
    function calculatePoolPrice(uint256 reserveToken, uint256 reserveStable, uint8 tokenDecimals, uint8 stableDecimals)
        internal
        pure
        returns (uint256)
    {
        if (reserveToken == 0) revert DivisionByZero();

        // Price = reserveStable / reserveToken
        // Adjust for decimals to get price in stablecoin terms
        uint256 price = (reserveStable * (10 ** tokenDecimals)) / reserveToken;

        // Normalize to stable decimals if needed
        if (stableDecimals > tokenDecimals) {
            price = price * (10 ** (stableDecimals - tokenDecimals));
        } else if (tokenDecimals > stableDecimals) {
            price = price / (10 ** (tokenDecimals - stableDecimals));
        }

        return price;
    }

    /**
     * @notice Calculates amount out from Uniswap constant product formula
     * @param amountIn Input amount
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @return amountOut Output amount (with 0.3% fee)
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert DivisionByZero();
        if (reserveIn == 0 || reserveOut == 0) revert DivisionByZero();

        // Uniswap V2 formula with 0.3% fee
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        amountOut = numerator / denominator;
    }

    /**
     * @notice Calculates amount in from Uniswap constant product formula
     * @param amountOut Desired output amount
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @return amountIn Required input amount (with 0.3% fee)
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        if (amountOut == 0) revert DivisionByZero();
        if (reserveIn == 0 || reserveOut == 0) revert DivisionByZero();

        // Uniswap V2 formula with 0.3% fee
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;

        amountIn = (numerator / denominator) + 1;
    }

    /**
     * @notice Calculates proportional liquidity amounts
     * @param amount0 Token0 amount
     * @param reserve0 Token0 reserve
     * @param reserve1 Token1 reserve
     * @return amount1 Proportional token1 amount
     */
    function quote(uint256 amount0, uint256 reserve0, uint256 reserve1) internal pure returns (uint256 amount1) {
        if (amount0 == 0) revert DivisionByZero();
        if (reserve0 == 0) revert DivisionByZero();

        amount1 = (amount0 * reserve1) / reserve0;
    }

    /**
     * @notice Applies slippage tolerance to an amount
     * @param amount Base amount
     * @param slippageBps Slippage in basis points (e.g., 500 = 5%)
     * @param isMinimum True for minimum amount, false for maximum
     * @return uint256 Amount with slippage applied
     */
    function applySlippage(uint256 amount, uint256 slippageBps, bool isMinimum) internal pure returns (uint256) {
        if (slippageBps > 10_000) revert PercentageOutOfRange();

        if (isMinimum) {
            // Minimum: amount - slippage
            return amount - basisPointsOf(amount, slippageBps);
        } else {
            // Maximum: amount + slippage
            return amount + basisPointsOf(amount, slippageBps);
        }
    }

    /**
     * @notice Scales a value from one decimal precision to another
     * @param value Value to scale
     * @param fromDecimals Current decimal precision
     * @param toDecimals Target decimal precision
     * @return uint256 Scaled value
     */
    function scaleDecimals(uint256 value, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) return value;

        if (fromDecimals > toDecimals) {
            return value / (10 ** (fromDecimals - toDecimals));
        } else {
            return value * (10 ** (toDecimals - fromDecimals));
        }
    }

    /**
     * @notice Calculates compound interest
     * @param principal Principal amount
     * @param rate Interest rate in basis points per period
     * @param periods Number of periods
     * @return uint256 Final amount with compound interest
     */
    function compoundInterest(uint256 principal, uint256 rate, uint256 periods) internal pure returns (uint256) {
        if (periods == 0) return principal;
        if (rate > 10_000) revert PercentageOutOfRange();

        uint256 amount = principal;
        for (uint256 i = 0; i < periods; i++) {
            amount = amount + basisPointsOf(amount, rate);
        }

        return amount;
    }

    /**
     * @notice Calculates weighted average
     * @param values Array of values
     * @param weights Array of weights (must sum to total weight)
     * @param totalWeight Total weight
     * @return uint256 Weighted average
     */
    function weightedAverage(uint256[] memory values, uint256[] memory weights, uint256 totalWeight)
        internal
        pure
        returns (uint256)
    {
        if (values.length != weights.length) revert DivisionByZero();
        if (totalWeight == 0) revert DivisionByZero();

        uint256 sum = 0;
        for (uint256 i = 0; i < values.length; i++) {
            sum += (values[i] * weights[i]);
        }

        return sum / totalWeight;
    }
}
