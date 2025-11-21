// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Mock ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

/**
 * @title MockUniswapV2Pair
 * @notice Mock Uniswap V2 pair for testing
 */
contract MockUniswapV2Pair {
    address public token0;
    address public token1;
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function setReserves(uint112 _reserve0, uint112 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = uint32(block.timestamp);
    }

    function balanceOf(address) external pure returns (uint256) {
        return 1000e18; // Return 1000 LP tokens for testing
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }
}

/**
 * @title MockUniswapV2Factory
 * @notice Mock Uniswap V2 factory for testing
 */
contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public pairs;

    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[tokenA][tokenB];
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(pairs[tokenA][tokenB] == address(0), "Pair exists");

        MockUniswapV2Pair newPair = new MockUniswapV2Pair(tokenA, tokenB);
        pair = address(newPair);

        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;

        return pair;
    }
}

/**
 * @title MockUniswapV2Router
 * @notice Mock Uniswap V2 router for testing
 */
contract MockUniswapV2Router {
    MockUniswapV2Factory public factory;

    constructor(address _factory) {
        factory = MockUniswapV2Factory(_factory);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256, /* amountAMin */
        uint256, /* amountBMin */
        address to,
        uint256 /* deadline */
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // Transfer tokens from sender
        MockERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        MockERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);

        // Get or create pair
        address pair = factory.getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = factory.createPair(tokenA, tokenB);
        }

        // Set reserves
        MockUniswapV2Pair(pair).setReserves(uint112(amountADesired), uint112(amountBDesired));

        // Mock liquidity
        liquidity = 1000e18;

        return (amountADesired, amountBDesired, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256, /* liquidity */
        uint256, /* amountAMin */
        uint256, /* amountBMin */
        address to,
        uint256 /* deadline */
    ) external returns (uint256 amountA, uint256 amountB) {
        address pair = factory.getPair(tokenA, tokenB);
        require(pair != address(0), "Pair not found");

        // Get reserves
        (uint112 reserveA, uint112 reserveB,) = MockUniswapV2Pair(pair).getReserves();

        // Transfer tokens back
        MockERC20(tokenA).transfer(to, uint256(reserveA));
        MockERC20(tokenB).transfer(to, uint256(reserveB));

        return (uint256(reserveA), uint256(reserveB));
    }
}

/**
 * @title MockChainlinkAggregator
 * @notice Mock Chainlink price feed for testing
 */
contract MockChainlinkAggregator {
    int256 private _answer;
    uint8 private _decimals;
    uint80 private _roundId;
    uint256 private _updatedAt;

    constructor(int256 initialAnswer, uint8 decimals_) {
        _answer = initialAnswer;
        _decimals = decimals_;
        _roundId = 1;
        _updatedAt = block.timestamp;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, block.timestamp, _updatedAt, _roundId);
    }

    function updateAnswer(int256 newAnswer) external {
        _answer = newAnswer;
        _roundId++;
        _updatedAt = block.timestamp;
    }
}
