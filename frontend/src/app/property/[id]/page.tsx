'use client';

import { useState, useEffect } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useActiveAccount } from "thirdweb/react";
import { prepareContractCall, sendTransaction, readContract } from "thirdweb";
import { useLandRegistryContract, usePrimaryMarketContract, useUSDCContract } from '@/hooks/useContracts';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import {
  MapPin, Building2, DollarSign, Calendar, User, FileText,
  TrendingUp, Clock, CheckCircle, Loader2, ArrowLeft, Share2,
  ShoppingCart, Info
} from 'lucide-react';
import Link from 'next/link';
import { formatUSDC, formatToken } from '@/utils/format';
import { toast } from 'sonner';
import { CONTRACT_ADDRESSES, TOKEN_PRICE } from '@/lib/config';
import { useRouter } from 'next/navigation';

interface PropertyDetails {
  propertyId: string;
  tokenAddress: string;
  owner: string;
  location: string;
  valuation: bigint;
  area: bigint;
  legalDescription: string;
  ownerName: string;
  coordinates: string;
  status: number;
  registrationTime: bigint;
  verificationTime: bigint;
  stakeAmount: bigint;

  // Sale info
  saleActive?: boolean;
  tokensForSale?: bigint;
  tokensSold?: bigint;
  pricePerToken?: bigint;
  saleEndTime?: bigint;
  totalSupply?: bigint;
}

export default function PropertyDetailPage({ params }: { params: { id: string } }) {
  const router = useRouter();
  const account = useActiveAccount();
  const landRegistry = useLandRegistryContract();
  const primaryMarket = usePrimaryMarketContract();
  const usdcContract = useUSDCContract();

  const [property, setProperty] = useState<PropertyDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [purchasing, setPurchasing] = useState(false);
  const [approving, setApproving] = useState(false);
  const [isApproved, setIsApproved] = useState(false);
  const [purchaseAmount, setPurchaseAmount] = useState('');
  const [timeRemaining, setTimeRemaining] = useState('');

  useEffect(() => {
    loadPropertyDetails();
  }, [params.id, account]);

  useEffect(() => {
    if (property?.saleEndTime) {
      const interval = setInterval(updateTimeRemaining, 1000);
      return () => clearInterval(interval);
    }
  }, [property]);

  async function loadPropertyDetails() {
    setLoading(true);

    try {
      // Demo data for now - replace with actual contract calls
      const demoProperty: PropertyDetails = {
        propertyId: params.id,
        tokenAddress: '0x123...',
        owner: '0xabc...',
        location: 'Downtown Manhattan, New York, NY 10001',
        valuation: BigInt(1500000 * 1e6),
        area: BigInt(2500),
        legalDescription: 'Commercial property located at the heart of Manhattan. Prime location with high foot traffic. Includes ground floor retail space and upper floor offices. Recently renovated with modern amenities.',
        ownerName: 'Manhattan Real Estate LLC',
        coordinates: '40.7589, -73.9851',
        status: 2,
        registrationTime: BigInt(Date.now() / 1000 - 86400 * 7),
        verificationTime: BigInt(Date.now() / 1000 - 86400 * 5),
        stakeAmount: BigInt(75000 * 1e6),

        saleActive: true,
        tokensForSale: BigInt(69750 * 1e18), // 46.5% of supply
        tokensSold: BigInt(31388 * 1e18), // 45% sold
        pricePerToken: BigInt(10 * 1e6), // 10 USDC
        saleEndTime: BigInt(Date.now() / 1000 + 86400 * 2), // 2 days from now
        totalSupply: BigInt(150000 * 1e18),
      };

      setProperty(demoProperty);
    } catch (error) {
      console.error('Error loading property:', error);
      toast.error('Failed to load property details');
    } finally {
      setLoading(false);
    }
  }

  function updateTimeRemaining() {
    if (!property?.saleEndTime) return;

    const now = Math.floor(Date.now() / 1000);
    const remaining = Number(property.saleEndTime) - now;

    if (remaining <= 0) {
      setTimeRemaining('Sale Ended');
      return;
    }

    const days = Math.floor(remaining / 86400);
    const hours = Math.floor((remaining % 86400) / 3600);
    const minutes = Math.floor((remaining % 3600) / 60);
    const seconds = remaining % 60;

    setTimeRemaining(`${days}d ${hours}h ${minutes}m ${seconds}s`);
  }

  async function handleApprove() {
    if (!account || !purchaseAmount) return;

    setApproving(true);

    try {
      const amount = BigInt(Math.floor(parseFloat(purchaseAmount) * 1e18));
      const cost = (amount * BigInt(TOKEN_PRICE * 1e6)) / BigInt(1e18);

      const transaction = prepareContractCall({
        contract: usdcContract,
        method: "function approve(address spender, uint256 amount) returns (bool)",
        params: [CONTRACT_ADDRESSES.primaryMarket, cost],
      });

      const { transactionHash } = await sendTransaction({
        transaction,
        account,
      });

      setIsApproved(true);
      toast.success(`USDC approved! TX: ${transactionHash.slice(0, 10)}...`);
    } catch (error: any) {
      console.error('Approval error:', error);
      toast.error(error.message || 'Failed to approve USDC');
    } finally {
      setApproving(false);
    }
  }

  async function handlePurchase() {
    if (!account || !property || !isApproved) return;

    setPurchasing(true);

    try {
      const amount = BigInt(Math.floor(parseFloat(purchaseAmount) * 1e18));

      const transaction = prepareContractCall({
        contract: primaryMarket,
        method: "function buyTokens(address tokenAddress, uint256 amount)",
        params: [property.tokenAddress, amount],
      });

      const { transactionHash } = await sendTransaction({
        transaction,
        account,
      });

      toast.success(`Tokens purchased! TX: ${transactionHash.slice(0, 10)}...`);
      setPurchaseAmount('');
      setIsApproved(false);
      loadPropertyDetails(); // Reload to update sale stats
    } catch (error: any) {
      console.error('Purchase error:', error);
      toast.error(error.message || 'Failed to purchase tokens');
    } finally {
      setPurchasing(false);
    }
  }

  const calculateCost = () => {
    if (!purchaseAmount) return '0.00';
    const tokens = parseFloat(purchaseAmount);
    return (tokens * TOKEN_PRICE).toFixed(2);
  };

  const getMaxPurchase = () => {
    if (!property) return '0';
    const available = property.tokensForSale! - property.tokensSold!;
    const maxPercent = property.tokensForSale! * BigInt(10) / BigInt(100); // 10% max
    const max = available < maxPercent ? available : maxPercent;
    return formatToken(max);
  };

  if (loading) {
    return (
      <div className="min-h-screen flex flex-col">
        <Navbar />
        <main className="flex-1 flex items-center justify-center">
          <Loader2 className="h-12 w-12 animate-spin text-primary-600" />
        </main>
        <Footer />
      </div>
    );
  }

  if (!property) {
    return (
      <div className="min-h-screen flex flex-col">
        <Navbar />
        <main className="flex-1 flex items-center justify-center">
          <div className="text-center">
            <h2 className="text-2xl font-bold mb-4">Property Not Found</h2>
            <Link href="/marketplace">
              <Button>Back to Marketplace</Button>
            </Link>
          </div>
        </main>
        <Footer />
      </div>
    );
  }

  const soldPercentage = property.saleActive
    ? Number((property.tokensSold! * BigInt(100)) / property.tokensForSale!)
    : 0;

  return (
    <div className="min-h-screen flex flex-col bg-gray-50">
      <Navbar />

      <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 w-full">
        {/* Back Button */}
        <motion.div
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          className="mb-6"
        >
          <Link href="/marketplace">
            <Button variant="ghost" className="gap-2">
              <ArrowLeft className="h-4 w-4" />
              Back to Marketplace
            </Button>
          </Link>
        </motion.div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column - Property Details */}
          <div className="lg:col-span-2 space-y-6">
            {/* Hero Image */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
            >
              <Card className="overflow-hidden">
                <div className="h-96 bg-gradient-to-br from-primary-400 via-primary-500 to-primary-600 relative">
                  <div className="absolute inset-0 bg-black/10" />
                  <div className="absolute bottom-6 left-6 right-6">
                    <h1 className="text-4xl font-bold text-white mb-2">
                      {property.location.split(',')[0]}
                    </h1>
                    <p className="text-white/90 flex items-center gap-2">
                      <MapPin className="h-5 w-5" />
                      {property.location}
                    </p>
                  </div>

                  {property.saleActive && (
                    <div className="absolute top-6 right-6">
                      <span className="px-4 py-2 bg-green-500 text-white rounded-full font-semibold flex items-center gap-2">
                        <TrendingUp className="h-4 w-4" />
                        Active Sale
                      </span>
                    </div>
                  )}
                </div>
              </Card>
            </motion.div>

            {/* Property Info Grid */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 }}
            >
              <Card>
                <CardHeader>
                  <CardTitle>Property Information</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="grid grid-cols-2 md:grid-cols-3 gap-6">
                    <div>
                      <div className="flex items-center gap-2 text-gray-600 mb-1">
                        <DollarSign className="h-4 w-4" />
                        <span className="text-sm">Valuation</span>
                      </div>
                      <p className="text-2xl font-bold">{formatUSDC(property.valuation)}</p>
                    </div>

                    <div>
                      <div className="flex items-center gap-2 text-gray-600 mb-1">
                        <Building2 className="h-4 w-4" />
                        <span className="text-sm">Area</span>
                      </div>
                      <p className="text-2xl font-bold">{property.area.toString()} m²</p>
                    </div>

                    <div>
                      <div className="flex items-center gap-2 text-gray-600 mb-1">
                        <DollarSign className="h-4 w-4" />
                        <span className="text-sm">Token Price</span>
                      </div>
                      <p className="text-2xl font-bold">{TOKEN_PRICE} USDC</p>
                    </div>

                    <div>
                      <div className="flex items-center gap-2 text-gray-600 mb-1">
                        <User className="h-4 w-4" />
                        <span className="text-sm">Owner</span>
                      </div>
                      <p className="font-semibold">{property.ownerName}</p>
                    </div>

                    <div>
                      <div className="flex items-center gap-2 text-gray-600 mb-1">
                        <Calendar className="h-4 w-4" />
                        <span className="text-sm">Registered</span>
                      </div>
                      <p className="font-semibold">
                        {new Date(Number(property.registrationTime) * 1000).toLocaleDateString()}
                      </p>
                    </div>

                    <div>
                      <div className="flex items-center gap-2 text-gray-600 mb-1">
                        <CheckCircle className="h-4 w-4" />
                        <span className="text-sm">Verified</span>
                      </div>
                      <p className="font-semibold">
                        {new Date(Number(property.verificationTime) * 1000).toLocaleDateString()}
                      </p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </motion.div>

            {/* Description */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
            >
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <FileText className="h-5 w-5" />
                    Legal Description
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-gray-700 leading-relaxed">
                    {property.legalDescription}
                  </p>

                  <div className="mt-6 pt-6 border-t">
                    <h4 className="font-semibold mb-2">Coordinates</h4>
                    <p className="text-gray-600">{property.coordinates}</p>
                  </div>
                </CardContent>
              </Card>
            </motion.div>
          </div>

          {/* Right Column - Purchase Card */}
          <div className="lg:col-span-1">
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              className="sticky top-24"
            >
              <Card className="border-2 border-primary-200">
                <CardHeader className="bg-primary-50">
                  <CardTitle className="flex items-center gap-2">
                    <ShoppingCart className="h-5 w-5" />
                    Purchase Tokens
                  </CardTitle>
                  <CardDescription>
                    Buy ownership tokens in this property
                  </CardDescription>
                </CardHeader>

                <CardContent className="pt-6">
                  {property.saleActive ? (
                    <div className="space-y-6">
                      {/* Sale Timer */}
                      <div className="bg-gradient-to-r from-primary-50 to-primary-100 rounded-lg p-4">
                        <div className="flex items-center gap-2 text-primary-700 mb-2">
                          <Clock className="h-4 w-4" />
                          <span className="text-sm font-medium">Sale Ends In</span>
                        </div>
                        <p className="text-2xl font-bold text-primary-900">
                          {timeRemaining}
                        </p>
                      </div>

                      {/* Sale Progress */}
                      <div>
                        <div className="flex justify-between text-sm mb-2">
                          <span className="text-gray-600">Sale Progress</span>
                          <span className="font-semibold">{soldPercentage}%</span>
                        </div>
                        <div className="w-full bg-gray-200 rounded-full h-3">
                          <motion.div
                            initial={{ width: 0 }}
                            animate={{ width: `${soldPercentage}%` }}
                            transition={{ duration: 1 }}
                            className="bg-primary-600 h-3 rounded-full"
                          />
                        </div>
                        <div className="flex justify-between text-xs text-gray-500 mt-1">
                          <span>{formatToken(property.tokensSold!)} sold</span>
                          <span>{formatToken(property.tokensForSale!)} total</span>
                        </div>
                      </div>

                      {/* Purchase Form */}
                      {account ? (
                        <div className="space-y-4">
                          <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                              Token Amount
                            </label>
                            <input
                              type="number"
                              value={purchaseAmount}
                              onChange={(e) => setPurchaseAmount(e.target.value)}
                              placeholder="0.00"
                              step="0.01"
                              min="1"
                              max={getMaxPurchase()}
                              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent text-lg"
                            />
                            <p className="text-xs text-gray-500 mt-1">
                              Max: {getMaxPurchase()} tokens (10% limit per buyer)
                            </p>
                          </div>

                          <div className="bg-gray-50 rounded-lg p-4">
                            <div className="flex justify-between mb-2">
                              <span className="text-gray-600">Token Price</span>
                              <span className="font-semibold">{TOKEN_PRICE} USDC</span>
                            </div>
                            <div className="flex justify-between text-lg font-bold border-t pt-2">
                              <span>Total Cost</span>
                              <span className="text-primary-600">{calculateCost()} USDC</span>
                            </div>
                          </div>

                          <div className="space-y-3">
                            <Button
                              onClick={handleApprove}
                              disabled={!purchaseAmount || parseFloat(purchaseAmount) <= 0 || approving || isApproved}
                              className="w-full"
                              variant="secondary"
                            >
                              {approving ? (
                                <>
                                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                  Approving...
                                </>
                              ) : isApproved ? (
                                <>
                                  <CheckCircle className="mr-2 h-4 w-4" />
                                  Approved
                                </>
                              ) : (
                                '1. Approve USDC'
                              )}
                            </Button>

                            <Button
                              onClick={handlePurchase}
                              disabled={!isApproved || purchasing}
                              className="w-full"
                            >
                              {purchasing ? (
                                <>
                                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                  Purchasing...
                                </>
                              ) : (
                                '2. Purchase Tokens'
                              )}
                            </Button>
                          </div>

                          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                            <div className="flex gap-2">
                              <Info className="h-4 w-4 text-blue-600 flex-shrink-0 mt-0.5" />
                              <div className="text-xs text-blue-800">
                                <p className="font-semibold mb-1">Important:</p>
                                <ul className="space-y-1">
                                  <li>• Minimum purchase: 1 token</li>
                                  <li>• Maximum: 10% of total sale</li>
                                  <li>• Tokens unlock after 180 days</li>
                                </ul>
                              </div>
                            </div>
                          </div>
                        </div>
                      ) : (
                        <div className="text-center py-6">
                          <p className="text-gray-600 mb-4">
                            Connect your wallet to purchase tokens
                          </p>
                        </div>
                      )}
                    </div>
                  ) : (
                    <div className="text-center py-6">
                      <p className="text-gray-600">
                        Sale not active for this property
                      </p>
                    </div>
                  )}
                </CardContent>
              </Card>
            </motion.div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}
