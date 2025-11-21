# Tokenomics & Economic Controls

> All parameters referenced below map directly to on-chain constants inside `LandLib`, `TokenFactory`, `LandToken`, `PrimaryMarket`, `StakingVault`, and `LiquidityBootstrap`.

---

## Contents
1. [Supply Calculation](#1-supply-calculation)
2. [Allocation Breakdown](#2-allocation-breakdown)
3. [Primary Market Rules](#3-primary-market-rules)
4. [Staking, Slashing, and Fees](#4-staking-slashing-and-fees)
5. [Liquidity & Pricing](#5-liquidity--pricing)
6. [Cashflow Summary](#6-cashflow-summary)

---

## 1. Supply Calculation

`TokenFactory` turns a verified property valuation (`metadata.valuation`, denominated in the staking token—USDC by default) into an 18-decimal ERC-20 supply using the constant token price:

```
TOKEN_PRICE = 10e6   // 10 USDC (6 decimals)
totalSupply = (valuation / TOKEN_PRICE) * 1e18
```

**Example**
- Property valuation: 6,900,000 USDC (≈₹69 Lakhs with 6 decimals)
- Supply: `(6,900,000e6 / 10e6) * 1e18 = 690,000 * 1e18`

This deterministic math ensures every property token starts at the same book value, simplifying audits and DCF models.

---

## 2. Allocation Breakdown

Once `totalSupply` is known, `LandLib.calculateTokenAllocation` fixes the split:

| Bucket | % of supply | Recipient / Rule | On-chain source |
| --- | --- | --- | --- |
| Owner reserve | **51 %** | Minted to `originalOwner`, must remain above `ownerAllocation` until `OWNER_LOCK_PERIOD = 180 days` expires | `LandToken.ownerAllocation` |
| Public sale | **46.5 %** | Minted to `TokenFactory`, streamed into `PrimaryMarket` for distribution | `LandLib.TokenAllocation.publicSale` |
| Platform fee | **2.5 %** | Minted to `feeRecipient` (protocol treasury) | `TokenFactory.PLATFORM_FEE_PERCENTAGE` |

Any unsold public allocation is burned (`PrimaryMarket.finalizeSale`), so supply never exceeds the initial mint.

---

## 3. Primary Market Rules

`PrimaryMarket` enforces the following guardrails to keep the initial distribution decentralized:

- **Price:** Fixed at `pricePerToken` (default: 10 USDC) for the entire sale window.
- **Duration:** `SALE_DURATION = 72 hours`; before that, purchases settle instantly; after, only finalization is allowed.
- **Per-buyer cap:** `MAX_PURCHASE_PERCENTAGE = 10` → no wallet can accumulate >10 % of the sale allocation.
- **Minimum ticket:** `MIN_PURCHASE = 1e18` (1 token) to block dust spam.
- **Funds flow:** Payments are escrowed in USDC and released to the property owner upon successful finalization.
- **Unsold tokens:** Burned using `LandToken.burn` to maintain price integrity.

---

## 4. Staking, Slashing, and Fees

Before a property is even considered for tokenization, the owner must stake USDC inside `StakingVault`:

| Parameter | Value | Behavior |
| --- | --- | --- |
| Minimum stake | **5 %** of valuation | Enforced by `LandRegistry.registerProperty` via `LandLib.calculateMinStake` |
| Bonus on approval | **+2 %** | `releaseStake(..., approved=true)` pays back the stake plus the bonus, funded by treasury revenues |
| Fee on rejection | **−1 %** | Keeps reviewers honest while refunding most capital |
| Fraud slash | **100 %** | `slashStake` sends the entire stake to treasury and blacklists the property |
| Lock timer | 72 h verification window + 7 days | Owners can self-withdraw only after this grace period via `emergencyWithdraw` |

These numbers ensure verifiers are sufficiently compensated to catch fraud while owners have meaningful collateral at risk.

---

## 5. Liquidity & Pricing

After the primary sale, the protocol guarantees tradability through `LiquidityBootstrap`:

- **Pair:** Land token vs USDC on any Uniswap V2 router/factory combo provided in config (`HelperConfig` sets QuickSwap on Polygon, Uniswap on Sepolia, mocks on Anvil).
- **Slippage guard:** 5 % tolerance in both directions via `MathLib.applySlippage`.
- **LP lock:** `LOCKUP_PERIOD = 180 days`; LP tokens stay in the contract to keep markets liquid and to prevent rug pulls.
- **Oracle inputs:** `PriceOracle` tracks manual and Chainlink-fed USD valuations, compares them with actual pool reserves (`getDexPrice`), and limits daily adjustments to ±50 %.

---

## 6. Cashflow Summary

| Actor | Inflows | Outflows | Notes |
| --- | --- | --- | --- |
| Property owner | 51 % token allocation, primary sale proceeds | 5 % valuation stake, platform fee share (implicit) | Owner tokens are unlockable only after 180 days and must always exceed `ownerAllocation` until then |
| Investors | Tradable land tokens | 10 USDC per token (primary) or market price (DEX) | Protected against whales by per-wallet caps and slippage-controlled pools |
| Protocol treasury / fee recipient | 2.5 % platform supply, 1 % rejection fee, slashed stakes | Pays 2 % approval bonus, funds ops/audits | Treasury addresses are configurable via `TokenFactory.setFeeRecipient` and `StakingVault.setTreasury` |
| Verification agency | Reputation, potential service fees (off-chain) | Multisig gas costs | Backed by `AgencyMultisig` so no single signer can corrupt the process |

Together, these controls make the LandToken model predictable for auditors while still leaving room for frontend UX, legal wrappers, or revenue-sharing extensions on top.

