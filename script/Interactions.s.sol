// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { LandRegistry } from "../src/core/LandRegistry.sol";
import { StakingVault } from "../src/core/StakingVault.sol";
import { TokenFactory } from "../src/core/TokenFactory.sol";
import { PrimaryMarket } from "../src/trading/PrimaryMarket.sol";
import { LiquidityBootstrap } from "../src/trading/LiquidityBootstrap.sol";
import { ILandToken } from "../src/interfaces/ILandToken.sol";
import { LandLib } from "../src/libraries/LandLib.sol";

/**
 * @title Interactions
 * @notice Helper scripts for common protocol interactions
 */
contract Interactions is Script {
    // Load addresses from environment
    address LAND_REGISTRY = vm.envAddress("LAND_REGISTRY");
    address STAKING_VAULT = vm.envAddress("STAKING_VAULT");
    address TOKEN_FACTORY = vm.envAddress("TOKEN_FACTORY");
    address PRIMARY_MARKET = vm.envAddress("PRIMARY_MARKET");
    address LIQUIDITY_BOOTSTRAP = vm.envAddress("LIQUIDITY_BOOTSTRAP");
    address USDC = vm.envAddress("USDC_TOKEN");
}

/**
 * @title RegisterProperty
 * @notice Register a new property for tokenization
 */
contract RegisterProperty is Interactions {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        // Example property metadata
        LandLib.PropertyMetadata memory metadata = LandLib.PropertyMetadata({
            surveyNumber: "123/A",
            location: "Kengeri, Bangalore",
            latitude: 12_970_000, // 12.97 degrees
            longitude: 77_490_000, // 77.49 degrees
            areaSqFt: 10_000, // 10,000 sq ft
            ipfsHash: "QmExampleHash123456789abcdefghijklmnopqrstuv",
            valuation: 6_900_000e6 // ₹69 Lakhs in USDC (6 decimals)
         });

        uint256 stakeAmount = 345_000e6; // 5% stake

        vm.startBroadcast(deployerKey);

        // Approve USDC for staking
        IERC20(USDC).approve(STAKING_VAULT, stakeAmount);

        // Deposit stake
        StakingVault(STAKING_VAULT).depositStake(stakeAmount);

        // Register property
        bytes32 propertyId = LandRegistry(LAND_REGISTRY).registerProperty(metadata, stakeAmount);

        vm.stopBroadcast();

        console.log("Property registered!");
        console.log("Property ID:", vm.toString(propertyId));
    }
}

/**
 * @title VerifyProperty
 * @notice Verify a pending property
 */
contract VerifyProperty is Interactions {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        bytes32 propertyId = vm.envBytes32("PROPERTY_ID");

        vm.startBroadcast(deployerKey);

        // Verify property (approve)
        LandRegistry(LAND_REGISTRY).verifyProperty(propertyId, true);

        vm.stopBroadcast();

        console.log("Property verified!");

        // Get token address
        LandLib.PropertyData memory propData = LandRegistry(LAND_REGISTRY).getPropertyData(propertyId);
        console.log("Token Address:", propData.tokenAddress);
    }
}

/**
 * @title StartPrimarySale
 * @notice Start primary market sale for a land token
 */
contract StartPrimarySale is Interactions {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("LAND_TOKEN");

        // Get token info
        ILandToken token = ILandToken(tokenAddress);
        uint256 factoryBalance = token.balanceOf(TOKEN_FACTORY);
        uint256 pricePerToken = 10e6; // 10 USDC per token

        vm.startBroadcast(deployerKey);

        // Transfer tokens from factory to primary market
        TokenFactory(TOKEN_FACTORY).transferToPrimaryMarket(tokenAddress, PRIMARY_MARKET, factoryBalance);

        // Start sale
        PrimaryMarket(PRIMARY_MARKET).startSale(tokenAddress, factoryBalance, pricePerToken, msg.sender);

        vm.stopBroadcast();

        console.log("Primary sale started!");
        console.log("Tokens for sale:", factoryBalance);
        console.log("Price per token:", pricePerToken);
    }
}

/**
 * @title BuyTokens
 * @notice Buy tokens from primary market
 */
contract BuyTokens is Interactions {
    function run() external {
        uint256 buyerKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("LAND_TOKEN");
        uint256 amount = vm.envUint("TOKEN_AMOUNT"); // Amount of tokens to buy

        // Calculate payment
        uint256 payment = (amount * 10e6) / 1e18; // 10 USDC per token

        vm.startBroadcast(buyerKey);

        // Approve USDC
        IERC20(USDC).approve(PRIMARY_MARKET, payment);

        // Buy tokens
        PrimaryMarket(PRIMARY_MARKET).buyTokens(tokenAddress, amount);

        vm.stopBroadcast();

        console.log("Tokens purchased!");
        console.log("Amount:", amount);
        console.log("Payment:", payment);
    }
}

/**
 * @title BootstrapLiquidity
 * @notice Create Uniswap pool and add liquidity
 */
contract BootstrapLiquidity is Interactions {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("LAND_TOKEN");
        uint256 tokenAmount = vm.envUint("TOKEN_AMOUNT");
        uint256 usdcAmount = vm.envUint("USDC_AMOUNT");

        vm.startBroadcast(deployerKey);

        // Approve tokens
        IERC20(tokenAddress).approve(LIQUIDITY_BOOTSTRAP, tokenAmount);
        IERC20(USDC).approve(LIQUIDITY_BOOTSTRAP, usdcAmount);

        // Bootstrap liquidity
        address pairAddress =
            LiquidityBootstrap(LIQUIDITY_BOOTSTRAP).bootstrapLiquidity(tokenAddress, tokenAmount, usdcAmount);

        vm.stopBroadcast();

        console.log("Liquidity bootstrapped!");
        console.log("Pair address:", pairAddress);
        console.log("Token amount:", tokenAmount);
        console.log("USDC amount:", usdcAmount);
    }
}

/**
 * @title GetPropertyInfo
 * @notice Get information about a property
 */
contract GetPropertyInfo is Interactions {
    function run() external view {
        bytes32 propertyId = vm.envBytes32("PROPERTY_ID");

        LandLib.PropertyData memory propData = LandRegistry(LAND_REGISTRY).getPropertyData(propertyId);

        console.log("=== Property Information ===");
        console.log("Property ID:", vm.toString(propertyId));
        console.log("Owner:", propData.owner);
        console.log("Location:", propData.metadata.location);
        console.log("Survey Number:", propData.metadata.surveyNumber);
        console.log("Area (sq ft):", propData.metadata.areaSqFt);
        console.log("Valuation:", propData.metadata.valuation);
        console.log("Token Address:", propData.tokenAddress);
        console.log("Status:", uint256(propData.status));
        console.log("Registered At:", propData.registeredAt);
    }
}

/**
 * @title GetTokenInfo
 * @notice Get information about a land token
 */
contract GetTokenInfo is Interactions {
    function run() external view {
        address tokenAddress = vm.envAddress("LAND_TOKEN");

        ILandToken token = ILandToken(tokenAddress);

        (
            string memory name,
            string memory symbol,
            uint256 totalSupply,
            address owner,
            ILandToken.TokenStatus status,
            uint256 valuation
        ) = token.getTokenInfo();

        console.log("=== Token Information ===");
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Total Supply:", totalSupply);
        console.log("Owner:", owner);
        console.log("Status:", uint256(status));
        console.log("Valuation:", valuation);
    }
}
