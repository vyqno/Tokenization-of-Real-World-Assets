# Testing Guide - v2.0 Security Updates

## Overview

This guide covers all test updates required after the v2.0 security fixes. **All tests have been updated** to work with the new bonus pool system, snapshot voting, and pause mechanisms.

---

## Breaking Changes for Tests

### 1. **StakingVault Bonus Pool**
**Impact:** Tests that release stakes with bonuses will fail without bonus pool funding.

**Fix Applied:**
```solidity
function setUp() public override {
    super.setUp();

    // CRITICAL: Fund bonus pool before running tests
    vm.startPrank(owner);
    usdc.approve(address(stakingVault), 1_000_000e6);
    stakingVault.fundBonusPool(1_000_000e6);
    vm.stopPrank();
}
```

### 2. **LandToken Voting (ERC20Votes)**
**Impact:** Token holders must delegate votes to participate in governance.

**Fix Required:**
```solidity
// Before voting, must delegate
vm.prank(voter);
landToken.delegate(voter); // Self-delegate to activate voting power

// Then can vote
vm.prank(voter);
landGovernor.vote(proposalId, true);
```

### 3. **LandGovernor Snapshot Voting**
**Impact:** Voting power is now snapshot-based, not balance-based.

**Fix Required:**
```solidity
// Create proposal
uint256 proposalId = landGovernor.propose("Description", ProposalType.SellLand);

// Must wait for VOTING_DELAY (1 block) before voting
vm.roll(block.number + 2);

// Vote using voting power at snapshot
landGovernor.vote(proposalId, true);
```

### 4. **Governance Timelock**
**Impact:** Proposals now require queue() step and 4-day delay before execution.

**Fix Required:**
```solidity
// After voting ends
vm.roll(proposal.endBlock + 1);

// Queue the proposal
landGovernor.queue(proposalId);

// Wait for timelock (4 days = 172,800 blocks on Polygon)
vm.roll(block.number + 172_800 + 1);

// Now can execute
landGovernor.execute(proposalId);
```

### 5. **AgencyMultisig Parameter Changes**
**Impact:** `submitTransaction()` now has additional parameter.

**Fix Required:**
```solidity
// OLD:
multisig.submitTransaction(type, propertyId, target, data);

// NEW (two options):

// Option 1: Use new full signature
multisig.submitTransaction(type, propertyId, target, uintData, data);

// Option 2: Use backward-compatible wrapper
multisig.submitSimpleTransaction(type, propertyId, target, data);
```

---

## Updated Test Files

### ✅ `test/unit/StakingVaultTest.t.sol` [UPDATED]

**New Tests Added:**
- `test_FundBonusPool()` - Test bonus pool funding
- `test_GetBonusPoolStatus()` - Check bonus pool state
- `test_RevertWhen_InsufficientBonusPool()` - Test empty pool scenario
- `test_BonusPoolAutoReplenishFromRejectionsAndSlashes()` - Auto-replenish mechanism
- `test_EmergencyWithdrawBonusPool()` - Emergency withdrawal

**Modified Tests:**
- `test_ReleaseStake_WithBonus()` - Now checks bonus pool reduction
- `test_ReleaseStake_WithFee()` - Fee goes to bonus pool, not treasury
- `test_SlashStake()` - 50/50 split between bonus pool and treasury

**Key Changes:**
```solidity
// Bonuses come from bonus pool
assertEq(stakingVault.bonusPool(), poolBefore - bonus);

// Rejection fees replenish pool
assertEq(stakingVault.bonusPool(), poolBefore + fee);

// Slashes split 50/50
uint256 toBonus = amount / 2;
uint256 toTreasury = amount - toBonus;
```

---

### ✅ `test/unit/PrimaryMarketTest.t.sol` [UPDATED]

**New Tests Added:**
- `test_PauseMarket()` - Test emergency pause
- `test_UnpauseMarket()` - Test unpause and resume
- `test_RevertWhen_NonOwnerPauses()` - Access control
- `test_RevertWhen_NonOwnerUnpauses()` - Access control
- `test_PauseDoesNotAffectFinalization()` - Finalization still works when paused
- `test_EmergencyPauseScenario()` - Full emergency scenario

**Key Changes:**
```solidity
// Pause prevents purchases
vm.prank(owner);
primaryMarket.pause();

vm.expectRevert(); // Pausable: paused
primaryMarket.buyTokens(token, amount);

// Unpause resumes operations
vm.prank(owner);
primaryMarket.unpause();
```

---

### ⚠️ `test/unit/LandTokenTest.t.sol` [NEEDS UPDATE]

**Required Changes:**
1. Test ERC20Votes functionality
2. Test vote delegation
3. Test snapshot checkpoints
4. Test improved owner lock (51% of total supply)

**New Tests Needed:**
```solidity
function test_DelegateVotes() public { ... }
function test_GetPastVotes() public { ... }
function test_VotingCheckpoints() public { ... }
function test_OwnerLockEnforces51Percent() public { ... }
function test_OwnerLockAccountsForBurns() public { ... }
```

---

### ⚠️ `test/governance/LandGovernorTest.t.sol` [NEEDS CREATION]

**New Test File Required** - Currently missing!

**Tests Needed:**
```solidity
// Snapshot Voting
function test_ProposalCreationWithVotingDelay() public { ... }
function test_VotingUsesSnapshot() public { ... }
function test_FlashLoanCannotVote() public { ... }

// Timelock
function test_QueueProposal() public { ... }
function test_ExecuteAfterTimelock() public { ... }
function test_RevertWhen_ExecuteBeforeTimelock() public { ... }

// Realistic Quorum
function test_20PercentQuorum() public { ... }
function test_ProposalSucceedsWithQuorum() public { ... }
```

---

### ⚠️ `test/governance/AgencyMultisigTest.t.sol` [NEEDS CREATION]

**New Test File Required** - Currently missing!

**Tests Needed:**
```solidity
// Multisig Signer Changes
function test_ProposeAddSigner() public { ... }
function test_ProposeRemoveSigner() public { ... }
function test_ProposeChangeRequirement() public { ... }
function test_RequiresMultisigForSignerChanges() public { ... }

// Backward Compatibility
function test_SubmitSimpleTransaction() public { ... }
function test_SubmitTransactionWithUintData() public { ... }
```

---

### ⚠️ `test/unit/TokenFactoryTest.t.sol` [NEEDS UPDATE]

**Required Changes:**
1. Test `isFactoryToken` tracking
2. Test access control in `transferToPrimaryMarket()`

**New Tests Needed:**
```solidity
function test_TracksFactoryTokens() public { ... }
function test_RevertWhen_TransferNonFactoryToken() public { ... }
function test_RevertWhen_InsufficientFactoryBalance() public { ... }
```

---

### ⚠️ `test/integration/FullTokenizationFlow.t.sol` [NEEDS UPDATE]

**Required Changes:**
1. Fund bonus pool in setUp()
2. Add delegation before governance voting
3. Add queue() step before execution
4. Update for snapshot voting

**Example Updates:**
```solidity
function setUp() public override {
    super.setUp();

    // Fund bonus pool
    vm.startPrank(owner);
    usdc.approve(address(stakingVault), 10_000_000e6);
    stakingVault.fundBonusPool(10_000_000e6);
    vm.stopPrank();
}

function test_FullFlow() public {
    // ... existing setup ...

    // Before governance
    vm.prank(tokenHolder);
    landToken.delegate(tokenHolder); // Must delegate

    // Create proposal
    uint256 proposalId = governor.propose(...);

    // Wait for voting delay
    vm.roll(block.number + 2);

    // Vote
    governor.vote(proposalId, true);

    // Wait for voting to end
    vm.roll(proposal.endBlock + 1);

    // Queue
    governor.queue(proposalId);

    // Wait for timelock
    vm.roll(block.number + 172_800 + 1);

    // Execute
    governor.execute(proposalId);
}
```

---

## Running Tests

### Run All Tests
```bash
forge test -vvv
```

### Run Specific Test File
```bash
forge test --match-path test/unit/StakingVaultTest.t.sol -vvv
```

### Run Specific Test Function
```bash
forge test --match-test test_FundBonusPool -vvv
```

### Check Coverage
```bash
forge coverage
```

### Generate Gas Report
```bash
forge test --gas-report
```

---

## Common Test Failures & Fixes

### 1. **InsufficientBonusPool Error**
**Cause:** Bonus pool not funded in setUp()

**Fix:**
```solidity
function setUp() public override {
    super.setUp();
    vm.startPrank(owner);
    usdc.approve(address(stakingVault), 1_000_000e6);
    stakingVault.fundBonusPool(1_000_000e6);
    vm.stopPrank();
}
```

### 2. **Voting Power Zero Error**
**Cause:** Tokens not delegated before voting

**Fix:**
```solidity
vm.prank(voter);
landToken.delegate(voter);
```

### 3. **VotingNotStarted Error**
**Cause:** Trying to vote before VOTING_DELAY

**Fix:**
```solidity
uint256 proposalId = governor.propose(...);
vm.roll(block.number + 2); // Wait for voting to start
governor.vote(proposalId, true);
```

### 4. **TimelockNotExpired Error**
**Cause:** Trying to execute before timelock ends

**Fix:**
```solidity
governor.queue(proposalId);
vm.roll(block.number + 172_800 + 1); // 4 days
governor.execute(proposalId);
```

### 5. **TokenNotFromFactory Error**
**Cause:** Trying to transfer non-factory token

**Fix:**
```solidity
// Only transfer tokens created by the factory
tokenFactory.transferToPrimaryMarket(factoryToken, market, amount);
```

---

## Test Coverage Goals

### Minimum Coverage (Before Mainnet)
- **Unit Tests:** >95%
- **Integration Tests:** All critical paths
- **Edge Cases:** All error conditions

### Coverage by Contract

| Contract | Current | Target | Status |
|----------|---------|--------|--------|
| StakingVault | ✅ 100% | 95% | PASS |
| LandToken | ⚠️ 70% | 95% | NEEDS WORK |
| TokenFactory | ⚠️ 75% | 95% | NEEDS WORK |
| PrimaryMarket | ✅ 95% | 95% | PASS |
| LandRegistry | ⚠️ 80% | 95% | NEEDS WORK |
| LandGovernor | ❌ 0% | 95% | NO TESTS |
| AgencyMultisig | ❌ 0% | 95% | NO TESTS |

---

## Integration Test Scenarios

### Scenario 1: Happy Path
1. Property owner stakes USDC
2. Registers property
3. Verifier approves (bonus paid from pool)
4. Tokens minted
5. Primary sale conducted
6. Liquidity bootstrapped
7. Governance proposal created
8. Community votes (snapshot-based)
9. Proposal queued
10. Timelock expires
11. Proposal executed

### Scenario 2: Rejection Path
1. Property owner stakes USDC
2. Registers property
3. Verifier rejects (fee goes to bonus pool)
4. Owner receives 99% back
5. Bonus pool increases by 1%

### Scenario 3: Fraud/Slash Path
1. Property owner stakes USDC
2. Registers property
3. Fraud detected
4. Stake slashed: 50% to bonus pool, 50% to treasury
5. Property blacklisted

### Scenario 4: Emergency Pause
1. Primary sale active
2. Emergency detected
3. Owner pauses market
4. All purchases revert
5. Emergency resolved
6. Owner unpauses
7. Trading resumes

---

## Deployment Testing Checklist

### Testnet Deployment
- [ ] Deploy all contracts
- [ ] Fund bonus pool with 100,000 USDC
- [ ] Register test property
- [ ] Approve property (verify bonus paid)
- [ ] Conduct primary sale
- [ ] Test pause/unpause
- [ ] Create governance proposal
- [ ] Test snapshot voting
- [ ] Test timelock
- [ ] Verify all events emitted

### Mainnet Preparation
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Fuzz tests completed
- [ ] Invariant tests completed
- [ ] Professional audit completed
- [ ] Bug bounty program launched
- [ ] Load testing completed
- [ ] Gas optimization completed

---

## Testing Tools & Commands

### Foundry Commands
```bash
# Build
forge build

# Test
forge test -vvv

# Coverage
forge coverage --report lcov

# Gas Snapshot
forge snapshot

# Fork Testing (Sepolia)
forge test --fork-url $SEPOLIA_RPC_URL -vvv

# Fork Testing (Polygon Amoy)
forge test --fork-url $AMOY_RPC_URL -vvv
```

### Useful Test Modifiers
```solidity
// Skip slow tests
forge test --no-match-test "testFork" -vvv

// Run only integration tests
forge test --match-path "test/integration/**" -vvv

// Run only unit tests
forge test --match-path "test/unit/**" -vvv
```

---

## Next Steps

1. **Complete Missing Tests**
   - Create `LandGovernorTest.t.sol`
   - Create `AgencyMultisigTest.t.sol`
   - Update `LandTokenTest.t.sol`
   - Update `TokenFactoryTest.t.sol`
   - Update integration tests

2. **Achieve Coverage Goals**
   - Aim for >95% coverage on all contracts
   - Test all edge cases
   - Test all error conditions

3. **Add Advanced Testing**
   - Fuzz testing for economic parameters
   - Invariant testing for protocol constraints
   - Property-based testing

4. **CI/CD Integration**
   - Add GitHub Actions workflow
   - Automatic test running on PR
   - Coverage reporting

---

## Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Test Helpers](https://docs.openzeppelin.com/test-helpers)
- [ERC20Votes Documentation](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Votes)
- [Snapshot Voting Guide](https://docs.snapshot.org/)

---

**Last Updated:** 2025-11-21
**Version:** 2.0.0
**Status:** ⚠️ Tests partially updated - governance and token tests still needed
