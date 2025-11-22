# RWA Tokenization Platform - Frontend (ThirdWeb SDK)

A production-ready Next.js frontend for Real-World Asset (RWA) tokenization, built with Thirdweb SDK v5 for seamless Web3 integration.

## 🚀 Features

- ✅ **Property Registration** - Full contract integration for registering properties with USDC staking
- 🔐 **ThirdWeb Connect** - Seamless wallet connection (MetaMask, Coinbase, WalletConnect, etc.)
- 📝 **Smart Contract Integration** - Direct interaction with deployed Sepolia contracts
- 💰 **USDC Approval Flow** - Two-step process: approve then register
- 📊 **Real-time Status** - Transaction status and error handling
- 🎨 **Responsive UI** - Mobile-first design with Tailwind CSS
- ⚡ **TypeScript** - Full type safety

## 🛠️ Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Language:** TypeScript
- **Web3:** ThirdWeb SDK v5
- **Styling:** Tailwind CSS
- **State:** TanStack Query
- **Icons:** Lucide React

## 📋 Prerequisites

- Node.js >= 18
- npm or yarn
- MetaMask or any Web3 wallet
- Sepolia testnet ETH and USDC

## 🔧 Installation

```bash
# Navigate to frontend directory
cd frontend

# Install dependencies
npm install

# Copy environment file
cp .env.example .env.local
```

## ⚙️ Configuration

The `.env.local` file has been pre-configured with:

```env
# ThirdWeb Configuration
NEXT_PUBLIC_THIRDWEB_CLIENT_ID=f46d5dd29518127f58746a2e5f723fb3

# Network
NEXT_PUBLIC_CHAIN_ID=11155111
NEXT_PUBLIC_NETWORK=sepolia

# Deployed Contract Addresses (Sepolia)
NEXT_PUBLIC_LAND_REGISTRY=0x047E7788D9469B2b3C10444a10aFD51942112cb4
NEXT_PUBLIC_STAKING_VAULT=0xB5bCC146E4Dd15637C3F09b29a63575a24c39291
NEXT_PUBLIC_TOKEN_FACTORY=0xEcC27d676029251C4819F499e6D812481bEaF6fd
NEXT_PUBLIC_PRIMARY_MARKET=0x2c074aE9dB59e853bcdf013DF9Bd9C93aEaa9078
NEXT_PUBLIC_LIQUIDITY_BOOTSTRAP=0xb99Ef9A146e41DD10dbb8a2d44621e5757Dbf026
NEXT_PUBLIC_PRICE_ORACLE=0x8bC9cE6A3376b41Cd0bEb1741ea54a11aF90e040
NEXT_PUBLIC_AGENCY_MULTISIG=0x6c336a00404Cd90cEe6a392B136eb0b9643fab2a
NEXT_PUBLIC_USDC=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
```

## 🚀 Running the App

```bash
# Development server
npm run dev

# Build for production
npm run build

# Start production server
npm run start
```

Open [http://localhost:3000](http://localhost:3000) to view the app.

## 📖 Usage Guide

### 1. Connect Wallet
- Click "Connect" in the top-right corner
- Choose your preferred wallet
- Approve the connection
- Ensure you're on Sepolia testnet

### 2. Get Test Tokens
- Get Sepolia ETH from [Sepolia Faucet](https://sepoliafaucet.com/)
- Get test USDC from the deployed USDC contract

### 3. Register a Property

**Step 1: Fill out the form**
- Property Location (e.g., "123 Main St, New York, NY")
- Valuation in USDC (e.g., 1000000)
- Area in square meters (e.g., 1000)
- Owner Name
- Coordinates (Lat, Long)
- Legal Description

**Step 2: Approve USDC**
- Click "1. Approve USDC"
- Approve the stake amount (5% of valuation)
- Wait for confirmation

**Step 3: Register**
- Click "2. Register Property"
- Confirm the transaction
- Wait for blockchain confirmation
- Your property is now pending verification!

### 4. Property Lifecycle

```
Register → Pending → Verification → Tokenization → Trading
```

1. **Register**: Submit property + stake 5% USDC
2. **Pending**: Awaiting multisig verification (1-7 days)
3. **Verified**: Agency approves, stake returned + 2% bonus
4. **Tokenized**: ERC-20 tokens minted
5. **Trading**: Primary sale (72h) then DEX listing

## 📁 Project Structure

```
frontend/
├── src/
│   ├── app/                      # Next.js App Router
│   │   ├── page.tsx             # Homepage
│   │   ├── register/            # Property registration ✅
│   │   ├── marketplace/         # Browse properties
│   │   ├── portfolio/           # User holdings
│   │   ├── governance/          # DAO voting
│   │   ├── analytics/           # Platform stats
│   │   ├── layout.tsx           # Root layout
│   │   ├── providers.tsx        # ThirdWeb provider
│   │   └── globals.css          # Global styles
│   ├── components/
│   │   ├── Navbar.tsx          # Navigation + Connect button
│   │   └── Footer.tsx          # Footer component
│   ├── contracts/
│   │   └── abis/               # Contract ABIs
│   ├── hooks/
│   │   ├── useContracts.ts     # Contract instances
│   │   ├── usePropertyData.ts  # Property queries
│   │   ├── useSaleData.ts      # Sale queries
│   │   └── useTokenBalance.ts  # Token balances
│   ├── lib/
│   │   ├── config.ts           # Contract addresses & constants
│   │   ├── thirdweb.ts         # ThirdWeb client
│   │   └── contracts.ts        # Legacy (to be removed)
│   ├── types/
│   │   └── contracts.ts        # TypeScript types
│   └── utils/
│       ├── cn.ts               # Class name utils
│       └── format.ts           # Formatting helpers
├── public/                      # Static assets
├── .env.local                  # Environment variables (configured)
├── .env.example               # Template
├── package.json               # Dependencies
├── tailwind.config.js         # Tailwind config
├── tsconfig.json              # TypeScript config
└── README.md                  # This file
```

## ✅ Implemented Features

### Property Registration (✅ FULLY FUNCTIONAL)
- Form validation
- USDC approval workflow
- Smart contract interaction
- Transaction status tracking
- Error handling
- Success/failure notifications
- Automatic form reset

### Wallet Connection (✅ FULLY FUNCTIONAL)
- ThirdWeb Connect Button
- Multiple wallet support
- Network detection
- Account management

### Configuration (✅ COMPLETE)
- All contract addresses configured
- Sepolia network setup
- ThirdWeb client ID
- Environment variables

## 🔜 To Be Implemented

- **Marketplace** - Browse and invest in properties
- **Portfolio** - Track your investments
- **Governance** - Vote on proposals
- **Analytics** - Platform statistics
- **Token Purchase** - Buy tokens in primary sale

## 🔗 Contract Addresses (Sepolia)

All contracts are deployed and verified on Sepolia:

- **LandRegistry**: `0x047E7788D9469B2b3C10444a10aFD51942112cb4`
- **Staking Vault**: `0xB5bCC146E4Dd15637C3F09b29a63575a24c39291`
- **Token Factory**: `0xEcC27d676029251C4819F499e6D812481bEaF6fd`
- **Primary Market**: `0x2c074aE9dB59e853bcdf013DF9Bd9C93aEaa9078`
- **Liquidity Bootstrap**: `0xb99Ef9A146e41DD10dbb8a2d44621e5757Dbf026`
- **Price Oracle**: `0x8bC9cE6A3376b41Cd0bEb1741ea54a11aF90e040`
- **Agency Multisig**: `0x6c336a00404Cd90cEe6a392B136eb0b9643fab2a`
- **USDC**: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`

View on [Sepolia Etherscan](https://sepolia.etherscan.io)

## 🐛 Troubleshooting

### Wallet Won't Connect
- Ensure you're on Sepolia network
- Clear browser cache
- Try a different wallet

### Transaction Fails
- Check you have enough Sepolia ETH for gas
- Verify USDC approval completed
- Ensure all form fields are valid
- Check you haven't already registered the same property

### Build Errors
```bash
# Clear cache and rebuild
rm -rf .next node_modules
npm install
npm run dev
```

## 📚 Resources

- [ThirdWeb Docs](https://portal.thirdweb.com/)
- [Next.js Docs](https://nextjs.org/docs)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Sepolia Faucet](https://sepoliafaucet.com/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

MIT License - See parent project

## 🎯 Next Steps

1. **Get Sepolia ETH** from faucet
2. **Get test USDC** from the contract
3. **Connect your wallet** to the app
4. **Register a property** and test the flow!

---

**Built with ❤️ using ThirdWeb SDK v5**
