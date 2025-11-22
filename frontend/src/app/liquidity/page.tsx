'use client';

import { useState, useEffect } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useActiveAccount } from "thirdweb/react";
import { readContract, getContract } from "thirdweb";
import { useLandRegistryContract } from '@/hooks/useContracts';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Droplet, TrendingUp, Lock, Clock, AlertCircle, DollarSign } from 'lucide-react';
import { toast } from 'sonner';
import { client } from "@/lib/thirdweb";
import { ACTIVE_CHAIN, CONTRACT_ADDRESSES } from "@/lib/config";
import LandTokenABI from "@/contracts/abis/LandToken.json";
import { formatUSDC, formatToken } from '@/utils/format';
import { LoadingSpinner } from '@/components/LoadingSpinner';

interface LiquidityPool {
  propertyId: string;
  tokenAddress: string;
  tokenSymbol: string;
  tokenName: string;
  pairAddress: string | null;
  usdcReserve: bigint;
  tokenReserve: bigint;
  lpTokenBalance: bigint;
  lockExpiryTime: bigint;
  isLocked: boolean;
  daysUntilUnlock: number;
}

export default function LiquidityPage() {
  const account = useActiveAccount();
  const landRegistry = useLandRegistryContract();

  const [loading, setLoading] = useState(true);
  const [pools, setPools] = useState<LiquidityPool[]>([]);

  useEffect(() => {
    loadLiquidityPools();
  }, [account]);

  async function loadLiquidityPools() {
    if (!account) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);

      // Get all property tokens
      const tokens = await readContract({
        contract: landRegistry,
        method: "function getAllTokens() view returns (address[])",
        params: [],
      }) as string[];

      console.log('Found tokens:', tokens);

      const loadedPools: LiquidityPool[] = [];

      // For each token, check if liquidity pool exists
      for (const tokenAddress of tokens) {
        try {
          const tokenContract = getContract({
            client,
            chain: ACTIVE_CHAIN,
            address: tokenAddress,
            abi: LandTokenABI,
          });

          // Get property ID
          const propertyId = await readContract({
            contract: landRegistry,
            method: "function tokenToProperty(address) view returns (bytes32)",
            params: [tokenAddress],
          }) as string;

          // Get token metadata
          const [symbol, name] = await Promise.all([
            readContract({
              contract: tokenContract,
              method: "function symbol() view returns (string)",
              params: [],
            }) as Promise<string>,
            readContract({
              contract: tokenContract,
              method: "function name() view returns (string)",
              params: [],
            }) as Promise<string>,
          ]);

          // In a real implementation, you would:
          // 1. Query Uniswap V2 Factory for pair address
          // 2. Get reserves from the pair contract
          // 3. Check LiquidityBootstrap contract for LP lock status

          // For now, we'll create placeholder data structure
          // This shows the UI/UX for liquidity pools

          // Mock data for demonstration (replace with actual contract calls)
          const LOCKUP_PERIOD = 180 * 24 * 60 * 60; // 180 days in seconds
          const mockLockStart = Math.floor(Date.now() / 1000) - (30 * 24 * 60 * 60); // Started 30 days ago
          const lockExpiryTime = BigInt(mockLockStart + LOCKUP_PERIOD);
          const currentTime = BigInt(Math.floor(Date.now() / 1000));
          const isLocked = lockExpiryTime > currentTime;
          const daysUntilUnlock = Number((lockExpiryTime - currentTime) / BigInt(86400));

          loadedPools.push({
            propertyId,
            tokenAddress,
            tokenSymbol: symbol,
            tokenName: name,
            pairAddress: null, // Would get from Uniswap Factory
            usdcReserve: BigInt(0), // Would get from pair.getReserves()
            tokenReserve: BigInt(0), // Would get from pair.getReserves()
            lpTokenBalance: BigInt(0), // Would get from LiquidityBootstrap
            lockExpiryTime,
            isLocked,
            daysUntilUnlock,
          });
        } catch (error) {
          console.error('Error loading pool for token:', tokenAddress, error);
        }
      }

      setPools(loadedPools);

      if (loadedPools.length === 0) {
        toast.info('No liquidity pools found yet');
      } else {
        toast.success(`Loaded ${loadedPools.length} liquidity pools`);
      }
    } catch (error: any) {
      console.error('Error loading liquidity pools:', error);
      toast.error('Failed to load liquidity pools');
    } finally {
      setLoading(false);
    }
  }

  function calculatePrice(usdcReserve: bigint, tokenReserve: bigint): string {
    if (tokenReserve === BigInt(0)) return '10.00'; // Default TOKEN_PRICE
    const price = (Number(usdcReserve) / 1e6) / (Number(tokenReserve) / 1e18);
    return price.toFixed(2);
  }

  function calculateTVL(usdcReserve: bigint): string {
    // TVL = 2x USDC reserve (since pool is 50/50)
    const tvl = (Number(usdcReserve) / 1e6) * 2;
    return tvl.toFixed(2);
  }

  return (
    <div className="min-h-screen flex flex-col bg-gradient-to-br from-blue-50 via-white to-blue-50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900">
      <Navbar />

      <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 w-full">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8"
        >
          <h1 className="text-4xl font-bold text-gray-900 dark:text-white mb-2 flex items-center gap-3">
            <Droplet className="h-10 w-10 text-blue-600" />
            Liquidity Pools
          </h1>
          <p className="text-gray-600 dark:text-gray-400">
            Monitor Uniswap V2 liquidity pools for property tokens
          </p>
        </motion.div>

        {!account ? (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-12 text-center"
          >
            <Droplet className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold mb-2 dark:text-white">Connect Your Wallet</h3>
            <p className="text-gray-600 dark:text-gray-400">
              Please connect your wallet to view liquidity pools
            </p>
          </motion.div>
        ) : loading ? (
          <div className="flex justify-center py-12">
            <LoadingSpinner size="lg" text="Loading liquidity pools..." />
          </div>
        ) : pools.length === 0 ? (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-12 text-center"
          >
            <Droplet className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold mb-2 dark:text-white">No Liquidity Pools Yet</h3>
            <p className="text-gray-600 dark:text-gray-400">
              Liquidity pools are created automatically after primary sales complete
            </p>
          </motion.div>
        ) : (
          <div className="space-y-6">
            {/* Info Banner */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 }}
            >
              <Card className="bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800">
                <CardContent className="p-6">
                  <div className="flex items-start gap-3">
                    <AlertCircle className="h-6 w-6 text-blue-600 dark:text-blue-400 flex-shrink-0 mt-1" />
                    <div>
                      <h3 className="font-semibold text-blue-900 dark:text-blue-100 mb-2">
                        Liquidity Bootstrap Protocol
                      </h3>
                      <p className="text-sm text-blue-800 dark:text-blue-300">
                        After each primary sale finalizes, the LiquidityBootstrap contract automatically creates
                        a USDC pair on Uniswap V2. LP tokens are locked for <strong>180 days</strong> to ensure
                        market stability and prevent rug pulls. This guarantees tradability for all property tokens.
                      </p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </motion.div>

            {/* Liquidity Pool Cards */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {pools.map((pool, index) => (
                <motion.div
                  key={pool.tokenAddress}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.1 + index * 0.05 }}
                >
                  <Card className="overflow-hidden hover:shadow-xl transition-shadow">
                    <CardHeader className="bg-gradient-to-r from-blue-500 to-blue-600 text-white">
                      <CardTitle className="flex items-center justify-between">
                        <span>{pool.tokenSymbol} / USDC</span>
                        {pool.isLocked && (
                          <Lock className="h-5 w-5" />
                        )}
                      </CardTitle>
                      <CardDescription className="text-blue-100">
                        {pool.tokenName}
                      </CardDescription>
                    </CardHeader>
                    <CardContent className="p-6 space-y-4">
                      {/* Pool Status */}
                      {pool.pairAddress ? (
                        <>
                          {/* Reserves */}
                          <div className="grid grid-cols-2 gap-4">
                            <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
                              <div className="text-xs text-gray-500 dark:text-gray-400 mb-1">USDC Reserve</div>
                              <div className="font-semibold text-gray-900 dark:text-white">
                                {formatUSDC(pool.usdcReserve)}
                              </div>
                            </div>
                            <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
                              <div className="text-xs text-gray-500 dark:text-gray-400 mb-1">{pool.tokenSymbol} Reserve</div>
                              <div className="font-semibold text-gray-900 dark:text-white">
                                {formatToken(pool.tokenReserve)}
                              </div>
                            </div>
                          </div>

                          {/* Price & TVL */}
                          <div className="grid grid-cols-2 gap-4">
                            <div className="flex items-center gap-2">
                              <DollarSign className="h-4 w-4 text-green-600" />
                              <div>
                                <div className="text-xs text-gray-500 dark:text-gray-400">Current Price</div>
                                <div className="font-semibold text-gray-900 dark:text-white">
                                  ${calculatePrice(pool.usdcReserve, pool.tokenReserve)}
                                </div>
                              </div>
                            </div>
                            <div className="flex items-center gap-2">
                              <TrendingUp className="h-4 w-4 text-blue-600" />
                              <div>
                                <div className="text-xs text-gray-500 dark:text-gray-400">Pool TVL</div>
                                <div className="font-semibold text-gray-900 dark:text-white">
                                  ${calculateTVL(pool.usdcReserve)}
                                </div>
                              </div>
                            </div>
                          </div>
                        </>
                      ) : (
                        <div className="bg-yellow-50 dark:bg-yellow-900/20 rounded-lg p-4 text-center">
                          <Clock className="h-8 w-8 text-yellow-600 dark:text-yellow-400 mx-auto mb-2" />
                          <p className="text-sm text-yellow-800 dark:text-yellow-300">
                            Pool will be created after primary sale completes
                          </p>
                        </div>
                      )}

                      {/* Lock Status */}
                      <div className="border-t border-gray-200 dark:border-gray-700 pt-4">
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                            LP Token Lock
                          </span>
                          <span className={`text-sm font-semibold ${pool.isLocked ? 'text-orange-600' : 'text-green-600'}`}>
                            {pool.isLocked ? 'Locked' : 'Unlocked'}
                          </span>
                        </div>
                        {pool.isLocked && (
                          <>
                            <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                              <Clock className="h-4 w-4" />
                              <span>{pool.daysUntilUnlock} days until unlock</span>
                            </div>
                            <div className="mt-3 bg-gray-200 dark:bg-gray-700 rounded-full h-2 overflow-hidden">
                              <div
                                className="bg-blue-600 h-2 rounded-full transition-all"
                                style={{
                                  width: `${Math.max(0, Math.min(100, ((180 - pool.daysUntilUnlock) / 180) * 100))}%`
                                }}
                              />
                            </div>
                            <div className="mt-1 text-xs text-gray-500 dark:text-gray-400 text-right">
                              {Math.floor(((180 - pool.daysUntilUnlock) / 180) * 100)}% elapsed
                            </div>
                          </>
                        )}
                      </div>

                      {/* Pool Address */}
                      <div className="text-xs text-gray-500 dark:text-gray-400 break-all">
                        Token: {pool.tokenAddress.slice(0, 6)}...{pool.tokenAddress.slice(-4)}
                      </div>
                    </CardContent>
                  </Card>
                </motion.div>
              ))}
            </div>

            {/* Summary Stats */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
            >
              <Card>
                <CardHeader>
                  <CardTitle>Liquidity Overview</CardTitle>
                  <CardDescription>Platform-wide liquidity metrics</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div className="bg-blue-50 dark:bg-blue-900/20 rounded-lg p-4">
                      <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Total Pools</div>
                      <div className="text-2xl font-bold text-blue-600 dark:text-blue-400">
                        {pools.length}
                      </div>
                    </div>
                    <div className="bg-green-50 dark:bg-green-900/20 rounded-lg p-4">
                      <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Locked Pools</div>
                      <div className="text-2xl font-bold text-green-600 dark:text-green-400">
                        {pools.filter(p => p.isLocked).length}
                      </div>
                    </div>
                    <div className="bg-purple-50 dark:bg-purple-900/20 rounded-lg p-4">
                      <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Average Lock Remaining</div>
                      <div className="text-2xl font-bold text-purple-600 dark:text-purple-400">
                        {Math.floor(pools.reduce((acc, p) => acc + p.daysUntilUnlock, 0) / pools.length)} days
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </motion.div>

            {/* Educational Info */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
            >
              <Card>
                <CardHeader>
                  <CardTitle>Understanding Liquidity Bootstrap</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3 text-sm text-gray-600 dark:text-gray-400">
                  <p>
                    <strong className="text-gray-900 dark:text-white">Automatic Pool Creation:</strong> When a primary
                    sale finalizes, the LiquidityBootstrap contract automatically creates a USDC pair on Uniswap V2,
                    ensuring immediate tradability for investors.
                  </p>
                  <p>
                    <strong className="text-gray-900 dark:text-white">180-Day Lock:</strong> LP tokens are locked in
                    the contract for 180 days to prevent rug pulls and maintain market stability. This protects investors
                    and ensures long-term liquidity.
                  </p>
                  <p>
                    <strong className="text-gray-900 dark:text-white">5% Slippage Protection:</strong> The protocol
                    uses MathLib.applySlippage to protect against price manipulation during pool creation, limiting
                    variance to ±5% in both directions.
                  </p>
                  <p>
                    <strong className="text-gray-900 dark:text-white">Price Discovery:</strong> After the lock period,
                    pool reserves reflect true market demand. The PriceOracle tracks both DEX prices and manual/Chainlink
                    feeds to detect divergence.
                  </p>
                </CardContent>
              </Card>
            </motion.div>
          </div>
        )}
      </main>

      <Footer />
    </div>
  );
}
