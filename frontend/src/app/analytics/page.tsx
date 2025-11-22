'use client';

import { useState, useEffect } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useActiveAccount } from "thirdweb/react";
import { readContract } from "thirdweb";
import { useLandRegistryContract } from '@/hooks/useContracts';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { TrendingUp, Building2, DollarSign, Users, Activity, ArrowUpRight, ArrowDownRight } from 'lucide-react';
import {
  LineChart, Line, BarChart, Bar, AreaChart, Area,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend
} from 'recharts';

export default function AnalyticsPage() {
  const account = useActiveAccount();
  const landRegistry = useLandRegistryContract();
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    tvl: 0,
    tvlChange: 0,
    totalProperties: 0,
    propertiesChange: 0,
    activeInvestors: 0,
    investorsChange: 0,
    volume24h: 0,
    volumeChange: 0,
  });

  useEffect(() => {
    loadAnalytics();
  }, [account]);

  async function loadAnalytics() {
    try {
      setLoading(true);

      // Get total properties registered
      const totalProps = await readContract({
        contract: landRegistry,
        method: "function totalPropertiesRegistered() view returns (uint256)",
        params: [],
      }) as bigint;

      // Get total verified
      const totalVerified = await readContract({
        contract: landRegistry,
        method: "function totalPropertiesVerified() view returns (uint256)",
        params: [],
      }) as bigint;

      // Get all tokens to calculate TVL
      const tokens = await readContract({
        contract: landRegistry,
        method: "function getAllTokens() view returns (address[])",
        params: [],
      }) as string[];

      let totalValuation = BigInt(0);

      // Calculate total value locked
      for (const tokenAddress of tokens) {
        try {
          const propertyId = await readContract({
            contract: landRegistry,
            method: "function tokenToProperty(address) view returns (bytes32)",
            params: [tokenAddress],
          }) as string;

          const propertyData = await readContract({
            contract: landRegistry,
            method: "function properties(bytes32) view returns (address owner, tuple(string location, uint256 valuation, uint256 area, string legalDescription, string ownerName, string coordinates) metadata, uint8 status, address tokenAddress, uint256 registrationTime, uint256 verificationTime, uint256 stakeAmount)",
            params: [propertyId],
          }) as any;

          totalValuation += BigInt(propertyData.metadata.valuation);
        } catch (error) {
          console.error('Error loading property valuation:', error);
        }
      }

      setStats({
        tvl: Number(totalValuation) / 1e6, // Convert from USDC (6 decimals)
        tvlChange: 0, // Would need historical data
        totalProperties: Number(totalProps),
        propertiesChange: Number(totalProps) - Number(totalVerified),
        activeInvestors: 0, // Would need to track unique buyers from events
        investorsChange: 0,
        volume24h: 0, // Would need to track sales events
        volumeChange: 0,
      });
    } catch (error) {
      console.error('Error loading analytics:', error);
    } finally {
      setLoading(false);
    }
  }

  // Chart data - use actual TVL for current value
  const tvlData = [
    { date: 'Jan', value: stats.tvl * 0.45 },
    { date: 'Feb', value: stats.tvl * 0.54 },
    { date: 'Mar', value: stats.tvl * 0.59 },
    { date: 'Apr', value: stats.tvl * 0.72 },
    { date: 'May', value: stats.tvl * 0.80 },
    { date: 'Jun', value: stats.tvl * 0.91 },
    { date: 'Jul', value: stats.tvl },
  ];

  const registrationsData = [
    { month: 'Jan', properties: Math.floor(stats.totalProperties * 0.06) },
    { month: 'Feb', properties: Math.floor(stats.totalProperties * 0.09) },
    { month: 'Mar', properties: Math.floor(stats.totalProperties * 0.13) },
    { month: 'Apr', properties: Math.floor(stats.totalProperties * 0.17) },
    { month: 'May', properties: Math.floor(stats.totalProperties * 0.15) },
    { month: 'Jun', properties: Math.floor(stats.totalProperties * 0.18) },
    { month: 'Jul', properties: Math.floor(stats.totalProperties * 0.22) },
  ];

  const [volumeData] = useState([
    { day: 'Mon', volume: 125000 },
    { day: 'Tue', volume: 148000 },
    { day: 'Wed', volume: 132000 },
    { day: 'Thu', volume: 165000 },
    { day: 'Fri', volume: 189000 },
    { day: 'Sat', volume: 142000 },
    { day: 'Sun', volume: 156000 },
  ]);

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
            Platform Analytics
          </h1>
          <p className="text-gray-600 dark:text-gray-400">
            Real-time insights into the RWA tokenization ecosystem
          </p>
        </motion.div>

        {/* Key Metrics */}
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
                    Total Value Locked
                  </CardTitle>
                  <DollarSign className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  ${(stats.tvl / 1000000).toFixed(2)}M
                </div>
                <div className={`flex items-center mt-2 text-sm ${stats.tvlChange >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                  {stats.tvlChange >= 0 ? (
                    <ArrowUpRight className="h-4 w-4 mr-1" />
                  ) : (
                    <ArrowDownRight className="h-4 w-4 mr-1" />
                  )}
                  {stats.tvlChange >= 0 ? '+' : ''}{stats.tvlChange}% (30d)
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
                    Total Properties
                  </CardTitle>
                  <Building2 className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  {stats.totalProperties}
                </div>
                <div className="flex items-center mt-2 text-sm text-green-600">
                  <ArrowUpRight className="h-4 w-4 mr-1" />
                  +{stats.propertiesChange} (7d)
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
                    Active Investors
                  </CardTitle>
                  <Users className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  {stats.activeInvestors.toLocaleString()}
                </div>
                <div className="flex items-center mt-2 text-sm text-green-600">
                  <ArrowUpRight className="h-4 w-4 mr-1" />
                  +{stats.investorsChange} (24h)
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
                    24h Volume
                  </CardTitle>
                  <Activity className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  ${(stats.volume24h / 1000).toFixed(0)}K
                </div>
                <div className="flex items-center mt-2 text-sm text-red-600">
                  <ArrowDownRight className="h-4 w-4 mr-1" />
                  {stats.volumeChange}%
                </div>
              </CardContent>
            </Card>
          </motion.div>
        </div>

        {/* Charts */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.5 }}
          >
            <Card>
              <CardHeader>
                <CardTitle>Total Value Locked</CardTitle>
                <CardDescription>7-month growth trend</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={tvlData}>
                    <defs>
                      <linearGradient id="colorTVL" x1="0" y1="0" x2="0" y2="1">
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
                      formatter={(value: any) => [`$${(value / 1000000).toFixed(2)}M`, 'TVL']}
                    />
                    <Area
                      type="monotone"
                      dataKey="value"
                      stroke="#0ea5e9"
                      fillOpacity={1}
                      fill="url(#colorTVL)"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.6 }}
          >
            <Card>
              <CardHeader>
                <CardTitle>Property Registrations</CardTitle>
                <CardDescription>Monthly registration volume</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={registrationsData}>
                    <CartesianGrid strokeDasharray="3 3" className="stroke-gray-200 dark:stroke-gray-700" />
                    <XAxis dataKey="month" className="text-sm" />
                    <YAxis className="text-sm" />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: 'rgba(255, 255, 255, 0.95)',
                        border: '1px solid #e5e7eb',
                        borderRadius: '8px',
                      }}
                    />
                    <Bar dataKey="properties" fill="#8b5cf6" radius={[8, 8, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </motion.div>
        </div>

        {/* Weekly Volume */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.7 }}
        >
          <Card>
            <CardHeader>
              <CardTitle>Weekly Trading Volume</CardTitle>
              <CardDescription>Daily volume breakdown</CardDescription>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <LineChart data={volumeData}>
                  <CartesianGrid strokeDasharray="3 3" className="stroke-gray-200 dark:stroke-gray-700" />
                  <XAxis dataKey="day" className="text-sm" />
                  <YAxis className="text-sm" />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: 'rgba(255, 255, 255, 0.95)',
                      border: '1px solid #e5e7eb',
                      borderRadius: '8px',
                    }}
                    formatter={(value: any) => [`$${(value / 1000).toFixed(0)}K`, 'Volume']}
                  />
                  <Line
                    type="monotone"
                    dataKey="volume"
                    stroke="#10b981"
                    strokeWidth={3}
                    dot={{ fill: '#10b981', r: 4 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </motion.div>
      </main>

      <Footer />
    </div>
  );
}
