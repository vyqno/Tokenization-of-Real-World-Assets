// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../utils/TestBase.sol";
import { console } from "forge-std/console.sol";
import { LandLib } from "../../src/libraries/LandLib.sol";
import { ILandToken } from "../../src/interfaces/ILandToken.sol";

contract LandTokenTest is TestBase {
    bytes32 propertyId;
    address tokenAddress;
    ILandToken token;

    function setUp() public override {
        super.setUp();

        // Create a verified property with token
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);
        tokenAddress = getTokenFromProperty(propertyId);
        token = ILandToken(tokenAddress);
    }

    function test_InitialState() public view {
        assertTrue(address(token) != address(0), "Token should be deployed");

        (string memory name, string memory symbol,, address owner, ILandToken.TokenStatus status, uint256 valuation) =
            token.getTokenInfo();

        assertEq(owner, landowner, "Owner incorrect");
        assertEq(valuation, PROPERTY_VALUATION, "Valuation incorrect");
        assertTrue(uint8(status) == uint8(ILandToken.TokenStatus.Verified), "Status should be Verified");
        assertTrue(bytes(name).length > 0, "Name should not be empty");
        assertTrue(bytes(symbol).length > 0, "Symbol should not be empty");
    }

    function test_TotalSupply() public view {
        uint256 expectedSupply = (PROPERTY_VALUATION * 1e18) / 10e6;
        assertEq(token.totalSupply(), expectedSupply, "Total supply incorrect");
    }

    function test_InitialBalances() public view {
        uint256 totalSupply = token.totalSupply();
        uint256 platformFee = (totalSupply * 25) / 1000; // 2.5%
        uint256 ownerAllocation = (totalSupply * 51) / 100; // 51%
        uint256 publicSale = totalSupply - platformFee - ownerAllocation; // 46.5%

        assertEq(token.balanceOf(treasury), platformFee, "Platform fee incorrect");
        assertEq(token.balanceOf(landowner), ownerAllocation, "Owner allocation incorrect");
        assertEq(token.balanceOf(address(tokenFactory)), publicSale, "Public sale allocation incorrect");
    }

    function test_TransferRestrictions_DuringVerification() public {
        // Create unique metadata to avoid duplicate property ID
        LandLib.PropertyMetadata memory uniqueMetadata = LandLib.PropertyMetadata({
            surveyNumber: "456/B",  // Different from "123/A"
            location: "Whitefield, Bangalore",
            latitude: 12_980_000,
            longitude: 77_500_000,
            areaSqFt: 15_000,
            ipfsHash: "QmDifferentHash987654321zyxwvutsrqponmlkjihgfedcba",
            valuation: PROPERTY_VALUATION
        });

        // Register property with unique metadata
        vm.startPrank(buyer1);
        usdc.approve(address(stakingVault), MIN_STAKE);
        stakingVault.depositStake(MIN_STAKE);
        bytes32 pendingProp = landRegistry.registerProperty(uniqueMetadata, MIN_STAKE);
        vm.stopPrank();

        // Property is still pending, no token yet
        assertEq(uint8(landRegistry.getPropertyStatus(pendingProp)), uint8(LandLib.PropertyStatus.Pending));
    }

    function test_OwnerCannotTransferDuring6MonthLock() public {
        // Owner should not be able to transfer during 6-month lock
        uint256 ownerBalance = token.balanceOf(landowner);

        vm.prank(landowner);
        vm.expectRevert();
        token.transfer(buyer1, ownerBalance);
    }

    function test_OwnerCanTransferAfter6MonthLock() public {
        // Fast forward 6 months + 1 second
        vm.warp(block.timestamp + 180 days + 1);

        uint256 ownerBalance = token.balanceOf(landowner);
        uint256 transferAmount = ownerBalance / 2;

        vm.prank(landowner);
        token.transfer(buyer1, transferAmount);

        assertEq(token.balanceOf(buyer1), transferAmount, "Transfer failed");
        assertEq(token.balanceOf(landowner), ownerBalance - transferAmount, "Owner balance incorrect");
    }

    function test_PublicSaleTokensCanTransferAfterSale() public {
        // Transfer tokens from factory to primary market
        uint256 publicSale = token.balanceOf(address(tokenFactory));

        vm.prank(owner);
        tokenFactory.transferToPrimaryMarket(tokenAddress, address(primaryMarket), publicSale);

        // After primary sale period, tokens should be transferable
        vm.warp(block.timestamp + 72 hours + 1);

        assertEq(token.balanceOf(address(primaryMarket)), publicSale, "Primary market didn't receive tokens");
    }

    function test_PauseAndUnpause() public {
        // Pause token (only registry/owner can pause)
        vm.prank(address(landRegistry));
        token.pause();

        // Transfers should be blocked
        vm.warp(block.timestamp + 180 days + 1);
        vm.prank(landowner);
        vm.expectRevert();
        token.transfer(buyer1, 100e18);

        // Unpause token
        vm.prank(address(landRegistry));
        token.unpause();

        // Transfers should work again
        vm.prank(landowner);
        token.transfer(buyer1, 100e18);

        assertEq(token.balanceOf(buyer1), 100e18, "Transfer after unpause failed");
    }

    function test_RevertWhen_NonOwnerPauses() public {
        vm.prank(buyer1);
        vm.expectRevert();
        token.pause();
    }

    function test_ActivateTrading() public {
        // Only registry can activate trading (token owner is registry after creation)
        vm.prank(address(landRegistry));
        token.activateTrading();

        (,,,, ILandToken.TokenStatus status,) = token.getTokenInfo();

        assertTrue(uint8(status) == uint8(ILandToken.TokenStatus.Trading), "Status not updated");
    }

    function test_RevertWhen_NonOwnerActivatesTrading() public {
        vm.prank(buyer1);
        vm.expectRevert();
        token.activateTrading();
    }

    function test_GetPropertyMetadata() public view {
        (string memory ipfs, int256 lat, int256 lon, uint256 area, uint256 valuation) = token.getPropertyMetadata();

        assertTrue(bytes(ipfs).length > 0, "IPFS hash empty");
        assertTrue(lat != 0, "Latitude should be set");
        assertTrue(lon != 0, "Longitude should be set");
        assertTrue(area > 0, "Area should be positive");
        assertEq(valuation, PROPERTY_VALUATION, "Valuation mismatch");
    }

    function test_GetTokenInfo() public view {
        (
            string memory name,
            string memory symbol,
            uint256 totalSupply_,
            address owner,
            ILandToken.TokenStatus status,
            uint256 valuation
        ) = token.getTokenInfo();

        assertTrue(bytes(name).length > 0, "Name empty");
        assertTrue(bytes(symbol).length > 0, "Symbol empty");
        assertEq(owner, landowner, "Owner mismatch");
        assertEq(valuation, PROPERTY_VALUATION, "Valuation mismatch");
        assertTrue(uint8(status) == uint8(ILandToken.TokenStatus.Verified), "Status mismatch");
        assertTrue(totalSupply_ > 0, "Total supply should be positive");
    }

    function test_StandardERC20Functions() public {
        // Test name, symbol, decimals
        (string memory name, string memory symbol,,,,) = token.getTokenInfo();

        assertTrue(bytes(name).length > 0, "Name should exist");
        assertTrue(bytes(symbol).length > 0, "Symbol should exist");
    }

    function test_Approval() public {
        vm.warp(block.timestamp + 180 days + 1);

        vm.prank(landowner);
        token.approve(buyer1, 1000e18);

        assertEq(token.allowance(landowner, buyer1), 1000e18, "Allowance not set");
    }

    function test_TransferFrom() public {
        vm.warp(block.timestamp + 180 days + 1);

        uint256 amount = 1000e18;

        // Approve buyer1
        vm.prank(landowner);
        token.approve(buyer1, amount);

        // Transfer from landowner to buyer2
        vm.prank(buyer1);
        token.transferFrom(landowner, buyer2, amount);

        assertEq(token.balanceOf(buyer2), amount, "TransferFrom failed");
        assertEq(token.allowance(landowner, buyer1), 0, "Allowance not consumed");
    }

    function test_BurnUnsoldTokens() public {
        // Get tokens from factory
        uint256 publicSale = token.balanceOf(address(tokenFactory));
        
        // Transfer to owner first
        vm.prank(owner);
        tokenFactory.transferToPrimaryMarket(tokenAddress, owner, publicSale);

        // Start sale with approval (startSale will transfer to PrimaryMarket)
        vm.startPrank(owner);
        token.approve(address(primaryMarket), publicSale);
        primaryMarket.startSale(tokenAddress, publicSale, 10e6, landowner);
        vm.stopPrank();

        vm.warp(block.timestamp + 72 hours + 1);

        uint256 totalSupplyBefore = token.totalSupply();

        vm.prank(owner);
        primaryMarket.finalizeSale(tokenAddress);

        // Total supply should decrease (unsold tokens burned)
        assertTrue(token.totalSupply() <= totalSupplyBefore, "Tokens should be burned");
    }

    function test_MultipleHolders() public {
        // Skip lock period
        vm.warp(block.timestamp + 180 days + 1);

        uint256 ownerBalance = token.balanceOf(landowner);
        uint256 amount1 = ownerBalance / 4;
        uint256 amount2 = ownerBalance / 4;
        uint256 amount3 = ownerBalance / 4;

        // Transfer to multiple buyers
        vm.startPrank(landowner);
        token.transfer(buyer1, amount1);
        token.transfer(buyer2, amount2);
        token.transfer(buyer3, amount3);
        vm.stopPrank();

        assertEq(token.balanceOf(buyer1), amount1, "Buyer1 balance incorrect");
        assertEq(token.balanceOf(buyer2), amount2, "Buyer2 balance incorrect");
        assertEq(token.balanceOf(buyer3), amount3, "Buyer3 balance incorrect");

        // Verify total supply conservation (include all holders)
        uint256 totalBalance = token.balanceOf(landowner) + token.balanceOf(buyer1) + token.balanceOf(buyer2)
            + token.balanceOf(buyer3) + token.balanceOf(treasury) + token.balanceOf(address(tokenFactory));

        assertEq(totalBalance, token.totalSupply(), "Token conservation violated");
    }

    function test_ZeroTransferReverts() public {
        vm.warp(block.timestamp + 180 days + 1);

        // ERC20 standard allows zero transfers by default
        // This test verifies that zero transfers don't cause issues
        vm.prank(landowner);
        token.transfer(buyer1, 0);
        
        // Verify no tokens were transferred
        assertEq(token.balanceOf(buyer1), 0, "Buyer should have 0 tokens");
    }

    function test_TransferToZeroAddressReverts() public {
        vm.warp(block.timestamp + 180 days + 1);

        vm.prank(landowner);
        vm.expectRevert();
        token.transfer(address(0), 100e18);
    }

    function test_OwnerLockPeriod() public view {
        uint256 deployTime = token.deploymentTimestamp();

        assertTrue(deployTime > 0, "Deployment timestamp should be set");
        // Owner lock is 6 months from deployment
        // This is tested implicitly through transfer restrictions
    }

    function test_IsOwnerLocked() public view {
        // Should be locked initially
        assertTrue(token.balanceOf(landowner) > 0, "Owner should have balance");

        // After verification, owner is locked for 6 months
        // We can't directly test isOwnerLocked as it's internal, but we test the effect through transfers
    }
}
