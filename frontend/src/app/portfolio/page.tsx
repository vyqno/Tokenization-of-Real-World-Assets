'use client';

import { useState, useEffect } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useActiveAccount } from "thirdweb/react";
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import {
  Building2, TrendingUp, Wallet, PieChart, ArrowUpRight, ArrowDownRight,
  DollarSign, Activity, Clock, ExternalLink
} from 'lucide-react';
import {
  AreaChart, Area, BarChart, Bar, PieChart as RePieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend
} from 'recharts';
import { formatUSDC, formatToken } from '@/utils/format';
import Link from 'next/link';

interface Holding {
  propertyId: string;
  tokenAddress: string;
  location: string;
  tokensHeld: bigint;
  currentValue: bigint;
  purchaseValue: bigint;
  change24h: number;
}

interface Transaction {
  id: string;
  type: 'buy' | 'sell' | 'reward';
  property: string;
  amount: bigint;
  value: bigint;
  timestamp: number;
}

const COLORS = ['#0ea5e9', '#8b5cf6', '#ec4899', '#f59e0b', '#10b981'];

export default function PortfolioPage() {
  const account = useActiveAccount();
  const [holdings, setHoldings] = useState<Holding[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [totalValue, setTotalValue] = useState(BigInt(0));
  const [totalInvested, setTotalInvested] = useState(BigInt(0));

  useEffect(() => {
    if (account) {
      loadPortfolioData();
    }
  }, [account]);

  async function loadPortfolioData() {
    setLoading(true);
    try {
      // Demo data - replace with actual contract calls
      const demoHoldings: Holding[] = [
        {
          propertyId: '0x1',
          tokenAddress: '0x123...',
          location: 'Downtown Manhattan, NY',
          tokensHeld: BigInt(5000 * 1e18),
          currentValue: BigInt(52500 * 1e6),
          purchaseValue: BigInt(50000 * 1e6),
          change24h: 2.5,
        },
        {
          propertyId: '0x2',
          tokenAddress: '0x456...',
          location: 'Beverly Hills, CA',
          tokensHeld: BigInt(3000 * 1e18),
          currentValue: BigInt(31200 * 1e6),
          purchaseValue: BigInt(30000 * 1e6),
          change24h: 1.8,
        },
      ];

      const demoTransactions: Transaction[] = [
        {
          id: '1',
          type: 'buy',
          property: 'Downtown Manhattan, NY',
          amount: BigInt(5000 * 1e18),
          value: BigInt(50000 * 1e6),
          timestamp: Date.now() / 1000 - 86400 * 7,
        },
        {
          id: '2',
          type: 'buy',
          property: 'Beverly Hills, CA',
          amount: BigInt(3000 * 1e18),
          value: BigInt(30000 * 1e6),
          timestamp: Date.now() / 1000 - 86400 * 3,
        },
        {
          id: '3',
          type: 'reward',
          property: 'Downtown Manhattan, NY',
          amount: BigInt(250 * 1e18),
          value: BigInt(2500 * 1e6),
          timestamp: Date.now() / 1000 - 86400,
        },
      ];

      setHoldings(demoHoldings);
      setTransactions(demoTransactions);

      const total = demoHoldings.reduce((sum, h) => sum + h.currentValue, BigInt(0));
      const invested = demoHoldings.reduce((sum, h) => sum + h.purchaseValue, BigInt(0));
      setTotalValue(total);
      setTotalInvested(invested);
    } catch (error) {
      console.error('Error loading portfolio:', error);
    } finally {
      setLoading(false);
    }
  }

  if (!account) {
    return (
      <div className="min-h-screen flex flex-col">
        <Navbar />
        <main className="flex-1 bg-gray-50 dark:bg-gray-900 py-12">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-12 text-center"
            >
              <Wallet className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-xl font-semibold mb-2 dark:text-white">Connect Your Wallet</h3>
              <p className="text-gray-600 dark:text-gray-400">
                Please connect your wallet to view your portfolio
              </p>
            </motion.div>
          </div>
        </main>
        <Footer />
      </div>
    );
  }

  const portfolioReturn = totalInvested > BigInt(0)
    ? Number((totalValue - totalInvested) * BigInt(10000) / totalInvested) / 100
    : 0;

  const performanceData = [
    { date: 'Mon', value: 75000 },
    { date: 'Tue', value: 78000 },
    { date: 'Wed', value: 76500 },
    { date: 'Thu', value: 81000 },
    { date: 'Fri', value: 82500 },
    { date: 'Sat', value: 83000 },
    { date: 'Sun', value: 83700 },
  ];

  const allocationData = holdings.map((h, i) => ({
    name: h.location,
    value: Number(h.currentValue) / 1e6,
    color: COLORS[i % COLORS.length],
  }));

  return (
    <div className="min-h-screen flex flex-col bg-gray-50 dark:bg-gray-900">
      <Navbar />

      <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 w-full">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8"
        >
          <h1 className="text-4xl font-bold text-gray-900 dark:text-white mb-2">
            Portfolio Overview
          </h1>
          <p className="text-gray-600 dark:text-gray-400">
            Track your property investments and performance
          </p>
        </motion.div>

        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
          >
            <Card>
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-sm font-medium text-gray-600 dark:text-gray-400">
                    Total Value
                  </CardTitle>
                  <Wallet className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  ${formatUSDC(totalValue)}
                </div>
                <div className={`flex items-center mt-2 text-sm ${portfolioReturn >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                  {portfolioReturn >= 0 ? (
                    <ArrowUpRight className="h-4 w-4 mr-1" />
                  ) : (
                    <ArrowDownRight className="h-4 w-4 mr-1" />
                  )}
                  {portfolioReturn >= 0 ? '+' : ''}{portfolioReturn.toFixed(2)}%
                </div>
              </CardContent>
            </Card>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
          >
            <Card>
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-sm font-medium text-gray-600 dark:text-gray-400">
                    Properties
                  </CardTitle>
                  <Building2 className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  {holdings.length}
                </div>
                <div className="text-sm text-gray-600 dark:text-gray-400 mt-2">
                  Active holdings
                </div>
              </CardContent>
            </Card>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
          >
            <Card>
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-sm font-medium text-gray-600 dark:text-gray-400">
                    Total Invested
                  </CardTitle>
                  <DollarSign className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  ${formatUSDC(totalInvested)}
                </div>
                <div className="text-sm text-gray-600 dark:text-gray-400 mt-2">
                  USDC
                </div>
              </CardContent>
            </Card>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
          >
            <Card>
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-sm font-medium text-gray-600 dark:text-gray-400">
                    P&L
                  </CardTitle>
                  <TrendingUp className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className={`text-3xl font-bold ${portfolioReturn >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                  {portfolioReturn >= 0 ? '+' : ''}${formatUSDC(totalValue - totalInvested)}
                </div>
                <div className="text-sm text-gray-600 dark:text-gray-400 mt-2">
                  Unrealized
                </div>
              </CardContent>
            </Card>
          </motion.div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          {/* Performance Chart */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.5 }}
            className="lg:col-span-2"
          >
            <Card>
              <CardHeader>
                <CardTitle>Portfolio Performance</CardTitle>
                <CardDescription>7-day value trend</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={performanceData}>
                    <defs>
                      <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#0ea5e9" stopOpacity={0.3} />
                        <stop offset="95%" stopColor="#0ea5e9" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" className="stroke-gray-200 dark:stroke-gray-700" />
                    <XAxis dataKey="date" className="text-sm" />
                    <YAxis className="text-sm" />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: 'rgba(255, 255, 255, 0.95)',
                        border: '1px solid #e5e7eb',
                        borderRadius: '8px',
                      }}
                      formatter={(value: any) => [`$${value.toLocaleString()}`, 'Value']}
                    />
                    <Area
                      type="monotone"
                      dataKey="value"
                      stroke="#0ea5e9"
                      fillOpacity={1}
                      fill="url(#colorValue)"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </motion.div>

          {/* Asset Allocation */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.6 }}
          >
            <Card>
              <CardHeader>
                <CardTitle>Asset Allocation</CardTitle>
                <CardDescription>By property value</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <RePieChart>
                    <Pie
                      data={allocationData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={90}
                      paddingAngle={5}
                      dataKey="value"
                    >
                      {allocationData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip
                      formatter={(value: any) => [`$${value.toLocaleString()}`, 'Value']}
                    />
                  </RePieChart>
                </ResponsiveContainer>
                <div className="mt-4 space-y-2">
                  {allocationData.map((item, i) => (
                    <div key={i} className="flex items-center justify-between text-sm">
                      <div className="flex items-center gap-2">
                        <div
                          className="w-3 h-3 rounded-full"
                          style={{ backgroundColor: item.color }}
                        />
                        <span className="text-gray-600 dark:text-gray-400 truncate max-w-[150px]">
                          {item.name.split(',')[0]}
                        </span>
                      </div>
                      <span className="font-semibold dark:text-white">
                        ${item.value.toLocaleString()}
                      </span>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </motion.div>
        </div>

        {/* Holdings Table */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.7 }}
          className="mb-8"
        >
          <Card>
            <CardHeader>
              <CardTitle>My Holdings</CardTitle>
              <CardDescription>Your property token portfolio</CardDescription>
            </CardHeader>
            <CardContent>
              {holdings.length === 0 ? (
                <div className="text-center py-12">
                  <Building2 className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                  <p className="text-gray-600 dark:text-gray-400">No holdings yet</p>
                  <p className="text-sm text-gray-500 dark:text-gray-500 mt-1">
                    Start investing in tokenized properties
                  </p>
                  <Link href="/marketplace">
                    <Button className="mt-4">Browse Marketplace</Button>
                  </Link>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead className="border-b dark:border-gray-700">
                      <tr>
                        <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                          Property
                        </th>
                        <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                          Tokens
                        </th>
                        <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                          Value
                        </th>
                        <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                          P&L
                        </th>
                        <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                          24h
                        </th>
                        <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                          Action
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y dark:divide-gray-700">
                      {holdings.map((holding, i) => {
                        const pnl = holding.currentValue - holding.purchaseValue;
                        const pnlPercent = Number((pnl * BigInt(10000)) / holding.purchaseValue) / 100;

                        return (
                          <tr key={i} className="hover:bg-gray-50 dark:hover:bg-gray-800 transition">
                            <td className="px-4 py-4">
                              <div>
                                <div className="font-medium dark:text-white">{holding.location.split(',')[0]}</div>
                                <div className="text-sm text-gray-500 dark:text-gray-400">{holding.location}</div>
                              </div>
                            </td>
                            <td className="px-4 py-4 dark:text-gray-300">{formatToken(holding.tokensHeld)}</td>
                            <td className="px-4 py-4 font-semibold dark:text-white">
                              ${formatUSDC(holding.currentValue)}
                            </td>
                            <td className="px-4 py-4">
                              <div className={pnl >= BigInt(0) ? 'text-green-600' : 'text-red-600'}>
                                <div className="font-semibold">
                                  {pnl >= BigInt(0) ? '+' : ''}${formatUSDC(pnl)}
                                </div>
                                <div className="text-sm">
                                  {pnlPercent >= 0 ? '+' : ''}{pnlPercent.toFixed(2)}%
                                </div>
                              </div>
                            </td>
                            <td className="px-4 py-4">
                              <div className={`flex items-center ${holding.change24h >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                                {holding.change24h >= 0 ? (
                                  <ArrowUpRight className="h-4 w-4 mr-1" />
                                ) : (
                                  <ArrowDownRight className="h-4 w-4 mr-1" />
                                )}
                                {holding.change24h >= 0 ? '+' : ''}{holding.change24h.toFixed(2)}%
                              </div>
                            </td>
                            <td className="px-4 py-4">
                              <Link href={`/property/${holding.propertyId}`}>
                                <Button variant="outline" size="sm">
                                  <ExternalLink className="h-4 w-4 mr-1" />
                                  View
                                </Button>
                              </Link>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </CardContent>
          </Card>
        </motion.div>

        {/* Recent Transactions */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8 }}
        >
          <Card>
            <CardHeader>
              <CardTitle>Recent Transactions</CardTitle>
              <CardDescription>Your latest activity</CardDescription>
            </CardHeader>
            <CardContent>
              {transactions.length === 0 ? (
                <div className="text-center py-12">
                  <Activity className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                  <p className="text-gray-600 dark:text-gray-400">No transactions yet</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {transactions.map((tx) => (
                    <div
                      key={tx.id}
                      className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-800 rounded-lg"
                    >
                      <div className="flex items-center gap-4">
                        <div className={`p-2 rounded-full ${
                          tx.type === 'buy' ? 'bg-blue-100 dark:bg-blue-900' :
                          tx.type === 'sell' ? 'bg-red-100 dark:bg-red-900' :
                          'bg-green-100 dark:bg-green-900'
                        }`}>
                          {tx.type === 'buy' ? (
                            <ArrowDownRight className="h-5 w-5 text-blue-600 dark:text-blue-400" />
                          ) : tx.type === 'sell' ? (
                            <ArrowUpRight className="h-5 w-5 text-red-600 dark:text-red-400" />
                          ) : (
                            <DollarSign className="h-5 w-5 text-green-600 dark:text-green-400" />
                          )}
                        </div>
                        <div>
                          <div className="font-medium dark:text-white capitalize">{tx.type} Tokens</div>
                          <div className="text-sm text-gray-600 dark:text-gray-400">{tx.property}</div>
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="font-semibold dark:text-white">
                          {tx.type === 'sell' ? '-' : '+'}{formatToken(tx.amount)} tokens
                        </div>
                        <div className="text-sm text-gray-600 dark:text-gray-400">
                          ${formatUSDC(tx.value)}
                        </div>
                        <div className="text-xs text-gray-500 dark:text-gray-500 flex items-center justify-end gap-1 mt-1">
                          <Clock className="h-3 w-3" />
                          {new Date(tx.timestamp * 1000).toLocaleDateString()}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </motion.div>
      </main>

      <Footer />
    </div>
  );
}
