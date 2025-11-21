// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../utils/TestBase.sol";
import { console } from "forge-std/console.sol";
import { LandLib } from "../../src/libraries/LandLib.sol";

contract StakingVaultTest is TestBase {
    bytes32 propertyId;

    function setUp() public override {
        super.setUp();

        // Fund the bonus pool before tests (CRITICAL for new system)
        // Fund with enough for all tests
        vm.startPrank(owner);
        usdc.approve(address(stakingVault), 1_000_000e6);
        stakingVault.fundBonusPool(1_000_000e6); // 1M USDC bonus pool
        vm.stopPrank();
    }

    function test_FundBonusPool() public {
        uint256 fundAmount = 100_000e6;
        uint256 poolBefore = stakingVault.bonusPool();

        vm.startPrank(owner);
        usdc.approve(address(stakingVault), fundAmount);
        stakingVault.fundBonusPool(fundAmount);
        vm.stopPrank();

        assertEq(stakingVault.bonusPool(), poolBefore + fundAmount);
    }

    function test_RevertWhen_FundBonusPoolWithZero() public {
        vm.startPrank(owner);
        vm.expectRevert();
        stakingVault.fundBonusPool(0);
        vm.stopPrank();
    }

    function test_GetBonusPoolStatus() public {
        (uint256 available, uint256 totalPaid) = stakingVault.getBonusPoolStatus();
        assertGt(available, 0); // Should have balance from setUp
        assertEq(totalPaid, 0); // No bonuses paid yet
    }

    function test_DepositStake() public {
        uint256 stakeAmount = MIN_STAKE;

        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), stakeAmount);
        stakingVault.depositStake(stakeAmount);
        vm.stopPrank();

        assertEq(stakingVault.stakes(landowner), stakeAmount);
        // Vault has INITIAL_BALANCE (10M) + deposited stake
        assertUSDCBalance(address(stakingVault), INITIAL_BALANCE + stakeAmount);
    }

    function test_RevertWhen_DepositZeroStake() public {
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), MIN_STAKE);
        vm.expectRevert();
        stakingVault.depositStake(0);
        vm.stopPrank();
    }

    function test_ReleaseStake_WithBonus() public {
        // Deposit stake
        uint256 stakeAmount = MIN_STAKE;
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), stakeAmount);
        stakingVault.depositStake(stakeAmount);
        vm.stopPrank();

        uint256 ownerBalanceBefore = usdc.balanceOf(landowner);
        uint256 bonusPoolBefore = stakingVault.bonusPool();

        // Release with bonus (approved=true)
        vm.prank(address(landRegistry));
        stakingVault.releaseStake(landowner, stakeAmount, true);

        // Should get stake + 2% bonus (from bonus pool)
        uint256 bonus = stakeAmount * 2 / 100;
        uint256 expectedBalance = ownerBalanceBefore + stakeAmount + bonus;
        assertUSDCBalance(landowner, expectedBalance);
        assertEq(stakingVault.stakes(landowner), 0);

        // Bonus pool should be reduced
        assertEq(stakingVault.bonusPool(), bonusPoolBefore - bonus);

        // Verify totalBonusPaid tracking
        assertEq(stakingVault.totalBonusPaid(), bonus);
    }

    function test_ReleaseStake_WithFee() public {
        // Deposit stake
        uint256 stakeAmount = MIN_STAKE;
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), stakeAmount);
        stakingVault.depositStake(stakeAmount);
        vm.stopPrank();

        uint256 ownerBalanceBefore = usdc.balanceOf(landowner);
        uint256 bonusPoolBefore = stakingVault.bonusPool();

        // Release with fee (approved=false)
        vm.prank(address(landRegistry));
        stakingVault.releaseStake(landowner, stakeAmount, false);

        // Owner should get stake - 1% fee
        uint256 fee = stakeAmount * 1 / 100;
        uint256 expectedOwnerBalance = ownerBalanceBefore + stakeAmount - fee;
        assertUSDCBalance(landowner, expectedOwnerBalance);

        // Fee should go to bonus pool (auto-replenish)
        assertEq(stakingVault.bonusPool(), bonusPoolBefore + fee);
        assertEq(stakingVault.stakes(landowner), 0);
    }

    function test_SlashStake() public {
        // Deposit stake
        uint256 stakeAmount = MIN_STAKE;
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), stakeAmount);
        stakingVault.depositStake(stakeAmount);
        vm.stopPrank();

        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);
        uint256 bonusPoolBefore = stakingVault.bonusPool();

        // Slash stake
        vm.prank(address(landRegistry));
        stakingVault.slashStake(landowner, stakeAmount);

        // 50% to bonus pool, 50% to treasury
        uint256 toBonus = stakeAmount / 2;
        uint256 toTreasury = stakeAmount - toBonus;

        assertUSDCBalance(treasury, treasuryBalanceBefore + toTreasury);
        assertEq(stakingVault.bonusPool(), bonusPoolBefore + toBonus);
        assertEq(stakingVault.stakes(landowner), 0);
    }

    function test_RevertWhen_NonRegistryReleasesStake() public {
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), MIN_STAKE);
        stakingVault.depositStake(MIN_STAKE);
        vm.stopPrank();

        // Try to release as non-registry
        vm.prank(buyer1);
        vm.expectRevert();
        stakingVault.releaseStake(landowner, MIN_STAKE, true);
    }

    function test_RevertWhen_SlashingWithInsufficientBalance() public {
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), MIN_STAKE);
        stakingVault.depositStake(MIN_STAKE);
        vm.stopPrank();

        // Try to slash more than balance
        vm.prank(address(landRegistry));
        vm.expectRevert();
        stakingVault.slashStake(landowner, MIN_STAKE * 2);
    }

    function test_EmergencyWithdraw() public {
        uint256 stakeAmount = MIN_STAKE;

        // Deposit stake
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), stakeAmount);
        stakingVault.depositStake(stakeAmount);
        vm.stopPrank();

        // Wait for emergency withdrawal period (72h verification + 7 days)
        vm.warp(block.timestamp + 72 hours + 7 days + 1);

        uint256 ownerBalanceBefore = usdc.balanceOf(landowner);

        // Emergency withdraw
        vm.prank(landowner);
        stakingVault.emergencyWithdraw();

        // Should get full stake back
        assertUSDCBalance(landowner, ownerBalanceBefore + stakeAmount);
        assertEq(stakingVault.stakes(landowner), 0);
    }

    function test_RevertWhen_EmergencyWithdrawTooEarly() public {
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), MIN_STAKE);
        stakingVault.depositStake(MIN_STAKE);
        vm.stopPrank();

        // Try to withdraw before period ends
        vm.warp(block.timestamp + 72 hours);

        vm.prank(landowner);
        vm.expectRevert();
        stakingVault.emergencyWithdraw();
    }

    function test_MultipleStakeDeposits() public {
        uint256 firstStake = MIN_STAKE;
        uint256 secondStake = MIN_STAKE / 2;

        // First deposit
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), firstStake + secondStake);
        stakingVault.depositStake(firstStake);
        assertEq(stakingVault.stakes(landowner), firstStake);

        // Second deposit
        stakingVault.depositStake(secondStake);
        vm.stopPrank();

        assertEq(stakingVault.stakes(landowner), firstStake + secondStake);
        // Vault has INITIAL_BALANCE + both deposits
        assertUSDCBalance(address(stakingVault), INITIAL_BALANCE + firstStake + secondStake);
    }

    function test_PartialStakeRelease() public {
        uint256 totalStake = MIN_STAKE * 2;
        uint256 releaseAmount = MIN_STAKE;

        // Deposit stake
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), totalStake);
        stakingVault.depositStake(totalStake);
        vm.stopPrank();

        // Release partial amount with bonus
        vm.prank(address(landRegistry));
        stakingVault.releaseStake(landowner, releaseAmount, true);

        // Should have remaining stake
        assertEq(stakingVault.stakes(landowner), totalStake - releaseAmount);
    }

    function test_RevertWhen_InsufficientBonusPool() public {
        // Create a new vault with no bonus pool
        vm.startPrank(owner);
        address newVault = address(
            deployStakingVault(address(usdc), address(landRegistry), treasury)
        );
        vm.stopPrank();

        // Deposit stake
        vm.startPrank(landowner);
        usdc.approve(newVault, MIN_STAKE);
        IStakingVault(newVault).depositStake(MIN_STAKE);
        vm.stopPrank();

        // Try to release with bonus but pool is empty
        vm.prank(address(landRegistry));
        vm.expectRevert(); // Should revert with InsufficientBonusPool
        IStakingVault(newVault).releaseStake(landowner, MIN_STAKE, true);
    }

    function test_BonusPoolAutoReplenishFromRejectionsAndSlashes() public {
        uint256 initialPool = stakingVault.bonusPool();

        // Scenario 1: Rejection adds 1% to pool
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), MIN_STAKE * 3);
        stakingVault.depositStake(MIN_STAKE);
        vm.stopPrank();

        vm.prank(address(landRegistry));
        stakingVault.releaseStake(landowner, MIN_STAKE, false);

        uint256 rejectionFee = MIN_STAKE * 1 / 100;
        assertEq(stakingVault.bonusPool(), initialPool + rejectionFee);

        // Scenario 2: Slash adds 50% to pool
        vm.startPrank(landowner);
        stakingVault.depositStake(MIN_STAKE);
        vm.stopPrank();

        uint256 poolBeforeSlash = stakingVault.bonusPool();
        vm.prank(address(landRegistry));
        stakingVault.slashStake(landowner, MIN_STAKE);

        uint256 slashToPool = MIN_STAKE / 2;
        assertEq(stakingVault.bonusPool(), poolBeforeSlash + slashToPool);
    }

    function test_GetStakeBalance() public {
        assertEq(stakingVault.stakes(landowner), 0);

        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), MIN_STAKE);
        stakingVault.depositStake(MIN_STAKE);
        vm.stopPrank();

        assertEq(stakingVault.stakes(landowner), MIN_STAKE);
    }

    function test_EmergencyWithdrawBonusPool() public {
        uint256 withdrawAmount = 100_000e6;
        uint256 poolBefore = stakingVault.bonusPool();
        uint256 treasuryBefore = usdc.balanceOf(treasury);

        vm.prank(owner);
        stakingVault.emergencyWithdrawBonusPool(withdrawAmount);

        assertEq(stakingVault.bonusPool(), poolBefore - withdrawAmount);
        assertUSDCBalance(treasury, treasuryBefore + withdrawAmount);
    }

    function test_RevertWhen_EmergencyWithdrawBonusPoolTooMuch() public {
        uint256 poolBalance = stakingVault.bonusPool();

        vm.prank(owner);
        vm.expectRevert(); // InsufficientBonusPool
        stakingVault.emergencyWithdrawBonusPool(poolBalance + 1);
    }
}

// Helper to import IStakingVault interface
import { IStakingVault } from "../../src/interfaces/IStakingVault.sol";
