// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ValidationLib } from "../libraries/ValidationLib.sol";
import { MathLib } from "../libraries/MathLib.sol";

// Uniswap V2 interfaces
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

interface IUniswapV2Pair {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/**
 * @title LiquidityBootstrap
 * @notice Auto-create Uniswap V2 liquidity pools for land tokens
 * @dev Manages initial liquidity and LP token lockup
 */
contract LiquidityBootstrap is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ValidationLib for *;
    using MathLib for *;

    // Uniswap contracts
    IUniswapV2Router02 public immutable uniswapRouter;
    IUniswapV2Factory public immutable uniswapFactory;

    // Token addresses
    address public immutable USDC;

    /**
     * @notice Pool configuration
     */
    struct PoolConfig {
        uint256 tokenAmount;
        uint256 usdcAmount;
        address lpTokenAddress;
        uint256 createdAt;
        uint256 liquidity;
        bool locked;
    }

    // Pool tracking
    mapping(address => PoolConfig) public pools;

    // Constants
    uint256 public constant LOCKUP_PERIOD = 180 days; // 6 months
    uint256 public constant SLIPPAGE_TOLERANCE = 500; // 5% in basis points
    uint256 public constant DEADLINE_EXTENSION = 15 minutes;

    // Events
    event LiquidityAdded(
        address indexed landToken, uint256 tokenAmount, uint256 usdcAmount, uint256 liquidity, address pair
    );
    event LiquidityRemoved(address indexed landToken, uint256 tokenAmount, uint256 usdcAmount);
    event PoolLocked(address indexed landToken, uint256 unlockTime);

    // Errors
    error PoolAlreadyExists(address landToken);
    error PoolNotFound(address landToken);
    error LockupPeriodActive(uint256 unlockTime);
    error PairCreationFailed();
    error InsufficientLiquidity();

    /**
     * @notice Constructor
     * @param _uniswapRouter Address of Uniswap V2 Router
     * @param _uniswapFactory Address of Uniswap V2 Factory
     * @param _usdc Address of USDC token
     */
    constructor(address _uniswapRouter, address _uniswapFactory, address _usdc) Ownable(msg.sender) {
        ValidationLib.validateAddress(_uniswapRouter);
        ValidationLib.validateAddress(_uniswapFactory);
        ValidationLib.validateAddress(_usdc);

        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        uniswapFactory = IUniswapV2Factory(_uniswapFactory);
        USDC = _usdc;
    }

    /**
     * @notice Bootstrap liquidity for a land token
     * @param landToken Address of land token
     * @param tokenAmount Amount of land tokens to add
     * @param usdcAmount Amount of USDC to add
     * @return pairAddress Address of created/existing Uniswap pair
     */
    function bootstrapLiquidity(address landToken, uint256 tokenAmount, uint256 usdcAmount)
        external
        onlyOwner
        nonReentrant
        returns (address pairAddress)
    {
        ValidationLib.validateAddress(landToken);
        ValidationLib.validateNonZero(tokenAmount);
        ValidationLib.validateNonZero(usdcAmount);

        // Check if pool already exists
        if (pools[landToken].lpTokenAddress != address(0)) {
            revert PoolAlreadyExists(landToken);
        }

        // Get or create pair
        pairAddress = uniswapFactory.getPair(landToken, USDC);

        if (pairAddress == address(0)) {
            pairAddress = uniswapFactory.createPair(landToken, USDC);
            if (pairAddress == address(0)) revert PairCreationFailed();
        }

        // Transfer tokens to this contract
        IERC20(landToken).safeTransferFrom(msg.sender, address(this), tokenAmount);
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Approve router
        IERC20(landToken).approve(address(uniswapRouter), tokenAmount);
        IERC20(USDC).approve(address(uniswapRouter), usdcAmount);

        // Calculate minimum amounts with slippage tolerance
        uint256 tokenMin = MathLib.applySlippage(tokenAmount, SLIPPAGE_TOLERANCE, true);
        uint256 usdcMin = MathLib.applySlippage(usdcAmount, SLIPPAGE_TOLERANCE, true);

        // Add liquidity
        (uint256 amountToken, uint256 amountUSDC, uint256 liquidity) = uniswapRouter.addLiquidity(
            landToken,
            USDC,
            tokenAmount,
            usdcAmount,
            tokenMin,
            usdcMin,
            address(this),
            block.timestamp + DEADLINE_EXTENSION
        );

        // Store pool config
        pools[landToken] = PoolConfig({
            tokenAmount: amountToken,
            usdcAmount: amountUSDC,
            lpTokenAddress: pairAddress,
            createdAt: block.timestamp,
            liquidity: liquidity,
            locked: true
        });

        emit LiquidityAdded(landToken, amountToken, amountUSDC, liquidity, pairAddress);
        emit PoolLocked(landToken, block.timestamp + LOCKUP_PERIOD);

        return pairAddress;
    }

    /**
     * @notice Remove liquidity after lockup period
     * @param landToken Address of land token
     */
    function removeLiquidity(address landToken) external onlyOwner nonReentrant {
        PoolConfig storage pool = pools[landToken];

        if (pool.lpTokenAddress == address(0)) revert PoolNotFound(landToken);

        // Check lockup period
        uint256 unlockTime = pool.createdAt + LOCKUP_PERIOD;
        if (block.timestamp < unlockTime) {
            revert LockupPeriodActive(unlockTime);
        }

        IUniswapV2Pair pair = IUniswapV2Pair(pool.lpTokenAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        if (liquidity == 0) revert InsufficientLiquidity();

        // Approve router to spend LP tokens
        pair.approve(address(uniswapRouter), liquidity);

        // Remove liquidity
        (uint256 amountToken, uint256 amountUSDC) = uniswapRouter.removeLiquidity(
            landToken, USDC, liquidity, 0, 0, msg.sender, block.timestamp + DEADLINE_EXTENSION
        );

        // Update pool state
        pool.locked = false;

        emit LiquidityRemoved(landToken, amountToken, amountUSDC);
    }

    /**
     * @notice Get pool information
     * @param landToken Address of land token
     * @return config Pool configuration
     */
    function getPoolConfig(address landToken) external view returns (PoolConfig memory) {
        return pools[landToken];
    }

    /**
     * @notice Get current reserves from pair
     * @param landToken Address of land token
     * @return tokenReserve Reserve of land token
     * @return usdcReserve Reserve of USDC
     */
    function getReserves(address landToken) external view returns (uint256 tokenReserve, uint256 usdcReserve) {
        PoolConfig memory pool = pools[landToken];

        if (pool.lpTokenAddress == address(0)) {
            return (0, 0);
        }

        IUniswapV2Pair pair = IUniswapV2Pair(pool.lpTokenAddress);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();

        // Determine token order
        if (pair.token0() == landToken) {
            return (uint256(reserve0), uint256(reserve1));
        } else {
            return (uint256(reserve1), uint256(reserve0));
        }
    }

    /**
     * @notice Get current price of land token in USDC
     * @param landToken Address of land token
     * @return price Price in USDC (scaled by 1e6)
     */
    function getTokenPrice(address landToken) external view returns (uint256 price) {
        (uint256 tokenReserve, uint256 usdcReserve) = this.getReserves(landToken);

        if (tokenReserve == 0) return 0;

        // Price = USDC reserve / Token reserve
        // Adjust for 18 decimals (token) to 6 decimals (USDC)
        price = (usdcReserve * 1e18) / tokenReserve;

        return price;
    }

    /**
     * @notice Check if lockup period is active
     * @param landToken Address of land token
     * @return bool True if locked
     */
    function isLocked(address landToken) external view returns (bool) {
        PoolConfig memory pool = pools[landToken];
        if (pool.lpTokenAddress == address(0)) return false;

        return block.timestamp < pool.createdAt + LOCKUP_PERIOD;
    }

    /**
     * @notice Get time until unlock
     * @param landToken Address of land token
     * @return uint256 Seconds until unlock (0 if unlocked)
     */
    function getTimeUntilUnlock(address landToken) external view returns (uint256) {
        PoolConfig memory pool = pools[landToken];
        if (pool.lpTokenAddress == address(0)) return 0;

        uint256 unlockTime = pool.createdAt + LOCKUP_PERIOD;

        if (block.timestamp >= unlockTime) return 0;

        return unlockTime - block.timestamp;
    }

    /**
     * @notice Get LP token balance held by this contract
     * @param landToken Address of land token
     * @return uint256 LP token balance
     */
    function getLPBalance(address landToken) external view returns (uint256) {
        PoolConfig memory pool = pools[landToken];
        if (pool.lpTokenAddress == address(0)) return 0;

        return IUniswapV2Pair(pool.lpTokenAddress).balanceOf(address(this));
    }
}
