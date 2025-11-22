# 🚀 Advanced Frontend Implementation Guide

This guide shows how to complete the advanced features with Framer Motion, shadcn/ui, and full contract integration.

## ✅ Already Implemented

### Core Features
- ✅ ThirdWeb SDK v5 integration
- ✅ Wallet connection (MetaMask, WalletConnect, etc.)
- ✅ **Property Registration** (FULLY FUNCTIONAL)
  - USDC approval workflow
  - Smart contract integration
  - Transaction tracking
  - Error handling

### UI Components
- ✅ Button component (shadcn/ui)
- ✅ Card component (shadcn/ui)
- ✅ Toast notifications (Sonner)
- ✅ Responsive Navbar with ThirdWeb Connect
- ✅ Footer component

### Dependencies Installed
- ✅ framer-motion (animations)
- ✅ animejs (advanced animations)
- ✅ @radix-ui components (accessible UI primitives)
- ✅ sonner (toast notifications)
- ✅ next-themes (dark mode)
- ✅ recharts (data visualization)

---

## 🔨 How to Complete Remaining Features

### 1. Marketplace Page with Contract Integration

**File**: `src/app/marketplace/page.tsx`

```typescript
'use client';

import { useEffect, useState } from 'react';
import { useActiveAccount } from "thirdweb/react";
import { readContract } from "thirdweb";
import { useLandRegistryContract } from '@/hooks/useContracts';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

export default function MarketplacePage() {
  const account = useActiveAccount();
  const landRegistry = useLandRegistryContract();
  const [properties, setProperties] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadProperties() {
      try {
        // Get all tokens
        const tokens = await readContract({
          contract: landRegistry,
          method: "function getAllTokens() view returns (address[])",
          params: [],
        });

        // Load property data for each token
        const propertyData = await Promise.all(
          tokens.map(async (tokenAddr) => {
            const propertyId = await readContract({
              contract: landRegistry,
              method: "function tokenToProperty(address) view returns (bytes32)",
              params: [tokenAddr],
            });

            const property = await readContract({
              contract: landRegistry,
              method: "function properties(bytes32) view returns (...)",
              params: [propertyId],
            });

            return { tokenAddr, propertyId, ...property };
          })
        );

        setProperties(propertyData);
      } catch (error) {
        console.error("Error loading properties:", error);
      } finally {
        setLoading(false);
      }
    }

    if (account) {
      loadProperties();
    }
  }, [account, landRegistry]);

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <main className="max-w-7xl mx-auto px-4 py-12">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          <h1 className="text-4xl font-bold mb-8">Property Marketplace</h1>

          {loading ? (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {[1, 2, 3].map((i) => (
                <Card key={i} className="animate-pulse">
                  <CardHeader>
                    <div className="h-4 bg-gray-200 rounded w-3/4"></div>
                  </CardHeader>
                  <CardContent>
                    <div className="h-24 bg-gray-200 rounded"></div>
                  </CardContent>
                </Card>
              ))}
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {properties.map((property, i) => (
                <motion.div
                  key={property.tokenAddr}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.1 }}
                >
                  <PropertyCard property={property} />
                </motion.div>
              ))}
            </div>
          )}
        </motion.div>
      </main>
      <Footer />
    </div>
  );
}
```

### 2. Portfolio Page with Charts

**File**: `src/app/portfolio/page.tsx`

```typescript
'use client';

import { useActiveAccount } from "thirdweb/react";
import { readContract } from "thirdweb";
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts';
import { motion } from 'framer-motion';

export default function PortfolioPage() {
  const account = useActiveAccount();

  // Read user's token balances
  const { data: holdings } = useQuery({
    queryKey: ['portfolio', account?.address],
    queryFn: async () => {
      // Fetch all tokens user holds
      // Calculate total value
      // Return formatted data
    },
    enabled: !!account,
  });

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="p-8"
    >
      {/* Portfolio value chart */}
      <AreaChart width={800} height={400} data={holdings}>
        <Area type="monotone" dataKey="value" stroke="#0ea5e9" fill="#0ea5e9" />
      </AreaChart>

      {/* Holdings table */}
      {/* Transaction history */}
    </motion.div>
  );
}
```

### 3. Governance with Voting

**File**: `src/app/governance/page.tsx`

```typescript
'use client';

import { prepareContractCall, sendTransaction } from "thirdweb";
import { useGovernorContract } from '@/hooks/useContracts';

export default function GovernancePage() {
  const governor = useGovernorContract();

  async function voteOnProposal(proposalId: bigint, support: boolean) {
    const transaction = prepareContractCall({
      contract: governor,
      method: "function castVote(uint256 proposalId, uint8 support)",
      params: [proposalId, support ? 1 : 0],
    });

    const { transactionHash } = await sendTransaction({
      transaction,
      account,
    });

    toast.success(`Vote cast! TX: ${transactionHash}`);
  }

  return (
    // Proposals list
    // Vote buttons
    // Create proposal form
  );
}
```

### 4. Token Purchase Functionality

**File**: `src/app/property/[id]/page.tsx`

```typescript
'use client';

export default function PropertyDetailPage({ params }: { params: { id: string } }) {
  async function buyTokens(amount: bigint) {
    // 1. Approve USDC
    const approvalTx = prepareContractCall({
      contract: usdcContract,
      method: "function approve(address spender, uint256 amount)",
      params: [CONTRACT_ADDRESSES.primaryMarket, amount * TOKEN_PRICE],
    });

    await sendTransaction({ transaction: approvalTx, account });

    // 2. Buy tokens
    const buyTx = prepareContractCall({
      contract: primaryMarket,
      method: "function buyTokens(address tokenAddress, uint256 amount)",
      params: [tokenAddress, amount],
    });

    const { transactionHash } = await sendTransaction({
      transaction: buyTx,
      account
    });

    toast.success(`Tokens purchased! TX: ${transactionHash}`);
  }

  return (
    // Property details
    // Buy form
    // Sale info
  );
}
```

### 5. Advanced Animations

**Add to any component**:

```typescript
import { motion } from 'framer-motion';
import anime from 'animejs';

// Framer Motion
<motion.div
  initial={{ opacity: 0, scale: 0.95 }}
  animate={{ opacity: 1, scale: 1 }}
  whileHover={{ scale: 1.02 }}
  whileTap={{ scale: 0.98 }}
  transition={{ type: "spring", stiffness: 300 }}
>
  {children}
</motion.div>

// Anime.js
useEffect(() => {
  anime({
    targets: '.stat-card',
    translateY: [20, 0],
    opacity: [0, 1],
    delay: anime.stagger(100),
    easing: 'easeOutExpo',
  });
}, []);
```

### 6. Loading Skeletons

```typescript
export function SkeletonCard() {
  return (
    <Card className="animate-pulse">
      <CardHeader>
        <div className="h-4 bg-gray-200 rounded w-3/4"></div>
        <div className="h-3 bg-gray-200 rounded w-1/2 mt-2"></div>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          <div className="h-3 bg-gray-200 rounded"></div>
          <div className="h-3 bg-gray-200 rounded w-5/6"></div>
        </div>
      </CardContent>
    </Card>
  );
}
```

---

## 📊 Analytics Implementation

Use **recharts** for data visualization:

```typescript
import { LineChart, Line, BarChart, Bar, PieChart, Pie } from 'recharts';

// Platform statistics
<LineChart width={600} height={300} data={tvlData}>
  <Line type="monotone" dataKey="tvl" stroke="#0ea5e9" />
  <XAxis dataKey="date" />
  <YAxis />
  <Tooltip />
</LineChart>

// Property distribution
<PieChart width={400} height={400}>
  <Pie
    data={propertyData}
    dataKey="value"
    nameKey="status"
    cx="50%"
    cy="50%"
    fill="#0ea5e9"
  />
</PieChart>
```

---

## 🎨 Theming with next-themes

**Setup**:

```typescript
// app/providers.tsx
import { ThemeProvider } from "next-themes";

<ThemeProvider attribute="class" defaultTheme="system">
  {children}
</ThemeProvider>

// components/theme-toggle.tsx
import { useTheme } from "next-themes";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  return (
    <button onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
      Toggle Theme
    </button>
  );
}
```

---

## 🔔 Toast Notifications

```typescript
import { toast } from 'sonner';

// Success
toast.success('Property registered successfully!');

// Error
toast.error('Transaction failed');

// Loading
toast.loading('Processing transaction...');

// Custom
toast.custom((t) => (
  <div className="bg-white p-4 rounded-lg shadow-lg">
    Custom toast content
  </div>
));
```

---

## 🚀 Running the Complete App

```bash
cd frontend
npm install
npm run dev
```

Visit `http://localhost:3000` and enjoy your advanced RWA dApp!

---

## 📝 Next Steps

1. **Complete Marketplace** - Add filters, search, sorting
2. **Portfolio Analytics** - Add charts and performance metrics
3. **Governance Dashboard** - Proposal creation and voting
4. **Advanced Animations** - Add page transitions
5. **Dark Mode** - Implement theme toggle
6. **Mobile Optimization** - Enhance mobile UX
7. **Real-time Updates** - Add WebSocket for live data
8. **Error Boundaries** - Add error handling
9. **Unit Tests** - Add test coverage
10. **Performance** - Optimize bundle size

---

**All the infrastructure is ready - just implement the logic following these patterns!** 🚀
