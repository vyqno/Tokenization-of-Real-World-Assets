'use client';

import { useState, useEffect } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { TrendingUp, Building2, DollarSign, Users, Activity, ArrowUpRight, ArrowDownRight } from 'lucide-react';
import {
  LineChart, Line, BarChart, Bar, AreaChart, Area,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend
} from 'recharts';

export default function AnalyticsPage() {
  const [tvlData] = useState([
    { date: 'Jan', value: 1200000 },
    { date: 'Feb', value: 1450000 },
    { date: 'Mar', value: 1580000 },
    { date: 'Apr', value: 1920000 },
    { date: 'May', value: 2150000 },
    { date: 'Jun', value: 2450000 },
    { date: 'Jul', value: 2680000 },
  ]);

  const [registrationsData] = useState([
    { month: 'Jan', properties: 12 },
    { month: 'Feb', properties: 18 },
    { month: 'Mar', properties: 25 },
    { month: 'Apr', properties: 32 },
    { month: 'May', properties: 28 },
    { month: 'Jun', properties: 35 },
    { month: 'Jul', properties: 42 },
  ]);

  const [volumeData] = useState([
    { day: 'Mon', volume: 125000 },
    { day: 'Tue', volume: 148000 },
    { day: 'Wed', volume: 132000 },
    { day: 'Thu', volume: 165000 },
    { day: 'Fri', volume: 189000 },
    { day: 'Sat', volume: 142000 },
    { day: 'Sun', volume: 156000 },
  ]);

  const stats = {
    tvl: 2680000,
    tvlChange: 9.4,
    totalProperties: 192,
    propertiesChange: 5,
    activeInvestors: 1247,
    investorsChange: 83,
    volume24h: 156000,
    volumeChange: -12.3,
  };

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
