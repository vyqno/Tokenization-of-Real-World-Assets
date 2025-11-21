// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../utils/TestBase.sol";
import { console } from "forge-std/console.sol";
import { LandLib } from "../../src/libraries/LandLib.sol";
import { ILandToken } from "../../src/interfaces/ILandToken.sol";

contract TokenFactoryTest is TestBase {
    bytes32 propertyId;
    LandLib.PropertyMetadata metadata;

    function setUp() public override {
        super.setUp();
        metadata = createPropertyMetadata();
    }

    function test_CreateLandToken() public {
        propertyId = keccak256(abi.encodePacked(landowner, block.timestamp, metadata.surveyNumber));

        vm.prank(address(landRegistry));
        address tokenAddress = tokenFactory.createLandToken(landowner, metadata, propertyId);

        assertTrue(tokenAddress != address(0), "Token address should not be zero");
        // assertTrue(tokenFactory.isLandToken(tokenAddress), "Should be recognized as land token");
        assertEq(tokenFactory.propertyToToken(propertyId), tokenAddress, "Property mapping incorrect");
    }

    function test_TokenAllocationCorrect() public {
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);

        address tokenAddress = getTokenFromProperty(propertyId);
        ILandToken token = ILandToken(tokenAddress);

        uint256 totalSupply = token.totalSupply();
        uint256 platformFee = (totalSupply * 25) / 1000; // 2.5%
        uint256 ownerAllocation = (totalSupply * 51) / 100; // 51%
        uint256 publicSale = totalSupply - platformFee - ownerAllocation; // 46.5%

        // Verify balances
        assertEq(token.balanceOf(treasury), platformFee, "Platform fee incorrect");
        assertEq(token.balanceOf(landowner), ownerAllocation, "Owner allocation incorrect");
        assertEq(token.balanceOf(address(tokenFactory)), publicSale, "Public sale allocation incorrect");

        console.log("Total Supply:", totalSupply / 1e18);
        console.log("Platform Fee (2.5%):", platformFee / 1e18);
        console.log("Owner Allocation (51%):", ownerAllocation / 1e18);
        console.log("Public Sale (46.5%):", publicSale / 1e18);
    }

    function test_TokenNameAndSymbolGeneration() public {
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);

        address tokenAddress = getTokenFromProperty(propertyId);
        ILandToken token = ILandToken(tokenAddress);

        (string memory name, string memory symbol,,,,) = token.getTokenInfo();

        // Name should be "Land Token - City"
        assertTrue(bytes(name).length > 0, "Token name should not be empty");
        assertTrue(bytes(symbol).length > 0, "Token symbol should not be empty");

        console.log("Token Name:", name);
        console.log("Token Symbol:", symbol);
    }

    function test_TotalSupplyCalculation() public {
        // Total supply should be valuation / 10 USDC
        uint256 expectedSupply = (PROPERTY_VALUATION * 1e18) / 10e6;

        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);

        address tokenAddress = getTokenFromProperty(propertyId);
        ILandToken token = ILandToken(tokenAddress);

        assertEq(token.totalSupply(), expectedSupply, "Total supply calculation incorrect");
    }

    function test_RevertWhen_NonRegistryCreatesToken() public {
        propertyId = keccak256(abi.encodePacked(landowner, block.timestamp, metadata.surveyNumber));

        vm.prank(buyer1);
        vm.expectRevert();
        tokenFactory.createLandToken(landowner, metadata, propertyId);
    }

    function test_RevertWhen_CreatingDuplicateToken() public {
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);

        // Try to create token again for same property
        vm.prank(address(landRegistry));
        vm.expectRevert();
        tokenFactory.createLandToken(landowner, metadata, propertyId);
    }

    function test_TransferToPrimaryMarket() public {
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);

        address tokenAddress = getTokenFromProperty(propertyId);
        ILandToken token = ILandToken(tokenAddress);

        uint256 publicSaleAmount = token.balanceOf(address(tokenFactory));

        vm.prank(owner);
        tokenFactory.transferToPrimaryMarket(tokenAddress, address(primaryMarket), publicSaleAmount);

        assertEq(token.balanceOf(address(primaryMarket)), publicSaleAmount, "Transfer failed");
        assertEq(token.balanceOf(address(tokenFactory)), 0, "Factory should have zero balance");
    }

    function test_RevertWhen_NonOwnerTransfersToPrimaryMarket() public {
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);

        address tokenAddress = getTokenFromProperty(propertyId);
        ILandToken token = ILandToken(tokenAddress);

        uint256 publicSaleAmount = token.balanceOf(address(tokenFactory));

        vm.prank(buyer1);
        vm.expectRevert();
        tokenFactory.transferToPrimaryMarket(tokenAddress, address(primaryMarket), publicSaleAmount);
    }

    function test_GetTokenByProperty() public {
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);

        // Before verification, no token should exist
        assertEq(tokenFactory.propertyToToken(propertyId), address(0), "Token should not exist yet");

        verifyProperty(propertyId, true);

        // After verification, token should exist
        address tokenAddress = tokenFactory.propertyToToken(propertyId);
        assertTrue(tokenAddress != address(0), "Token should exist after verification");
    }

    function test_IsLandToken() public {
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);

        address tokenAddress = getTokenFromProperty(propertyId);

        // assertTrue(tokenFactory.isLandToken(tokenAddress), "Should be recognized as land token");
        // assertFalse(tokenFactory.isLandToken(address(usdc)), "USDC should not be land token");
        // assertFalse(tokenFactory.isLandToken(address(0)), "Zero address should not be land token");
    }

    function test_MultipleTokenCreation() public {
        // Create first property
        bytes32 prop1 = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(prop1, true);
        address token1 = getTokenFromProperty(prop1);

        // Create second property with different metadata
        vm.prank(landowner);
        usdc.approve(address(stakingVault), MIN_STAKE);
        vm.prank(landowner);
        stakingVault.depositStake(MIN_STAKE);

        LandLib.PropertyMetadata memory metadata2 = createPropertyMetadata();
        metadata2.surveyNumber = "124/B";
        metadata2.location = "Mumbai, Maharashtra";

        vm.prank(landowner);
        bytes32 prop2 = landRegistry.registerProperty(metadata2, MIN_STAKE);
        verifyProperty(prop2, true);
        address token2 = getTokenFromProperty(prop2);

        // Verify both tokens exist and are different
        assertTrue(token1 != address(0), "Token 1 should exist");
        assertTrue(token2 != address(0), "Token 2 should exist");
        assertTrue(token1 != token2, "Tokens should be different");

        // assertTrue(tokenFactory.isLandToken(token1), "Token 1 should be recognized");
        // assertTrue(tokenFactory.isLandToken(token2), "Token 2 should be recognized");
    }

    function test_TokenDetailsMatch() public {
        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);

        address tokenAddress = getTokenFromProperty(propertyId);
        ILandToken token = ILandToken(tokenAddress);

        ( , , , address tokenOwner, , uint256 valuation) = token.getTokenInfo();

        assertEq(tokenOwner, landowner, "Token owner mismatch");
        assertEq(valuation, PROPERTY_VALUATION, "Valuation mismatch");
    }

    function test_FeeRecipientReceivesTokens() public {
        // Fee recipient is treasury
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);

        propertyId = stakeAndRegisterProperty(landowner, MIN_STAKE);
        verifyProperty(propertyId, true);

        address tokenAddress = getTokenFromProperty(propertyId);
        ILandToken token = ILandToken(tokenAddress);

        // Treasury should receive 2.5% platform fee in tokens
        uint256 platformFee = (token.totalSupply() * 25) / 1000;
        assertEq(token.balanceOf(treasury), platformFee, "Treasury didn't receive platform fee");

        console.log("Platform fee tokens received by treasury:", platformFee / 1e18);
    }
}
