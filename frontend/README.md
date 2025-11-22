# RWA Tokenization Platform - Frontend

A modern Next.js frontend for the Real-World Asset (RWA) tokenization protocol, enabling users to tokenize physical land into ERC-20 tokens with staking-backed verification and decentralized governance.

## Features

- 🏗️ **Property Registration** - Register properties for tokenization with USDC staking
- 🛒 **Marketplace** - Browse and invest in tokenized properties
- 💼 **Portfolio Management** - Track your property investments and holdings
- 🗳️ **Governance** - Participate in property-specific DAO voting
- 📊 **Analytics** - Real-time platform statistics and insights
- 🔐 **Web3 Integration** - Connect with MetaMask, WalletConnect, and other wallets
- ⚡ **Responsive Design** - Mobile-first responsive UI with Tailwind CSS

## Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS
- **Web3:** Wagmi, Viem, RainbowKit
- **State Management:** TanStack Query
- **Icons:** Lucide React
- **Charts:** Recharts (for analytics)

## Getting Started

### Prerequisites

- Node.js >= 18
- npm or yarn
- MetaMask or any Web3 wallet

### Installation

1. Navigate to the frontend directory:
```bash
cd frontend
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file based on `.env.example`:
```bash
cp .env.example .env
```

4. Configure environment variables:
```env
NEXT_PUBLIC_CHAIN_ID=11155111  # Sepolia testnet
NEXT_PUBLIC_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

# Contract addresses (deploy contracts first)
NEXT_PUBLIC_LAND_REGISTRY_ADDRESS=0x...
NEXT_PUBLIC_STAKING_VAULT_ADDRESS=0x...
NEXT_PUBLIC_TOKEN_FACTORY_ADDRESS=0x...
NEXT_PUBLIC_PRIMARY_MARKET_ADDRESS=0x...
NEXT_PUBLIC_LIQUIDITY_BOOTSTRAP_ADDRESS=0x...
NEXT_PUBLIC_PRICE_ORACLE_ADDRESS=0x...
NEXT_PUBLIC_LAND_GOVERNOR_ADDRESS=0x...
NEXT_PUBLIC_AGENCY_MULTISIG_ADDRESS=0x...
NEXT_PUBLIC_USDC_ADDRESS=0x...

# WalletConnect Project ID
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id
```

5. Run the development server:
```bash
npm run dev
```

6. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Project Structure

```
frontend/
├── src/
│   ├── app/                    # Next.js app router pages
│   │   ├── page.tsx           # Homepage
│   │   ├── register/          # Property registration
│   │   ├── marketplace/       # Property marketplace
│   │   ├── portfolio/         # User portfolio
│   │   ├── governance/        # Governance/voting
│   │   └── analytics/         # Platform analytics
│   ├── components/            # Reusable components
│   │   ├── Navbar.tsx
│   │   └── Footer.tsx
│   ├── contracts/            # Contract ABIs
│   │   └── abis/
│   ├── hooks/                # Custom React hooks
│   ├── lib/                  # Libraries and configurations
│   │   ├── wagmi.ts         # Wagmi configuration
│   │   └── contracts.ts     # Contract addresses
│   ├── types/               # TypeScript types
│   └── utils/               # Utility functions
├── public/                  # Static assets
├── .env.example            # Environment variables template
├── next.config.js          # Next.js configuration
├── tailwind.config.js      # Tailwind CSS configuration
└── tsconfig.json           # TypeScript configuration
```

## Pages

### Homepage (`/`)
- Platform overview and statistics
- Hero section with CTAs
- Feature highlights
- Benefits section

### Register Property (`/register`)
- Property registration form
- USDC stake approval
- Property metadata submission
- Real-time validation

### Marketplace (`/marketplace`)
- Browse all tokenized properties
- Filter by status (active, verified, pending)
- Property details and investment info
- Primary sale participation

### Portfolio (`/portfolio`)
- View owned property tokens
- Track total portfolio value
- Registered properties status
- Performance metrics

### Governance (`/governance`)
- Active and past proposals
- Vote on property decisions
- Voting power display
- Proposal creation (for token holders)

### Analytics (`/analytics`)
- Total Value Locked (TVL)
- Platform statistics
- Recent activity feed
- Top performing properties

## Smart Contract Integration

The frontend interacts with the following smart contracts:

- **LandRegistry** - Property registration and verification
- **StakingVault** - USDC stake management
- **PrimaryMarket** - Initial token sales
- **LandToken** - ERC-20 property tokens
- **LandGovernor** - On-chain governance
- **PriceOracle** - Property valuations

## Development

### Build for Production

```bash
npm run build
```

### Start Production Server

```bash
npm run start
```

### Lint Code

```bash
npm run lint
```

## Environment Setup

### Sepolia Testnet

1. Get Sepolia ETH from [Sepolia Faucet](https://sepoliafaucet.com/)
2. Get test USDC from the faucet (if available)
3. Deploy contracts using the parent project
4. Update `.env` with contract addresses

### Polygon Amoy/Mainnet

Update `NEXT_PUBLIC_CHAIN_ID` and `NEXT_PUBLIC_RPC_URL` accordingly.

## Features Roadmap

- [ ] Property detail pages with full information
- [ ] Advanced filtering and search
- [ ] Real-time price charts using Recharts
- [ ] Notification system for governance votes
- [ ] Multi-language support
- [ ] Dark mode toggle
- [ ] Mobile app (React Native)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Troubleshooting

### Wallet Connection Issues

- Ensure you're on the correct network (Sepolia/Polygon)
- Clear browser cache and reconnect wallet
- Try a different wallet provider

### Transaction Failures

- Check you have sufficient ETH for gas
- Verify USDC approval before registration
- Ensure contract addresses are correct in `.env`

### Build Errors

- Delete `.next` folder and `node_modules`
- Run `npm install` again
- Check Node.js version (>=18)

## License

MIT License - See parent project for details

## Support

For issues and questions:
- Open an issue on GitHub
- Check the main project documentation
- Review the smart contract documentation in `../PROTOCOL.md`

---

Built with ❤️ for the future of real estate tokenization
