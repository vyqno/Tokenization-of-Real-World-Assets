// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../utils/TestBase.sol";
import { console } from "forge-std/console.sol";
import { LandLib } from "../../src/libraries/LandLib.sol";

contract StakingVaultTest is TestBase {
    bytes32 propertyId;

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

        // Release with bonus (approved=true)
        vm.prank(address(landRegistry));
        stakingVault.releaseStake(landowner, stakeAmount, true);

        // Should get stake + 2% bonus
        uint256 expectedBalance = ownerBalanceBefore + stakeAmount + (stakeAmount * 2 / 100);
        assertUSDCBalance(landowner, expectedBalance);
        assertEq(stakingVault.stakes(landowner), 0);
    }

    function test_ReleaseStake_WithFee() public {
        // Deposit stake
        uint256 stakeAmount = MIN_STAKE;
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), stakeAmount);
        stakingVault.depositStake(stakeAmount);
        vm.stopPrank();

        uint256 ownerBalanceBefore = usdc.balanceOf(landowner);
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);

        // Release with fee (approved=false)
        vm.prank(address(landRegistry));
        stakingVault.releaseStake(landowner, stakeAmount, false);

        // Owner should get stake - 1% fee
        uint256 fee = stakeAmount * 1 / 100;
        uint256 expectedOwnerBalance = ownerBalanceBefore + stakeAmount - fee;
        assertUSDCBalance(landowner, expectedOwnerBalance);

        // Treasury should receive the fee
        assertUSDCBalance(treasury, treasuryBalanceBefore + fee);
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

        // Slash stake
        vm.prank(address(landRegistry));
        stakingVault.slashStake(landowner, stakeAmount);

        // All stake should go to treasury
        assertUSDCBalance(treasury, treasuryBalanceBefore + stakeAmount);
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

    function test_TreasuryReceivesBonusAndFees() public {
        uint256 treasuryBalanceStart = usdc.balanceOf(treasury);
        uint256 vaultBalanceStart = usdc.balanceOf(address(stakingVault));

        // Scenario 1: Approved property (vault pays 2% bonus from its funds)
        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), MIN_STAKE * 2);
        stakingVault.depositStake(MIN_STAKE);
        vm.stopPrank();

        vm.prank(address(landRegistry));
        stakingVault.releaseStake(landowner, MIN_STAKE, true);

        uint256 bonus = MIN_STAKE * 2 / 100;
        // Vault pays bonus from its own funds, not treasury
        assertUSDCBalance(address(stakingVault), vaultBalanceStart - bonus);

        // Scenario 2: Rejected property (treasury receives 1% fee)
        vm.startPrank(landowner);
        stakingVault.depositStake(MIN_STAKE);
        vm.stopPrank();

        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);

        vm.prank(address(landRegistry));
        stakingVault.releaseStake(landowner, MIN_STAKE, false);

        uint256 fee = MIN_STAKE * 1 / 100;
        // Treasury should receive the fee
        assertUSDCBalance(treasury, treasuryBalanceBefore + fee);
    }

    function test_GetStakeBalance() public {
        assertEq(stakingVault.stakes(landowner), 0);

        vm.startPrank(landowner);
        usdc.approve(address(stakingVault), MIN_STAKE);
        stakingVault.depositStake(MIN_STAKE);
        vm.stopPrank();

        assertEq(stakingVault.stakes(landowner), MIN_STAKE);
    }
}
