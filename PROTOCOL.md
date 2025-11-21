# Protocol Deep Dive

This document explains how the RWA tokenization stack operates across the entire lifecycle—covering actors, contract responsibilities, scripts, and failure scenarios. Use it as the canonical source of truth when onboarding teammates, writing audits, or integrating a frontend.

---

## Contents
1. [Actors & Responsibilities](#1-actors--responsibilities)
2. [Contract Modules](#2-contract-modules)
3. [Lifecycle Walkthrough](#3-lifecycle-walkthrough)
4. [Safety & Control Plane](#4-safety--control-plane)
5. [Deployment & Configuration](#5-deployment--configuration)
6. [Testing Matrix](#6-testing-matrix)

---

## 1. Actors & Responsibilities

| Actor | Responsibilities | On-chain touchpoints |
| --- | --- | --- |
| Property Owner | Tokenization applicant; supplies metadata, funds stake, receives owner allocation & sale proceeds | `StakingVault.depositStake`, `LandRegistry.registerProperty`, receives ERC-20 + USDC |
| Verification Agency (multisig) | Reviews documents, approves/rejects/slashes, manages emergency actions | `AgencyMultisig` → `LandRegistry.verifyProperty / slashProperty`, `LandToken.pause` |
| Protocol Treasury / Fee Recipient | Collects platform share + penalties, funds staking bonuses | `TokenFactory` fee mint, `StakingVault` fees/slashes |
| Investors | Buy tokens in the primary sale or secondary markets, vote in `LandGovernor` | `PrimaryMarket.buyTokens`, DEX swaps, governance voting |
| Governance Participants | Create/vote on proposals affecting the property | `LandGovernor.propose/vote/execute` |

---

## 2. Contract Modules

### Core
- **`LandRegistry.sol`** – Master state machine controlling property metadata, status transitions, and statistics.
- **`StakingVault.sol`** – USDC escrow with bonus/refund/slash logic; only callable by the registry.
- **`TokenFactory.sol`** – Deterministic `LandToken` deployer with supply math, fee minting, and transfer exemptions.
- **`LandToken.sol`** – ERC-20 with owner lock, verification lock, metadata getters, and pausable transfers.

### Trading Stack
- **`PrimaryMarket.sol`** – Fixed-price sale with whale caps, 72 h window, and unsold-token burn.
- **`LiquidityBootstrap.sol`** – Creates/locks Uniswap V2 pools; enforces 180-day LP custody.
- **`PriceOracle.sol`** – Stores manual and Chainlink-fed prices, compares with DEX reserves, and exposes divergence metrics.

### Governance & Access Control
- **`AgencyMultisig.sol`** – Lightweight multisig that gates registry actions (verify, reject, slash, pause, verifier rotation).
- **`LandGovernor.sol`** – Per-token DAO contract requiring 1 % proposal threshold and 75 % quorum.

### Shared Libraries
- **`LandLib.sol`** – Structs (`PropertyMetadata`, `TokenAllocation`), enums, ID + allocation math.
- **`ValidationLib.sol`** – Common require wrappers (non-zero amounts, address checks, strings, IPFS).
- **`MathLib.sol`** – Slippage helpers, decimal scaling, divergence math.

---

## 3. Lifecycle Walkthrough

1. **Stake & Register**
   - Owner stakes at least 5 % of valuation via `StakingVault.depositStake`.
   - Calls `LandRegistry.registerProperty(metadata, stakeAmount)` which:
     - Validates metadata (survey no., coordinates, IPFS hash, valuation).
     - Generates `propertyId = keccak256(survey, lat, lon, timestamp)`.
     - Stores `PropertyData` in the `Pending` state and tracks ownership statistics.

2. **Verification Decision**
   - Agency multisig prepares a transaction (`TransactionType.VerifyProperty`, `RejectProperty`, or `SlashProperty`).
   - Once the threshold signatures confirm, the multisig executes:
     - **Approve:** Registry marks `Verified`, calls `TokenFactory.createLandToken`, releases the stake with a +2 % bonus, and activates trading.
     - **Reject:** Registry marks `Rejected`, refunds stake −1 % fee.
     - **Slash:** Registry marks `Slashed`, blacklists the property, and sends the entire stake to treasury.

3. **Token Deployment**
   - `TokenFactory` (only callable by the registry) deploys `LandToken` using CREATE2, initializes metadata, mints owner/fee/sale allocations, and transfers token ownership back to the registry.
   - `LandToken` status starts at `Pending`; registry switches it to `Verified` and then `Trading` via `activateTrading`.
   - Owner allocation is locked for 180 days (enforced in `_update`), and only lock-exempt addresses (factory, contracts) can bypass early-transfer rules.

4. **Primary Sale**
   - Treasury (or another coordinator) calls `PrimaryMarket.startSale` with the public allocation, price, and owner beneficiary.
   - Buyers call `buyTokens` (subject to cap/minimum) and transfer USDC directly to the contract, receiving tokens instantly.
   - After the window or sellout, `finalizeSale` burns unsold tokens and forwards USDC to the property owner.

5. **Liquidity Bootstrap**
   - Coordinator invokes `LiquidityBootstrap.bootstrapLiquidity`, supplying both land tokens and USDC.
   - The contract creates (or fetches) the Uniswap pair, adds liquidity with a 5 % slippage margin, and holds the LP tokens for 180 days.
   - Optional: after the lock, `removeLiquidity` returns proceeds to the coordinator/treasury.

6. **Secondary Market & Governance**
   - Tokens now trade freely; owners can only sell down to their `ownerAllocation` threshold until the 6‑month lock expires.
   - `PriceOracle` can be updated manually (`updatePrice`) or via Chainlink feeds (`setChainlinkFeed` + `getChainlinkPrice`).
   - Holders spin up `LandGovernor` instances (one per property token) to run proposals that coordinate off-chain legal actions or rental distributions. Execution emits events for off-chain services to act on.

---

## 4. Safety & Control Plane

- **Multi-sig verification:** All state transitions after registration require `AgencyMultisig`. Even registry owner actions (add/remove verifiers) are usually proxied through multisig proposals.
- **Stake-backed honesty:** Owners risk 5 % of valuation (plus opportunity cost) and cannot rage-quit instantly due to the 72 h + 7 d withdrawal rule.
- **Owner transfer lock:** Prevents immediate dumping of the 51 % allocation; enforced at the ERC-20 transfer hook level.
- **Whale cap + min purchase:** Mitigates price manipulation during the fixed-price sale.
- **LP lock:** Removes liquidity rug risk for 6 months while the market matures.
- **Oracle circuit breaker:** Manual price updates are throttled to ±50 % per day; Chainlink feeds must be fresh (<1 hour) or the call reverts.
- **Emergency levers:** 
  - `LandToken.pause/unpause` can be triggered via multisig to freeze transfers.
  - `LiquidityBootstrap.removeLiquidity` requires the lock to expire.
  - `StakingVault.emergencyWithdraw` allows owners to reclaim stakes if verifiers stall.

---

## 5. Deployment & Configuration

- **Helper Config (`script/HelperConfig.s.sol`):** Auto-selects network-specific constants (USDC, WMATIC, router/factory addresses) and deploys mocks on Anvil.
- **Deploy Script (`script/DeployCore.s.sol`):** Boots the entire stack (registry, vault, factory, market, bootstrap, oracle) and wires dependencies (`setStakingVault`, `setTokenFactory`, `addVerifier`).
- **Interactions (`script/Interactions.s.sol`):** Provides scripted flows for registering, verifying, buying tokens, and creating pools—useful both for integration tests and demo CLIs.
- **Makefile:** Wraps Forge commands with `deploy-*`, `verify-*`, and `register/verify/buy/create-pool` shortcuts.

All critical addresses are emitted via `console.log` during deployment; persist them in your frontend or monitoring stack.

---

## 6. Testing Matrix

| Test Suite | Coverage |
| --- | --- |
| `test/unit/*.t.sol` | Contract-specific invariants (vault math, token locks, factory allocation) |
| `test/integration/*.t.sol` | Full workflows: stake → register → verify → sale → liquidity → trading |
| `test/utils/` | Shared mocks and helpers |
| `test/fork/` (when enabled) | Uniswap + Chainlink behavior on Sepolia/Polygon forked states |

Key scenarios to pay attention to:
- Double registration or re-using metadata (guarded by `PropertyAlreadyExists`).
- Slashing and blacklist propagation (blacklisted properties cannot re-register).
- Token transfer hooks preventing owners from breaching the 51 % minimum during lock.
- Liquidity removal attempts before the 180-day timer.
- Oracle divergence calculations when pool reserves are zero or stale.

Run `make test`, `make test-unit`, `make test-integration`, and the fork-specific targets before shipping any protocol modifications.

