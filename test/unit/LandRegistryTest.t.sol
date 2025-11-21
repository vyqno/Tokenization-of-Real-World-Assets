// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../utils/TestBase.sol";
import { console } from "forge-std/console.sol";
import { LandLib } from "../../src/libraries/LandLib.sol";

contract LandRegistryTest is TestBase {
    bytes32 propertyId;

    function test_RegisterProperty() public {
        uint256 stakeAmount = MIN_STAKE;

        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), stakeAmount);
        stakingVault.depositStake(stakeAmount);

        LandLib.PropertyMetadata memory metadata = createPropertyMetadata();
        propertyId = landRegistry.registerProperty(metadata, stakeAmount);
        vm.stopPrank();

        // Assertions
        assertPropertyStatus(propertyId, LandLib.PropertyStatus.Pending);
        assertEq(landRegistry.totalPropertiesRegistered(), 1);
    }

    function test_RevertWhen_InsufficientStake() public {
        uint256 insufficientStake = MIN_STAKE - 1;

        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), insufficientStake);
        stakingVault.depositStake(insufficientStake);

        LandLib.PropertyMetadata memory metadata = createPropertyMetadata();

        vm.expectRevert();
        landRegistry.registerProperty(metadata, insufficientStake);
        vm.stopPrank();
    }

    function test_VerifyProperty_Approved() public {
        // Register property
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);

        uint256 ownerBalanceBefore = usdc.balanceOf(landowner);

        // Verify
        verifyProperty(propertyId, true);

        // Assertions
        assertPropertyStatus(propertyId, LandLib.PropertyStatus.Verified);
        assertEq(landRegistry.totalPropertiesVerified(), 1);

        // Check stake returned with bonus (2%)
        uint256 expectedBalance = ownerBalanceBefore + MIN_STAKE + (MIN_STAKE * 2 / 100);
        assertUSDCBalance(landowner, expectedBalance);

        // Check token was created
        address tokenAddress = getTokenFromProperty(propertyId);
        assertTrue(tokenAddress != address(0), "Token should be created");
    }

    function test_VerifyProperty_Rejected() public {
        // Register property
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);

        uint256 ownerBalanceBefore = usdc.balanceOf(landowner);

        // Reject
        verifyProperty(propertyId, false);

        // Assertions
        assertPropertyStatus(propertyId, LandLib.PropertyStatus.Rejected);

        // Check stake returned with fee (1% deducted)
        uint256 expectedBalance = ownerBalanceBefore + MIN_STAKE - (MIN_STAKE * 1 / 100);
        assertUSDCBalance(landowner, expectedBalance);
    }

    function test_SlashProperty() public {
        // Register property
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);

        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);

        // Slash
        vm.prank(verifier);
        landRegistry.slashProperty(propertyId, "Fraudulent documents");

        // Assertions
        assertPropertyStatus(propertyId, LandLib.PropertyStatus.Slashed);
        assertTrue(landRegistry.isBlacklisted(propertyId), "Property should be blacklisted");
        assertEq(landRegistry.totalPropertiesSlashed(), 1);

        // Check stake went to treasury
        assertUSDCBalance(treasury, treasuryBalanceBefore + MIN_STAKE);
    }

    function test_RevertWhen_NonVerifierVerifies() public {
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);

        vm.prank(buyer1);
        vm.expectRevert();
        landRegistry.verifyProperty(propertyId, true);
    }

    function test_RevertWhen_VerifyingNonPendingProperty() public {
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);

        // Verify once
        verifyProperty(propertyId, true);

        // Try to verify again
        vm.prank(verifier);
        vm.expectRevert();
        landRegistry.verifyProperty(propertyId, true);
    }

    function test_GetOwnerProperties() public {
        // Register multiple properties
        bytes32 prop1 = stakeAndRegisterProperty(landowner, MIN_STAKE);

        vm.prank(landowner);
        usdc.approve(address(stakingVault), MIN_STAKE);
        vm.prank(landowner);
        stakingVault.depositStake(MIN_STAKE);

        LandLib.PropertyMetadata memory metadata2 = createPropertyMetadata();
        metadata2.surveyNumber = "124/B";

        vm.prank(landowner);
        bytes32 prop2 = landRegistry.registerProperty(metadata2, MIN_STAKE);

        // Get properties
        bytes32[] memory properties = landRegistry.getOwnerProperties(landowner);

        assertEq(properties.length, 2, "Should have 2 properties");
        assertEq(properties[0], prop1, "First property mismatch");
        assertEq(properties[1], prop2, "Second property mismatch");
    }

    function test_CalculateMinStake() public view {
        uint256 minStake = landRegistry.calculateMinStake(PROPERTY_VALUATION);
        assertEq(minStake, MIN_STAKE, "Min stake calculation incorrect");
    }

    function test_AddAndRemoveVerifier() public {
        address newVerifier = makeAddr("newVerifier");

        // Add verifier
        landRegistry.addVerifier(newVerifier);
        assertTrue(landRegistry.isVerifier(newVerifier), "Verifier should be added");

        // Remove verifier
        landRegistry.removeVerifier(newVerifier);
        assertFalse(landRegistry.isVerifier(newVerifier), "Verifier should be removed");
    }
}
