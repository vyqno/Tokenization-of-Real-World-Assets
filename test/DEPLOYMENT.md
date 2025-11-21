# LandToken Protocol - Deployment Guide

Complete deployment guide for the LandToken Protocol smart contracts.

## 📋 Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Node.js v16+ (for ThirdWeb SDK integration)
- Git
- A wallet with testnet/mainnet funds

## 🔧 Setup

### 1. Clone and Install

```bash
git clone <your-repo-url>
cd frontend-rwa
make install
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and fill in:
- `PRIVATE_KEY`: Your deployment wallet private key
- `SEPOLIA_RPC_URL`: Alchemy/Infura Sepolia endpoint
- `AMOY_RPC_URL`: Alchemy Polygon Amoy endpoint
- `ETHERSCAN_API_KEY`: For contract verification
- `POLYGONSCAN_API_KEY`: For contract verification

## 🚀 Deployment

### Deploy to Sepolia

```bash
make deploy-sepolia
```

### Deploy to Polygon Amoy

```bash
make deploy-amoy
```

### Deploy to Polygon Mainnet

```bash
make deploy-polygon
```

### Deploy Locally (Anvil)

```bash
# Terminal 1: Start Anvil
make anvil

# Terminal 2: Deploy
make deploy-local
```

## 📝 Post-Deployment

After deployment, contracts are saved to `deployments/<network>.json`:

```json
{
  "chainId": 80002,
  "network": "amoy",
  "deployer": "0x...",
  "contracts": {
    "LandRegistry": "0x...",
    "StakingVault": "0x...",
    "TokenFactory": "0x...",
    "PrimaryMarket": "0x...",
    "LiquidityBootstrap": "0x...",
    "PriceOracle": "0x...",
    "AgencyMultisig": "0x..."
  }
}
```

Update your `.env` file with deployed addresses.

## 🧪 Testing the Deployment

### 1. Register a Property

```bash
# Update .env with USDC token address
export USDC_TOKEN=<usdc_address>

# Run registration
forge script script/Interactions.s.sol:RegisterProperty --rpc-url sepolia --broadcast
```

### 2. Verify Property

```bash
# Set property ID from previous step
export PROPERTY_ID=0x...

# Verify (as verifier)
forge script script/Interactions.s.sol:VerifyProperty --rpc-url sepolia --broadcast
```

### 3. Start Primary Sale

```bash
# Set land token address (from verification output)
export LAND_TOKEN=0x...

forge script script/Interactions.s.sol:StartPrimarySale --rpc-url sepolia --broadcast
```

### 4. Buy Tokens

```bash
export TOKEN_AMOUNT=1000000000000000000  # 1 token (18 decimals)

forge script script/Interactions.s.sol:BuyTokens --rpc-url sepolia --broadcast
```

### 5. Bootstrap Liquidity

```bash
export TOKEN_AMOUNT=10000000000000000000  # 10 tokens
export USDC_AMOUNT=100000000  # 100 USDC (6 decimals)

forge script script/Interactions.s.sol:BootstrapLiquidity --rpc-url sepolia --broadcast
```

## 🔍 Contract Verification

### Auto-Verification (during deployment)

Contracts are automatically verified if you provide API keys in `.env`.

### Manual Verification

```bash
# Sepolia
make verify-sepolia CONTRACT_ADDRESS=0x... CONTRACT_NAME=LandRegistry

# Amoy
make verify-amoy CONTRACT_ADDRESS=0x... CONTRACT_NAME=LandRegistry
```

## 📊 Monitoring

### View Property Info

```bash
forge script script/Interactions.s.sol:GetPropertyInfo --rpc-url sepolia
```

### View Token Info

```bash
forge script script/Interactions.s.sol:GetTokenInfo --rpc-url sepolia
```

## 🏗️ Architecture

```
LandToken Protocol
│
├── Core Contracts
│   ├── LandRegistry (Central property database)
│   ├── StakingVault (USDC escrow)
│   ├── TokenFactory (ERC20 token deployment)
│   └── LandToken (Individual property tokens)
│
├── Trading Contracts
│   ├── PrimaryMarket (Initial token sale)
│   ├── LiquidityBootstrap (DEX pool creation)
│   └── PriceOracle (Price tracking with Chainlink)
│
└── Governance Contracts
    ├── LandGovernor (Per-property DAO)
    └── AgencyMultisig (Verification control)
```

## 🌐 Supported Networks

| Network | Chain ID | DEX | Status |
|---------|----------|-----|--------|
| Sepolia | 11155111 | Uniswap V2 | ✅ Ready |
| Polygon Amoy | 80002 | QuickSwap | ✅ Ready |
| Polygon Mainnet | 137 | QuickSwap | ✅ Ready |
| Anvil (Local) | 31337 | Mock | ✅ Ready |

## 💡 Integration with ThirdWeb SDK

After deployment, integrate with your frontend:

```typescript
import { useContract, useContractRead } from "@thirdweb-dev/react";

// Connect to LandRegistry
const { contract } = useContract("LAND_REGISTRY_ADDRESS");

// Read property data
const { data: propertyData } = useContractRead(
  contract,
  "getPropertyData",
  [propertyId]
);
```

## 🔐 Security Notes

- Never commit `.env` file
- Keep private keys secure
- Test thoroughly on testnets before mainnet
- Use multi-sig for production deployments
- Enable contract verification for transparency

## 📚 Additional Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Uniswap V2 Docs](https://docs.uniswap.org/contracts/v2/overview)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds)
- [ThirdWeb SDK](https://portal.thirdweb.com/)

## 🆘 Troubleshooting

### "Insufficient funds" error
- Ensure your wallet has enough ETH/MATIC for gas
- Get testnet tokens from faucets

### "Transaction reverted" error
- Check contract state (is property already registered?)
- Verify USDC allowances
- Ensure minimum stake is met (5% of valuation)

### Verification fails
- Double-check API keys in `.env`
- Ensure network configuration is correct
- Try manual verification with constructor args

## 📞 Support

For issues or questions:
- Open an issue on GitHub
- Check the main README.md
- Review contract documentation in `/src`
