'use client';

import { useState, useEffect } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useActiveAccount } from "thirdweb/react";
import { readContract, prepareContractCall, sendTransaction, getContract } from "thirdweb";
import { useLandRegistryContract } from '@/hooks/useContracts';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { ArrowDownUp, Building2, TrendingUp, Info, RefreshCw, ChevronDown } from 'lucide-react';
import { toast } from 'sonner';
import { client } from "@/lib/thirdweb";
import { ACTIVE_CHAIN, CONTRACT_ADDRESSES } from "@/lib/config";
import LandTokenABI from "@/contracts/abis/LandToken.json";
import { formatUSDC, formatToken } from '@/utils/format';

interface TokenOption {
  address: string;
  symbol: string;
  name: string;
  balance: bigint;
  decimals: number;
}

export default function SwapPage() {
  const account = useActiveAccount();
  const landRegistry = useLandRegistryContract();

  const [loading, setLoading] = useState(true);
  const [tokens, setTokens] = useState<TokenOption[]>([]);
  const [fromToken, setFromToken] = useState<TokenOption | null>(null);
  const [toToken, setToToken] = useState<TokenOption | null>(null);
  const [fromAmount, setFromAmount] = useState('');
  const [toAmount, setToAmount] = useState('');
  const [swapping, setSwapping] = useState(false);
  const [showFromDropdown, setShowFromDropdown] = useState(false);
  const [showToDropdown, setShowToDropdown] = useState(false);

  // USDC token for the base pair
  const USDC_TOKEN: TokenOption = {
    address: CONTRACT_ADDRESSES.USDC,
    symbol: 'USDC',
    name: 'USD Coin',
    balance: BigInt(0),
    decimals: 6,
  };

  useEffect(() => {
    loadTokens();
  }, [account]);

  async function loadTokens() {
    if (!account) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);

      // Get all property token addresses
      const tokenAddresses = await readContract({
        contract: landRegistry,
        method: "function getAllTokens() view returns (address[])",
        params: [],
      }) as string[];

      const loadedTokens: TokenOption[] = [];

      // Load USDC balance
      const usdcContract = getContract({
        client,
        chain: ACTIVE_CHAIN,
        address: CONTRACT_ADDRESSES.USDC,
      });

      const usdcBalance = await readContract({
        contract: usdcContract,
        method: "function balanceOf(address) view returns (uint256)",
        params: [account.address],
      }) as bigint;

      loadedTokens.push({
        ...USDC_TOKEN,
        balance: usdcBalance,
      });

      // Load each land token
      for (const tokenAddress of tokenAddresses) {
        try {
          const tokenContract = getContract({
            client,
            chain: ACTIVE_CHAIN,
            address: tokenAddress,
            abi: LandTokenABI,
          });

          // Get token details
          const [symbol, name, balance] = await Promise.all([
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
            readContract({
              contract: tokenContract,
              method: "function balanceOf(address) view returns (uint256)",
              params: [account.address],
            }) as Promise<bigint>,
          ]);

          loadedTokens.push({
            address: tokenAddress,
            symbol,
            name,
            balance,
            decimals: 18,
          });
        } catch (error) {
          console.error('Error loading token:', tokenAddress, error);
        }
      }

      setTokens(loadedTokens);

      // Set default tokens: USDC -> first property token
      if (loadedTokens.length > 0) {
        setFromToken(loadedTokens[0]); // USDC
        if (loadedTokens.length > 1) {
          setToToken(loadedTokens[1]); // First property token
        }
      }

      toast.success(`Loaded ${loadedTokens.length} tokens`);
    } catch (error: any) {
      console.error('Error loading tokens:', error);
      toast.error('Failed to load tokens');
    } finally {
      setLoading(false);
    }
  }

  function calculateEstimatedOutput() {
    if (!fromAmount || !fromToken || !toToken) {
      setToAmount('');
      return;
    }

    try {
      // Simple calculation: 1 token = 10 USDC (TOKEN_PRICE from tokenomics)
      const TOKEN_PRICE = 10;
      const inputAmount = parseFloat(fromAmount);

      if (isNaN(inputAmount) || inputAmount <= 0) {
        setToAmount('');
        return;
      }

      let estimated: number;

      if (fromToken.symbol === 'USDC') {
        // Buying property tokens with USDC
        estimated = inputAmount / TOKEN_PRICE;
      } else if (toToken.symbol === 'USDC') {
        // Selling property tokens for USDC
        estimated = inputAmount * TOKEN_PRICE;
      } else {
        // Token to token swap (via USDC)
        estimated = inputAmount;
      }

      setToAmount(estimated.toFixed(6));
    } catch (error) {
      console.error('Error calculating output:', error);
      setToAmount('');
    }
  }

  useEffect(() => {
    calculateEstimatedOutput();
  }, [fromAmount, fromToken, toToken]);

  function switchTokens() {
    const temp = fromToken;
    setFromToken(toToken);
    setToToken(temp);
    setFromAmount(toAmount);
    setToAmount('');
  }

  async function handleSwap() {
    if (!account || !fromToken || !toToken || !fromAmount) {
      toast.error('Please fill in all fields');
      return;
    }

    try {
      setSwapping(true);

      const fromAmountBigInt = BigInt(Math.floor(parseFloat(fromAmount) * Math.pow(10, fromToken.decimals)));

      // Check balance
      if (fromAmountBigInt > fromToken.balance) {
        toast.error(`Insufficient ${fromToken.symbol} balance`);
        return;
      }

      toast.info('Swap functionality requires DEX integration. For now, use the Primary Market to purchase tokens.');

      // In a production environment, you would:
      // 1. Approve token spending if needed
      // 2. Call Uniswap V2 Router or use an aggregator
      // 3. Execute the swap transaction

      // Example structure (not functional without DEX deployment):
      /*
      // Approve if needed
      const tokenContract = getContract({
        client,
        chain: ACTIVE_CHAIN,
        address: fromToken.address,
      });

      const tx = await sendTransaction({
        transaction: prepareContractCall({
          contract: tokenContract,
          method: "function approve(address spender, uint256 amount) returns (bool)",
          params: [ROUTER_ADDRESS, fromAmountBigInt],
        }),
        account,
      });

      // Then execute swap on router
      */

    } catch (error: any) {
      console.error('Swap error:', error);
      toast.error(error.message || 'Swap failed');
    } finally {
      setSwapping(false);
    }
  }

  function selectFromToken(token: TokenOption) {
    setFromToken(token);
    setShowFromDropdown(false);
    if (toToken?.address === token.address) {
      setToToken(null);
    }
  }

  function selectToToken(token: TokenOption) {
    setToToken(token);
    setShowToDropdown(false);
    if (fromToken?.address === token.address) {
      setFromToken(null);
    }
  }

  return (
    <div className="min-h-screen flex flex-col bg-gradient-to-br from-gray-50 via-primary-50/30 to-gray-50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900">
      <Navbar />

      <main className="flex-1 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 w-full">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8 text-center"
        >
          <h1 className="text-4xl font-bold text-gray-900 dark:text-white mb-2 flex items-center justify-center gap-3">
            <TrendingUp className="h-10 w-10 text-primary-600" />
            Token Exchange
          </h1>
          <p className="text-gray-600 dark:text-gray-400">
            Swap between property tokens and USDC
          </p>
        </motion.div>

        {!account ? (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-12 text-center"
          >
            <Building2 className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold mb-2 dark:text-white">Connect Your Wallet</h3>
            <p className="text-gray-600 dark:text-gray-400">
              Please connect your wallet to access the token exchange
            </p>
          </motion.div>
        ) : loading ? (
          <Card>
            <CardContent className="py-12">
              <div className="flex flex-col items-center gap-4">
                <RefreshCw className="h-8 w-8 animate-spin text-primary-600" />
                <p className="text-gray-600 dark:text-gray-400">Loading tokens...</p>
              </div>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-6">
            {/* Swap Card */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 }}
            >
              <Card className="overflow-hidden">
                <CardHeader className="bg-gradient-to-r from-primary-500 to-primary-600 text-white">
                  <CardTitle className="flex items-center gap-2">
                    <ArrowDownUp className="h-5 w-5" />
                    Swap Tokens
                  </CardTitle>
                  <CardDescription className="text-primary-100">
                    Exchange property tokens and USDC
                  </CardDescription>
                </CardHeader>
                <CardContent className="p-6 space-y-4">
                  {/* From Token */}
                  <div className="space-y-2">
                    <label className="text-sm font-medium text-gray-700 dark:text-gray-300">From</label>
                    <div className="relative">
                      <div className="flex gap-2">
                        <div className="relative flex-1">
                          <button
                            onClick={() => setShowFromDropdown(!showFromDropdown)}
                            className="w-full px-4 py-3 bg-gray-100 dark:bg-gray-700 rounded-lg flex items-center justify-between hover:bg-gray-200 dark:hover:bg-gray-600 transition"
                          >
                            <div className="flex items-center gap-2">
                              {fromToken ? (
                                <>
                                  <div className="w-8 h-8 rounded-full bg-primary-600 flex items-center justify-center text-white font-bold text-sm">
                                    {fromToken.symbol[0]}
                                  </div>
                                  <div className="text-left">
                                    <div className="font-semibold dark:text-white">{fromToken.symbol}</div>
                                    <div className="text-xs text-gray-500 dark:text-gray-400">
                                      Balance: {fromToken.decimals === 6 ? formatUSDC(fromToken.balance) : formatToken(fromToken.balance)}
                                    </div>
                                  </div>
                                </>
                              ) : (
                                <span className="text-gray-500 dark:text-gray-400">Select token</span>
                              )}
                            </div>
                            <ChevronDown className="h-5 w-5 text-gray-400" />
                          </button>

                          {showFromDropdown && (
                            <div className="absolute top-full mt-2 w-full bg-white dark:bg-gray-800 rounded-lg shadow-xl border border-gray-200 dark:border-gray-700 z-10 max-h-64 overflow-y-auto">
                              {tokens.map((token) => (
                                <button
                                  key={token.address}
                                  onClick={() => selectFromToken(token)}
                                  disabled={token.address === toToken?.address}
                                  className="w-full px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed transition"
                                >
                                  <div className="w-8 h-8 rounded-full bg-primary-600 flex items-center justify-center text-white font-bold text-sm">
                                    {token.symbol[0]}
                                  </div>
                                  <div className="flex-1 text-left">
                                    <div className="font-semibold dark:text-white">{token.symbol}</div>
                                    <div className="text-xs text-gray-500 dark:text-gray-400">
                                      {token.decimals === 6 ? formatUSDC(token.balance) : formatToken(token.balance)}
                                    </div>
                                  </div>
                                </button>
                              ))}
                            </div>
                          )}
                        </div>
                        <input
                          type="number"
                          value={fromAmount}
                          onChange={(e) => setFromAmount(e.target.value)}
                          placeholder="0.00"
                          className="flex-1 px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-700 dark:text-white"
                        />
                      </div>
                    </div>
                  </div>

                  {/* Switch Button */}
                  <div className="flex justify-center">
                    <Button
                      onClick={switchTokens}
                      variant="outline"
                      size="sm"
                      className="rounded-full p-2"
                      disabled={!fromToken || !toToken}
                    >
                      <ArrowDownUp className="h-5 w-5" />
                    </Button>
                  </div>

                  {/* To Token */}
                  <div className="space-y-2">
                    <label className="text-sm font-medium text-gray-700 dark:text-gray-300">To</label>
                    <div className="relative">
                      <div className="flex gap-2">
                        <div className="relative flex-1">
                          <button
                            onClick={() => setShowToDropdown(!showToDropdown)}
                            className="w-full px-4 py-3 bg-gray-100 dark:bg-gray-700 rounded-lg flex items-center justify-between hover:bg-gray-200 dark:hover:bg-gray-600 transition"
                          >
                            <div className="flex items-center gap-2">
                              {toToken ? (
                                <>
                                  <div className="w-8 h-8 rounded-full bg-primary-600 flex items-center justify-center text-white font-bold text-sm">
                                    {toToken.symbol[0]}
                                  </div>
                                  <div className="text-left">
                                    <div className="font-semibold dark:text-white">{toToken.symbol}</div>
                                    <div className="text-xs text-gray-500 dark:text-gray-400">
                                      Balance: {toToken.decimals === 6 ? formatUSDC(toToken.balance) : formatToken(toToken.balance)}
                                    </div>
                                  </div>
                                </>
                              ) : (
                                <span className="text-gray-500 dark:text-gray-400">Select token</span>
                              )}
                            </div>
                            <ChevronDown className="h-5 w-5 text-gray-400" />
                          </button>

                          {showToDropdown && (
                            <div className="absolute top-full mt-2 w-full bg-white dark:bg-gray-800 rounded-lg shadow-xl border border-gray-200 dark:border-gray-700 z-10 max-h-64 overflow-y-auto">
                              {tokens.map((token) => (
                                <button
                                  key={token.address}
                                  onClick={() => selectToToken(token)}
                                  disabled={token.address === fromToken?.address}
                                  className="w-full px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed transition"
                                >
                                  <div className="w-8 h-8 rounded-full bg-primary-600 flex items-center justify-center text-white font-bold text-sm">
                                    {token.symbol[0]}
                                  </div>
                                  <div className="flex-1 text-left">
                                    <div className="font-semibold dark:text-white">{token.symbol}</div>
                                    <div className="text-xs text-gray-500 dark:text-gray-400">
                                      {token.decimals === 6 ? formatUSDC(token.balance) : formatToken(token.balance)}
                                    </div>
                                  </div>
                                </button>
                              ))}
                            </div>
                          )}
                        </div>
                        <input
                          type="number"
                          value={toAmount}
                          readOnly
                          placeholder="0.00"
                          className="flex-1 px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-gray-50 dark:bg-gray-700 dark:text-white"
                        />
                      </div>
                    </div>
                  </div>

                  {/* Info */}
                  {fromToken && toToken && fromAmount && (
                    <motion.div
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: 'auto' }}
                      className="bg-blue-50 dark:bg-blue-900/20 rounded-lg p-4"
                    >
                      <div className="flex items-start gap-2">
                        <Info className="h-5 w-5 text-blue-600 dark:text-blue-400 flex-shrink-0 mt-0.5" />
                        <div className="text-sm text-blue-800 dark:text-blue-300">
                          <p className="font-medium mb-1">Exchange Rate</p>
                          <p>1 Property Token ≈ 10 USDC (based on primary market price)</p>
                        </div>
                      </div>
                    </motion.div>
                  )}

                  {/* Swap Button */}
                  <Button
                    onClick={handleSwap}
                    disabled={!fromToken || !toToken || !fromAmount || swapping}
                    className="w-full py-6 text-lg font-semibold"
                  >
                    {swapping ? (
                      <>
                        <RefreshCw className="h-5 w-5 mr-2 animate-spin" />
                        Swapping...
                      </>
                    ) : (
                      <>
                        <ArrowDownUp className="h-5 w-5 mr-2" />
                        Swap Tokens
                      </>
                    )}
                  </Button>
                </CardContent>
              </Card>
            </motion.div>

            {/* Info Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 }}
              >
                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">Secondary Market Trading</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      After the primary sale completes, property tokens are listed on Uniswap V2-compatible DEXs.
                      Liquidity is bootstrapped automatically with LP tokens locked for 180 days.
                    </p>
                  </CardContent>
                </Card>
              </motion.div>

              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3 }}
              >
                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">Primary Market</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      For new property token purchases, visit the <a href="/marketplace" className="text-primary-600 hover:underline">Marketplace</a> to
                      participate in primary sales at the fixed price of 10 USDC per token.
                    </p>
                  </CardContent>
                </Card>
              </motion.div>
            </div>
          </div>
        )}
      </main>

      <Footer />
    </div>
  );
}
