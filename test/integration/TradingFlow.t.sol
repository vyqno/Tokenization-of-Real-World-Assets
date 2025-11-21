// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../utils/TestBase.sol";
import { LandLib } from "../../src/libraries/LandLib.sol";
import { ILandToken } from "../../src/interfaces/ILandToken.sol";
import { console } from "forge-std/console.sol";

/**
 * @title TradingFlowTest
 * @notice Integration test for complete trading workflow
 * Tests: Primary Market Sale → Liquidity Bootstrap → DEX Trading
 */
contract TradingFlowTest is TestBase {
    bytes32 propertyId;
    address tokenAddress;
    ILandToken token;

    function setUp() public override {
        super.setUp();

        // Setup: Create and verify a property
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);
        tokenAddress = getTokenFromProperty(propertyId);
        token = ILandToken(tokenAddress);
    }

    function test_CompleteTradingFlow() public {
        console.log("\n=== Starting Complete Trading Flow Test ===\n");

        uint256 totalSupply = token.totalSupply();
        uint256 factoryBalance = token.balanceOf(address(tokenFactory));

        // STEP 1: Start Primary Market Sale
        console.log("Step 1: Start primary market sale");
        _startPrimarySale(factoryBalance);

        // STEP 2: Multiple buyers purchase tokens
        console.log("\nStep 2: Buyers purchase tokens");
        _testPrimaryMarketPurchases();

        // STEP 3: Finalize sale
        console.log("\nStep 3: Finalize primary sale");
        _finalizePrimarySale();

        // STEP 4: Bootstrap liquidity on DEX
        console.log("\nStep 4: Bootstrap liquidity on DEX");
        _bootstrapLiquidity();

        // STEP 5: Verify DEX price
        console.log("\nStep 5: Verify DEX integration");
        _verifyDEXIntegration();

        console.log("\n=== Trading Flow Test Complete ===\n");
    }

    function _startPrimarySale(uint256 tokensForSale) internal {
        uint256 pricePerToken = 10e6; // 10 USDC per token (scaled to 18 decimals for ERC20)

        // Transfer tokens from factory to owner
        vm.prank(owner);
        tokenFactory.transferToPrimaryMarket(tokenAddress, owner, tokensForSale);

        // Start sale (with approval) - startSale will transfer to PrimaryMarket
        vm.startPrank(owner);
        token.approve(address(primaryMarket), tokensForSale);
        primaryMarket.startSale(tokenAddress, tokensForSale, pricePerToken, landowner);
        vm.stopPrank();

        assertTrue(primaryMarket.isSaleActive(tokenAddress), "Sale not active");
        console.log("  [OK] Primary sale started");
        console.log("    Tokens for sale:", tokensForSale);
        console.log("    Price per token: 10 USDC");
    }

    function _testPrimaryMarketPurchases() internal {
        uint256 tokenAmount = 1000e18; // Buy 1000 tokens
        uint256 payment = (tokenAmount * 10e6) / 1e18; // 10 USDC per token

        // Test max purchase limit (10%)
        uint256 maxPurchase = primaryMarket.getMaxPurchaseFor(tokenAddress, buyer1);
        console.log("  Max purchase per buyer:", maxPurchase);

        // Buyer 1 purchases
        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, tokenAmount);
        vm.stopPrank();

        assertEq(token.balanceOf(buyer1), tokenAmount, "Buyer1 didn't receive tokens");
        console.log("  [OK] Buyer 1 purchased:", tokenAmount / 1e18, "tokens");

        // Buyer 2 purchases
        vm.startPrank(buyer2);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, tokenAmount);
        vm.stopPrank();

        console.log("  [OK] Buyer 2 purchased:", tokenAmount / 1e18, "tokens");

        // Buyer 3 purchases
        vm.startPrank(buyer3);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, tokenAmount);
        vm.stopPrank();

        console.log("  [OK] Buyer 3 purchased:", tokenAmount / 1e18, "tokens");

        // Verify max purchase limit prevents whale
        // Buyer1 already bought 1000 tokens, max is 10% = 32,085 tokens
        // So buyer1 can buy at most 31,085 more tokens
        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), type(uint256).max);
        vm.expectRevert();
        primaryMarket.buyTokens(tokenAddress, maxPurchase); // Try to buy max again (would exceed limit)
        vm.stopPrank();

        console.log("  [OK] Max purchase limit enforced (10% per buyer)");
    }

    function _finalizePrimarySale() internal {
        // Skip to end of sale period
        vm.warp(block.timestamp + 72 hours + 1);

        uint256 landownerBalanceBefore = usdc.balanceOf(landowner);

        vm.prank(owner);
        primaryMarket.finalizeSale(tokenAddress);

        // Landowner should receive USDC from sale
        uint256 landownerBalanceAfter = usdc.balanceOf(landowner);
        assertTrue(landownerBalanceAfter > landownerBalanceBefore, "Landowner didn't receive proceeds");

        console.log("  [OK] Sale finalized");
        console.log("    Landowner received:", landownerBalanceAfter - landownerBalanceBefore);
    }

    function _bootstrapLiquidity() internal {
        uint256 tokenAmount = 5000e18; // 5000 tokens
        uint256 usdcAmount = 50_000e6; // 50,000 USDC

        // Get tokens from landowner (original owner who has 51% allocation)
        address originalOwner = token.originalOwner();
        
        // Skip lock period so landowner can transfer
        vm.warp(block.timestamp + 181 days);
        
        // Transfer tokens from landowner to owner for liquidity
        vm.prank(originalOwner);
        token.transfer(owner, tokenAmount);

        // Mint USDC for owner
        usdc.mint(owner, usdcAmount);

        vm.startPrank(owner);

        // Approve tokens
        token.approve(address(liquidityBootstrap), tokenAmount);
        usdc.approve(address(liquidityBootstrap), usdcAmount);

        // Bootstrap liquidity
        address pairAddress = liquidityBootstrap.bootstrapLiquidity(tokenAddress, tokenAmount, usdcAmount);

        vm.stopPrank();

        assertTrue(pairAddress != address(0), "Pair not created");
        console.log("  [OK] Liquidity pool created at:", pairAddress);
        console.log("    Token amount:", tokenAmount / 1e18);
        console.log("    USDC amount:", usdcAmount / 1e6);

        // Verify lockup
        assertTrue(liquidityBootstrap.isLocked(tokenAddress), "LP tokens should be locked");
        console.log("  [OK] LP tokens locked for 6 months");
    }

    function _verifyDEXIntegration() internal {
        // Get reserves
        (uint256 tokenReserve, uint256 usdcReserve) = liquidityBootstrap.getReserves(tokenAddress);

        assertTrue(tokenReserve > 0, "Token reserve is zero");
        assertTrue(usdcReserve > 0, "USDC reserve is zero");

        console.log("  Pool reserves:");
        console.log("    Token:", tokenReserve / 1e18);
        console.log("    USDC:", usdcReserve / 1e6);

        // Get price from bootstrap
        uint256 dexPrice = liquidityBootstrap.getTokenPrice(tokenAddress);
        console.log("  DEX price:", dexPrice / 1e6, "USDC per token");

        // Verify price is reasonable (around 10 USDC)
        assertTrue(dexPrice >= 9e6 && dexPrice <= 11e6, "DEX price not reasonable");
        console.log("  [OK] DEX price is reasonable");
    }

    function test_SecondaryMarketTrading() public {
        console.log("\n=== Testing Secondary Market Trading ===\n");

        // Setup: Complete primary sale first
        uint256 factoryBalance = token.balanceOf(address(tokenFactory));
        _startPrimarySale(factoryBalance);

        // Buyer1 purchases in primary
        uint256 purchaseAmount = 1000e18;
        uint256 payment = (purchaseAmount * 10e6) / 1e18;

        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, purchaseAmount);
        vm.stopPrank();

        console.log("Buyer1 purchased", purchaseAmount / 1e18, "tokens in primary market");

        // After sale ends, buyer1 can trade freely
        vm.warp(block.timestamp + 73 hours);

        vm.prank(buyer1);
        token.transfer(buyer2, purchaseAmount / 2);

        assertEq(token.balanceOf(buyer2), purchaseAmount / 2, "Transfer failed");
        console.log("  [OK] Buyer1 transferred to Buyer2 in secondary market");
    }

    function test_TokenomicsAfterTrading() public {
        console.log("\n=== Verifying Tokenomics After Trading ===\n");

        // Complete full flow
        uint256 factoryBalance = token.balanceOf(address(tokenFactory));
        _startPrimarySale(factoryBalance);
        _testPrimaryMarketPurchases();

        // Calculate total distribution
        uint256 totalSupply = token.totalSupply();
        uint256 ownerBalance = token.balanceOf(landowner);
        uint256 buyer1Balance = token.balanceOf(buyer1);
        uint256 buyer2Balance = token.balanceOf(buyer2);
        uint256 buyer3Balance = token.balanceOf(buyer3);
        uint256 treasuryBalance = token.balanceOf(treasury);

        console.log("\nToken Distribution:");
        console.log("  Total Supply:", totalSupply / 1e18);
        console.log("  Landowner (51%):", ownerBalance / 1e18);
        console.log("  Treasury (2.5%):", treasuryBalance / 1e18);
        console.log("  Buyer 1:", buyer1Balance / 1e18);
        console.log("  Buyer 2:", buyer2Balance / 1e18);
        console.log("  Buyer 3:", buyer3Balance / 1e18);

        // Verify conservation of tokens
        uint256 accountedFor = ownerBalance + buyer1Balance + buyer2Balance + buyer3Balance + treasuryBalance
            + token.balanceOf(address(primaryMarket));

        assertEq(accountedFor, totalSupply, "Token conservation violated");
        console.log("\n  [OK] Token conservation verified");
        console.log("  [OK] All tokenomics correct after trading");
    }
}
