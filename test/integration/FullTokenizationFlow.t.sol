// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../utils/TestBase.sol";
import { LandLib } from "../../src/libraries/LandLib.sol";
import { ILandToken } from "../../src/interfaces/ILandToken.sol";
import { console } from "forge-std/console.sol";

/**
 * @title FullTokenizationFlowTest
 * @notice Integration test for complete property tokenization workflow
 * Tests: Registration → Staking → Verification → Token Creation → Distribution
 */
contract FullTokenizationFlowTest is TestBase {
    bytes32 propertyId;
    address tokenAddress;

    function test_CompleteTokenizationFlow() public {
        console.log("\n=== Starting Complete Tokenization Flow Test ===\n");

        // STEP 1: Landowner stakes USDC
        console.log("Step 1: Landowner stakes USDC");
        uint256 stakeAmount = MIN_STAKE;
        uint256 landownerInitialBalance = usdc.balanceOf(landowner);

        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), stakeAmount);
        stakingVault.depositStake(stakeAmount);
        vm.stopPrank();

        assertEq(stakingVault.stakes(landowner), stakeAmount, "Stake not recorded");
        assertEq(usdc.balanceOf(landowner), landownerInitialBalance - stakeAmount, "USDC not deducted");
        console.log("  [OK] Staked:", stakeAmount);

        // STEP 2: Register property
        console.log("\nStep 2: Register property");
        LandLib.PropertyMetadata memory metadata = createPropertyMetadata();

        vm.prank(landowner);
        propertyId = landRegistry.registerProperty(metadata, stakeAmount);

        assertPropertyStatus(propertyId, LandLib.PropertyStatus.Pending);
        assertEq(landRegistry.totalPropertiesRegistered(), 1);
        console.log("  [OK] Property registered with ID:", vm.toString(propertyId));

        // STEP 3: Verifier approves
        console.log("\nStep 3: Verifier approves property");
        vm.prank(verifier);
        landRegistry.verifyProperty(propertyId, true);

        assertPropertyStatus(propertyId, LandLib.PropertyStatus.Verified);
        assertEq(landRegistry.totalPropertiesVerified(), 1);
        console.log("  [OK] Property verified");

        // STEP 4: Check token was created
        console.log("\nStep 4: Verify token creation");
        LandLib.PropertyData memory propData = landRegistry.getPropertyData(propertyId);
        tokenAddress = propData.tokenAddress;

        assertTrue(tokenAddress != address(0), "Token not created");

        ILandToken token = ILandToken(tokenAddress);
        console.log("  [OK] Token created at:", tokenAddress);

        (string memory name, string memory symbol,,,,) = token.getTokenInfo();
        console.log("    Name:", name);
        console.log("    Symbol:", symbol);

        // STEP 5: Verify tokenomics
        console.log("\nStep 5: Verify tokenomics and distribution");
        _verifyTokenomics(token);

        // STEP 6: Verify stake bonus was paid
        console.log("\nStep 6: Verify stake returned with bonus");
        uint256 bonus = (stakeAmount * 2) / 100; // 2% bonus
        uint256 expectedBalance = landownerInitialBalance + bonus;
        assertEq(usdc.balanceOf(landowner), expectedBalance, "Bonus not paid correctly");
        console.log("  [OK] Stake returned with 2% bonus:", bonus);

        console.log("\n=== Tokenization Flow Test Complete ===\n");
    }

    function _verifyTokenomics(ILandToken token) internal view {
        uint256 totalSupply = token.totalSupply();
        address originalOwner = token.originalOwner();
        uint256 ownerAllocation = token.ownerAllocation();

        console.log("  Total Supply:", totalSupply);
        console.log("  Valuation:", PROPERTY_VALUATION);

        // Calculate expected values (matching corrected LandLib logic)
        uint256 expectedTotalSupply = (PROPERTY_VALUATION / 10e6) * 1e18; // With 18 decimals
        uint256 platformFee = (expectedTotalSupply * 250) / 10_000; // 2.5% of total
        uint256 expectedOwnerAllocation = (expectedTotalSupply * 51) / 100; // 51% of total
        uint256 expectedPublicSale = expectedTotalSupply - platformFee - expectedOwnerAllocation;

        // Verify total supply
        assertEq(totalSupply, expectedTotalSupply, "Total supply incorrect");
        console.log("  [OK] Total Supply correct:", totalSupply);

        // Verify owner allocation (51% of total)
        uint256 ownerBalance = token.balanceOf(originalOwner);
        assertEq(ownerBalance, expectedOwnerAllocation, "Owner allocation incorrect");
        console.log("  [OK] Owner allocation (51%):", ownerBalance);

        // Verify platform fee (2.5%)
        uint256 treasuryBalance = token.balanceOf(treasury);
        assertEq(treasuryBalance, platformFee, "Platform fee incorrect");
        console.log("  [OK] Platform fee (2.5%):", treasuryBalance);

        // Verify factory holds tokens for public sale
        uint256 factoryBalance = token.balanceOf(address(tokenFactory));
        assertEq(factoryBalance, expectedPublicSale, "Public sale allocation incorrect");
        console.log("  [OK] Public sale allocation (46.5%):", factoryBalance);

        // Verify percentages
        uint256 ownerPercentage = (ownerBalance * 100) / totalSupply;
        uint256 feePercentage = (treasuryBalance * 10_000) / totalSupply; // In basis points
        uint256 salePercentage = (factoryBalance * 100) / totalSupply;

        assertTrue(ownerPercentage >= 50 && ownerPercentage <= 52, "Owner percentage not ~51%");
        assertTrue(feePercentage >= 240 && feePercentage <= 260, "Fee percentage not ~2.5%");
        assertTrue(salePercentage >= 45 && salePercentage <= 48, "Sale percentage not ~46.5%");

        console.log("  Percentages verified:");
        console.log("    Owner:", ownerPercentage);
        console.log("    Fee (basis points):", feePercentage);
        console.log("    Sale:", salePercentage);
    }

    function test_MultipleProperties() public {
        console.log("\n=== Testing Multiple Property Tokenization ===\n");

        // Register and verify 3 properties
        for (uint256 i = 0; i < 3; i++) {
            console.log("Processing property", i + 1);

            // Create unique property
            LandLib.PropertyMetadata memory metadata = createPropertyMetadata();
            metadata.surveyNumber = string(abi.encodePacked("PROP", vm.toString(i)));

            // Stake and register
            vm.startPrank(landowner);
            usdc.approve(address(stakingVault), MIN_STAKE);
            stakingVault.depositStake(MIN_STAKE);
            bytes32 propId = landRegistry.registerProperty(metadata, MIN_STAKE);
            vm.stopPrank();

            // Verify
            vm.prank(verifier);
            landRegistry.verifyProperty(propId, true);

            console.log("  [OK] Property", i + 1, "tokenized");
        }

        assertEq(landRegistry.totalPropertiesRegistered(), 3);
        assertEq(landRegistry.totalPropertiesVerified(), 3);
        assertEq(landRegistry.getAllTokens().length, 3);

        console.log("\n[OK] All 3 properties successfully tokenized");
        console.log("=== Multiple Properties Test Complete ===\n");
    }

    function test_TransferRestrictions() public {
        // Create and verify token
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);

        tokenAddress = getTokenFromProperty(propertyId);
        ILandToken token = ILandToken(tokenAddress);

        // Get the original owner from the token (this is who received the minted tokens)
        address originalOwner = token.originalOwner();
        uint256 ownerBalance = token.balanceOf(originalOwner);

        console.log("\n=== Testing Transfer Restrictions ===\n");

        // Test 1: Owner cannot transfer below minimum allocation
        console.log("Test 1: Owner locked allocation (6 months)");
        vm.prank(originalOwner);
        vm.expectRevert();
        token.transfer(buyer1, ownerBalance); // Try to transfer all
        console.log("  [OK] Owner cannot transfer all tokens (locked)");

        // Test 2: Owner can transfer excess (if any)
        if (ownerBalance > token.ownerAllocation()) {
            uint256 excess = ownerBalance - token.ownerAllocation() - 1;
            if (excess > 0) {
                vm.prank(originalOwner);
                token.transfer(buyer1, excess);
                console.log("  [OK] Owner can transfer excess tokens");
            }
        } else {
            console.log("  [SKIP] Owner has no excess tokens to transfer");
        }

        // Test 3: Skip time to unlock
        vm.warp(block.timestamp + 181 days);
        uint256 remainingBalance = token.balanceOf(originalOwner);
        vm.startPrank(originalOwner);
        token.transfer(buyer1, remainingBalance);
        vm.stopPrank();
        console.log("  [OK] After 6 months, owner can transfer all");

        console.log("\n=== Transfer Restrictions Test Complete ===\n");
    }
}
