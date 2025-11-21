# Real-World Asset (RWA) Tokenization Protocol

> Tokenize physical land into ERC-20s, run a capped primary sale, seed DEX liquidity, and govern the asset through staking-backed verification.

---

## Contents
- [Protocol Summary](#protocol-summary)
- [Contract Surface](#contract-surface)
- [Tokenomics Snapshot](#tokenomics-snapshot)
- [Local Development](#local-development)
- [Environment Configuration](#environment-configuration)
- [Testing & Quality](#testing--quality)
- [Deployment & Operations](#deployment--operations)
- [Further Reading](#further-reading)

---

## Protocol Summary

### Lifecycle at a Glance
1. **Stake + Register** – Owners lock 5 % of the property valuation in `StakingVault` and submit metadata via `LandRegistry.registerProperty`.
2. **Multisig Verification** – `AgencyMultisig` (or any registry-approved verifier) calls `verifyProperty`. Approval releases the stake with a 2 % bonus; rejection refunds minus a 1 % fee; fraud is slashed to the treasury.
3. **Token Minting** – `TokenFactory` deterministically deploys a dedicated `LandToken` (`ERC20`, mint/burn, pausable) with 51 % reserved/locked for the owner, 2.5 % platform fee, and the remainder earmarked for the public sale.
4. **Primary Sale** – `PrimaryMarket` sells the public allocation at a fixed price (10 USDC per token) with a 10 % per-buyer cap and 1-token minimum.
5. **Liquidity Bootstrap** – Once the sale finalizes, `LiquidityBootstrap` adds a USDC pair on any Uniswap V2-compatible DEX, locking LP tokens for 180 days.
6. **Secondary Markets + Governance** – Land tokens trade freely (owner lock lasts 180 days), on-chain prices feed into `PriceOracle`, and property-specific DAOs run through `LandGovernor`.

### Actors
- **Property Owner** – stakes funds, supplies metadata, receives 51 % of tokens (subject to a 6‑month lock).
- **Verification Agency** – multisig that approves, rejects, or slashes properties and manages emergency actions.
- **Investors** – purchase tokens in the primary sale (max 10 % each) and on DEXs post-liquidity.
- **Treasury / Protocol** – receives the 2.5 % platform fee plus any slashed stakes or rejection fees.
- **Governance Tokenholders** – participate in per-property proposals (sell, change management, distribute income, etc.).

For the end-to-end walkthrough—including revert paths and safety rails—see `PROTOCOL.md`.

---

## Contract Surface

| Area | Contracts | Highlights |
| --- | --- | --- |
| Core | `LandRegistry`, `StakingVault`, `TokenFactory`, `LandToken` | Registration, staking escrow, deterministic ERC-20 factories, transfer locks |
| Trading | `PrimaryMarket`, `LiquidityBootstrap`, `PriceOracle` | Fixed-price sale with whale cap, Uniswap V2 pool creation, oracle + DEX divergence tracking |
| Governance | `LandGovernor`, `AgencyMultisig` | Property-specific DAOs, multi-sig verification + emergency controls |
| Libraries & Interfaces | `LandLib`, `ValidationLib`, `MathLib`, `interfaces/*` | Shared structs/enums, validation helpers, math utilities, standard interfaces |
| Tooling | `script/*.s.sol`, `test/*`, `Makefile` | Foundry deployment scripts, full flow tests, reproducible ops targets |

All Solidity is written for `pragma ^0.8.20` with OpenZeppelin v5, Chainlink feeds, and Uniswap V2 interfaces vendored under `lib/`.

---

## Tokenomics Snapshot

- **Token price:** `TOKEN_PRICE = 10e6` (10 USDC with 6 decimals) → total supply = `valuation / 10 USDC`, expressed with 18 decimals.
- **Supply split:** 51 % owner (subject to 180‑day lock + minimum balance), 46.5 % public sale, 2.5 % platform fee.
- **Primary sale rules:** 72‑hour window, `MIN_PURCHASE = 1e18`, max 10 % per wallet, unsold tokens are burned.
- **Stake economics:** Minimum stake = 5 % of valuation, +2 % bonus on approval, −1 % penalty on rejection, 100 % slash to treasury for fraud, emergency withdrawal after 72 h + 7 days.
- **Liquidity:** LP tokens locked for 180 days; 5 % slippage tolerance when adding liquidity.
- **Oracle guardrails:** Manual/Chainlink updates limited to ±50 % per day, stale data rejected after 30 days (manual) or 1 hour (Chainlink).

See `TOKENOMICS.md` for worked examples and cashflow diagrams.

---

## Local Development

### Requirements
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)
- Node.js ≥ 18 (for optional frontend tooling)
- Git, Make, and a recent `solc` (bundled via Foundry)

### Bootstrap
```bash
git clone <repo>
cd frontend-rwa
forge install          # or `make install`
cp .env.example .env   # fill in RPC keys, treasury, etc.
forge build            # or `make build`
forge test             # or `make test`
```

Run `npm install` if you plan to pair these contracts with the optional Next.js frontend.

---

## Environment Configuration

Populate `.env` (or export vars inline) before running scripts/tests. Key values:

| Variable | Why it matters |
| --- | --- |
| `RPC_URL`, `SEPOLIA_RPC_URL`, `AMOY_RPC_URL` | Network endpoints for deployments/fork tests |
| `PRIVATE_KEY`, `ANVIL_KEY` | Broadcaster key for Forge scripts |
| `USDC_ADDRESS`, `WMATIC_ADDRESS` | Stablecoin + wrapped native tokens used across staking and liquidity |
| `UNISWAP_ROUTER`, `UNISWAP_FACTORY` | V2 router/factory addresses per chain |
| `TREASURY`, `FEE_RECIPIENT`, `VERIFIER` | Treasury for fees/slashes, platform fee recipient, multisig/verifier actor |
| `ETHERSCAN_API_KEY`, `POLYGONSCAN_API_KEY` | Optional verification helpers |

`script/HelperConfig.s.sol` chooses sensible defaults per chain and deploys mocks for local Anvil environments.

---

## Testing & Quality

- `make test` – run the full Foundry suite (`test/unit`, `test/integration`, `test/utils`).
- `make test-unit` / `make test-integration` – focused passes.
- `make test-fork-sepolia` / `make test-fork-amoy` – exercise flows against live liquidity + Chainlink feeds.
- `make gas-report`, `make coverage`, `make snapshot` – profiling helpers.
- `forge doc` – generate NatSpec HTML docs (served from `out/docs`).

Tests live under `test/` and cover escrow flows, fraud scenarios, full tokenization (registration → trading), and Uniswap integration.

---

## Deployment & Operations

| Action | Command | Notes |
| --- | --- | --- |
| Deploy full stack | `make deploy-sepolia` / `deploy-amoy` / `deploy-polygon` | Runs `script/DeployCore.s.sol` with broadcast + verification flags |
| Local deployment | `make deploy-local` | Targets an Anvil node (see `make anvil`) |
| Contract verification | `make verify-<chain>` | Wraps `forge verify-contract` |
| Register / verify / trade | `make register-property`, `make verify-property`, `make buy-tokens`, `make create-pool` | Execute scripted interactions end-to-end |
| Liquidity lifecycle | `LiquidityBootstrap.bootstrapLiquidity` + `removeLiquidity` | Adds/withdraws USDC pairs, enforcing a 180-day lock |

All deployments log component addresses (registry, vault, factory, markets, oracle) to STDOUT for easy ingestion by frontends or monitoring.

---

## Further Reading

- `PROTOCOL.md` – detailed lifecycle, actor responsibilities, and safety rails.
- `TOKENOMICS.md` – supply math, staking game theory, treasury flows, and numerical examples.

Questions or contributions? Open an issue, submit a PR (use Conventional Commits), or reach out to the maintainers. Happy tokenizing! 🚜
