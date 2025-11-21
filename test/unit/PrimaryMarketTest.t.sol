// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../utils/TestBase.sol";
import { console } from "forge-std/console.sol";
import { LandLib } from "../../src/libraries/LandLib.sol";
import { ILandToken } from "../../src/interfaces/ILandToken.sol";
import { PrimaryMarket } from "../../src/trading/PrimaryMarket.sol";

contract PrimaryMarketTest is TestBase {
    bytes32 propertyId;
    address tokenAddress;
    ILandToken token;
    uint256 tokensForSale;
    uint256 pricePerToken = 10e6; // 10 USDC

    function setUp() public override {
        super.setUp();

        // Create verified property with token
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);
        tokenAddress = getTokenFromProperty(propertyId);
        token = ILandToken(tokenAddress);

        // Tokens remain with TokenFactory until startSale is called
        tokensForSale = token.balanceOf(address(tokenFactory));
    }

    // Helper function to start sale with proper setup
    function startSaleWithApproval() internal {
        // Transfer tokens from TokenFactory to owner first
        vm.prank(owner);
        tokenFactory.transferToPrimaryMarket(tokenAddress, owner, tokensForSale);
        
        // Now owner approves and starts sale (startSale will transfer to PrimaryMarket)
        vm.startPrank(owner);
        token.approve(address(primaryMarket), tokensForSale);
        primaryMarket.startSale(tokenAddress, tokensForSale, pricePerToken, landowner);
        vm.stopPrank();
    }


    function test_StartSale() public {
        startSaleWithApproval();

        assertTrue(primaryMarket.isSaleActive(tokenAddress), "Sale should be active");

        console.log("Sale started successfully");
        console.log("  Tokens for sale:", tokensForSale / 1e18);
        console.log("  Price per token:", pricePerToken / 1e6, "USDC");
    }

    function test_RevertWhen_NonOwnerStartsSale() public {
        vm.prank(buyer1);
        vm.expectRevert();
        primaryMarket.startSale(tokenAddress, tokensForSale, pricePerToken, landowner);
    }

    function test_BuyTokens() public {
        startSaleWithApproval();

        uint256 buyAmount = 1000e18; // 1000 tokens
        uint256 payment = (buyAmount * pricePerToken) / 1e18;

        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();

        assertEq(token.balanceOf(buyer1), buyAmount, "Buyer didn't receive tokens");
        console.log("Buyer1 purchased:", buyAmount / 1e18, "tokens");
    }

    function test_RevertWhen_SaleNotActive() public {
        uint256 buyAmount = 1000e18;
        uint256 payment = (buyAmount * pricePerToken) / 1e18;

        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        vm.expectRevert();
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();
    }

    function test_MaxPurchaseLimit() public {
        startSaleWithApproval();

        // Max purchase is 10% of tokens for sale
        uint256 maxPurchase = primaryMarket.getMaxPurchaseFor(tokenAddress, buyer1);
        assertEq(maxPurchase, tokensForSale / 10, "Max purchase calculation incorrect");

        console.log("Max purchase per buyer:", maxPurchase / 1e18, "tokens");
    }

    function test_RevertWhen_ExceedingMaxPurchase() public {
        startSaleWithApproval();

        uint256 maxPurchase = primaryMarket.getMaxPurchaseFor(tokenAddress, buyer1);
        uint256 excessiveAmount = maxPurchase + 1e18; // 1 token more than max
        uint256 payment = (excessiveAmount * pricePerToken) / 1e18;

        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        vm.expectRevert();
        primaryMarket.buyTokens(tokenAddress, excessiveAmount);
        vm.stopPrank();
    }

    function test_MultipleBuyersPurchase() public {
        startSaleWithApproval();

        uint256 buyAmount = 1000e18;
        uint256 payment = (buyAmount * pricePerToken) / 1e18;

        // Buyer 1
        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();

        // Buyer 2
        vm.startPrank(buyer2);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();

        // Buyer 3
        vm.startPrank(buyer3);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();

        assertEq(token.balanceOf(buyer1), buyAmount, "Buyer1 balance incorrect");
        assertEq(token.balanceOf(buyer2), buyAmount, "Buyer2 balance incorrect");
        assertEq(token.balanceOf(buyer3), buyAmount, "Buyer3 balance incorrect");

        console.log("Multiple buyers purchased successfully");
    }

    function test_FinalizeSale() public {
        startSaleWithApproval();

        // Buy some tokens
        uint256 buyAmount = 1000e18;
        uint256 payment = (buyAmount * pricePerToken) / 1e18;

        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();

        // Fast forward past sale period
        vm.warp(block.timestamp + 72 hours + 1);

        uint256 landownerBalanceBefore = usdc.balanceOf(landowner);

        vm.prank(owner);
        primaryMarket.finalizeSale(tokenAddress);

        // Landowner should receive proceeds
        uint256 landownerBalanceAfter = usdc.balanceOf(landowner);
        assertTrue(landownerBalanceAfter > landownerBalanceBefore, "Landowner didn't receive proceeds");

        assertFalse(primaryMarket.isSaleActive(tokenAddress), "Sale should be finalized");

        console.log("Sale finalized");
        console.log("  Landowner received:", (landownerBalanceAfter - landownerBalanceBefore) / 1e6, "USDC");
    }

    function test_RevertWhen_FinalizingBeforeSaleEnds() public {
        startSaleWithApproval();

        // Try to finalize immediately
        vm.prank(owner);
        vm.expectRevert();
        primaryMarket.finalizeSale(tokenAddress);
    }

    function test_UnsoldTokensBurned() public {
        startSaleWithApproval();

        // Buy only small amount
        uint256 buyAmount = 1000e18;
        uint256 payment = (buyAmount * pricePerToken) / 1e18;

        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();

        uint256 totalSupplyBefore = token.totalSupply();

        // Fast forward and finalize
        vm.warp(block.timestamp + 72 hours + 1);

        vm.prank(owner);
        primaryMarket.finalizeSale(tokenAddress);

        // Total supply should decrease
        assertTrue(token.totalSupply() < totalSupplyBefore, "Unsold tokens should be burned");

        console.log("Tokens burned:", (totalSupplyBefore - token.totalSupply()) / 1e18);
    }

    function test_GetSaleInfo() public {
        startSaleWithApproval();

        // Buy some tokens
        uint256 buyAmount = 1000e18;
        uint256 payment = (buyAmount * pricePerToken) / 1e18;

        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();

        PrimaryMarket.Sale memory sale = primaryMarket.getSale(tokenAddress);

        assertEq(sale.tokensForSale, tokensForSale, "Total tokens incorrect");
        assertEq(sale.tokensSold, buyAmount, "Tokens sold incorrect");
        assertEq(sale.pricePerToken, pricePerToken, "Price incorrect");
        assertTrue(sale.endTime > block.timestamp, "End time should be in future");
        assertTrue(sale.active, "Sale should be active");

        console.log("Sale Info:");
        console.log("  Total tokens:", sale.tokensForSale / 1e18);
        console.log("  Tokens sold:", sale.tokensSold / 1e18);
        console.log("  Price (USDC):", sale.pricePerToken / 1e6);
    }

    function test_GetMaxPurchaseFor() public {
        startSaleWithApproval();

        uint256 maxPurchase = primaryMarket.getMaxPurchaseFor(tokenAddress, buyer1);
        assertEq(maxPurchase, tokensForSale / 10, "Max purchase should be 10%");

        // Buy half of max
        uint256 buyAmount = maxPurchase / 2;
        uint256 payment = (buyAmount * pricePerToken) / 1e18;

        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();

        // Remaining max purchase should be reduced
        uint256 remainingMax = primaryMarket.getMaxPurchaseFor(tokenAddress, buyer1);
        assertEq(remainingMax, maxPurchase - buyAmount, "Remaining max purchase incorrect");
    }

    function test_IsSaleActive() public {
        assertFalse(primaryMarket.isSaleActive(tokenAddress), "Sale should not be active initially");

        startSaleWithApproval();

        assertTrue(primaryMarket.isSaleActive(tokenAddress), "Sale should be active after start");

        // Fast forward and finalize
        vm.warp(block.timestamp + 72 hours + 1);

        vm.prank(owner);
        primaryMarket.finalizeSale(tokenAddress);

        assertFalse(primaryMarket.isSaleActive(tokenAddress), "Sale should not be active after finalize");
    }

    function test_SaleDuration() public {
        uint256 startTime = block.timestamp;

        startSaleWithApproval();

        PrimaryMarket.Sale memory sale = primaryMarket.getSale(tokenAddress);

        assertEq(sale.endTime, startTime + 72 hours, "Sale duration should be 72 hours");
    }

    function test_RevertWhen_BuyingZeroTokens() public {
        startSaleWithApproval();

        vm.prank(buyer1);
        vm.expectRevert();
        primaryMarket.buyTokens(tokenAddress, 0);
    }

    function test_RevertWhen_InsufficientPayment() public {
        startSaleWithApproval();

        uint256 buyAmount = 1000e18;
        uint256 payment = (buyAmount * pricePerToken) / 1e18;

        // Approve less than required
        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment / 2);
        vm.expectRevert();
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();
    }

    function test_ProceedsGoToLandowner() public {
        startSaleWithApproval();

        uint256 buyAmount = 1000e18;
        uint256 payment = (buyAmount * pricePerToken) / 1e18;

        vm.startPrank(buyer1);
        usdc.approve(address(primaryMarket), payment);
        primaryMarket.buyTokens(tokenAddress, buyAmount);
        vm.stopPrank();

        uint256 landownerBalanceBefore = usdc.balanceOf(landowner);

        // Finalize sale
        vm.warp(block.timestamp + 72 hours + 1);

        vm.prank(owner);
        primaryMarket.finalizeSale(tokenAddress);

        uint256 landownerBalanceAfter = usdc.balanceOf(landowner);
        uint256 proceeds = landownerBalanceAfter - landownerBalanceBefore;

        // Landowner should receive all proceeds
        assertEq(proceeds, payment, "Landowner didn't receive full proceeds");
    }

//    function test_FullSaleSellout() public {
//        startSaleWithApproval();
//
//        // Calculate max purchase per buyer (10%)
//        uint256 maxPurchase = primaryMarket.getMaxPurchaseFor(tokenAddress, buyer1);
//
//        // 10 buyers buy max amount (last buyer buys remaining to avoid rounding issues)
//        address[] memory buyers = new address[](10);
//        buyers[0] = buyer1;
//        buyers[1] = buyer2;
//        buyers[2] = buyer3;
//        for (uint256 i = 3; i < 10; i++) {
//            buyers[i] = makeAddr(string(abi.encodePacked("buyer", vm.toString(i))));
//            usdc.mint(buyers[i], 1_000_000e6);
//        }
//
//        for (uint256 i = 0; i < 10; i++) {
//            // Each buyer buys min(their max remaining purchase, remaining tokens in sale)
//            uint256 remaining = primaryMarket.getRemainingTokens(tokenAddress);
//            uint256 maxForBuyer = primaryMarket.getMaxPurchaseFor(tokenAddress, buyers[i]);
//            uint256 amountToBuy = remaining < maxForBuyer ? remaining : maxForBuyer;
//            
//            if (amountToBuy == 0) break; // No more tokens to buy or buyer maxed out
//            
//            uint256 payment = (amountToBuy * pricePerToken) / 1e18;
//            vm.startPrank(buyers[i]);
//            usdc.approve(address(primaryMarket), payment);
//            primaryMarket.buyTokens(tokenAddress, amountToBuy);
//            vm.stopPrank();
//        }
//
//        PrimaryMarket.Sale memory sale = primaryMarket.getSale(tokenAddress);
//
//        assertEq(sale.tokensSold, tokensForSale, "All tokens should be sold");
//
//        console.log("Sale sold out: 100% of tokens sold");
//    }
}
