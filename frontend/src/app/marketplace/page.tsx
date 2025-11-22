'use client';

import { useState } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useAccount, useReadContract } from 'wagmi';
import { contractAddresses } from '@/lib/contracts';
import LandRegistryABI from '@/contracts/abis/LandRegistry.json';
import { MapPin, TrendingUp, Clock, Building2 } from 'lucide-react';
import Link from 'next/link';

export default function MarketplacePage() {
  const { isConnected } = useAccount();
  const [filter, setFilter] = useState<'all' | 'active' | 'verified' | 'pending'>('all');

  // Read all tokens from registry
  const { data: allTokens, isLoading } = useReadContract({
    address: contractAddresses.landRegistry,
    abi: LandRegistryABI,
    functionName: 'getAllTokens',
  });

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />

      <main className="flex-1 bg-gray-50 py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="mb-8">
            <h1 className="text-4xl font-bold mb-2">Property Marketplace</h1>
            <p className="text-gray-600">
              Browse and invest in tokenized real-world assets
            </p>
          </div>

          {/* Filters */}
          <div className="bg-white rounded-lg shadow-sm p-4 mb-8">
            <div className="flex flex-wrap gap-3">
              <button
                onClick={() => setFilter('all')}
                className={`px-4 py-2 rounded-lg font-medium transition ${
                  filter === 'all'
                    ? 'bg-primary-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                All Properties
              </button>
              <button
                onClick={() => setFilter('active')}
                className={`px-4 py-2 rounded-lg font-medium transition ${
                  filter === 'active'
                    ? 'bg-primary-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                Active Sales
              </button>
              <button
                onClick={() => setFilter('verified')}
                className={`px-4 py-2 rounded-lg font-medium transition ${
                  filter === 'verified'
                    ? 'bg-primary-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                Verified
              </button>
              <button
                onClick={() => setFilter('pending')}
                className={`px-4 py-2 rounded-lg font-medium transition ${
                  filter === 'pending'
                    ? 'bg-primary-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                Pending Verification
              </button>
            </div>
          </div>

          {/* Property Grid */}
          {isLoading ? (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
              <p className="mt-4 text-gray-600">Loading properties...</p>
            </div>
          ) : !isConnected ? (
            <div className="bg-white rounded-lg shadow-sm p-12 text-center">
              <Building2 className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-xl font-semibold mb-2">Connect Your Wallet</h3>
              <p className="text-gray-600 mb-6">
                Please connect your wallet to view available properties
              </p>
            </div>
          ) : !allTokens || (allTokens as any[]).length === 0 ? (
            <div className="bg-white rounded-lg shadow-sm p-12 text-center">
              <Building2 className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-xl font-semibold mb-2">No Properties Yet</h3>
              <p className="text-gray-600 mb-6">
                Be the first to tokenize a property on our platform
              </p>
              <Link
                href="/register"
                className="inline-block bg-primary-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-primary-700 transition"
              >
                Register Property
              </Link>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {/* Example Property Card - In production, map over allTokens */}
              <PropertyCard
                name="Downtown Commercial Property"
                location="123 Main St, New York, NY"
                valuation="$1,500,000"
                tokenPrice="10 USDC"
                status="active"
                endTime={new Date(Date.now() + 2 * 24 * 60 * 60 * 1000)}
                area="2,500 sq m"
                tokensSold={35}
              />

              <PropertyCard
                name="Suburban Residential Land"
                location="456 Oak Ave, Los Angeles, CA"
                valuation="$850,000"
                tokenPrice="10 USDC"
                status="verified"
                endTime={new Date(Date.now() + 5 * 24 * 60 * 60 * 1000)}
                area="1,800 sq m"
                tokensSold={22}
              />

              <PropertyCard
                name="Industrial Warehouse"
                location="789 Industrial Pkwy, Chicago, IL"
                valuation="$2,200,000"
                tokenPrice="10 USDC"
                status="pending"
                endTime={new Date(Date.now() + 1 * 24 * 60 * 60 * 1000)}
                area="5,000 sq m"
                tokensSold={18}
              />
            </div>
          )}
        </div>
      </main>

      <Footer />
    </div>
  );
}

interface PropertyCardProps {
  name: string;
  location: string;
  valuation: string;
  tokenPrice: string;
  status: 'active' | 'verified' | 'pending';
  endTime: Date;
  area: string;
  tokensSold: number;
}

function PropertyCard({
  name,
  location,
  valuation,
  tokenPrice,
  status,
  endTime,
  area,
  tokensSold,
}: PropertyCardProps) {
  const getStatusBadge = () => {
    switch (status) {
      case 'active':
        return <span className="bg-green-100 text-green-800 px-3 py-1 rounded-full text-sm font-medium">Active Sale</span>;
      case 'verified':
        return <span className="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm font-medium">Verified</span>;
      case 'pending':
        return <span className="bg-yellow-100 text-yellow-800 px-3 py-1 rounded-full text-sm font-medium">Pending</span>;
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-sm hover:shadow-xl transition-shadow overflow-hidden card-hover">
      <div className="h-48 bg-gradient-to-br from-primary-400 to-primary-600"></div>

      <div className="p-6">
        <div className="flex justify-between items-start mb-3">
          <h3 className="text-xl font-bold">{name}</h3>
          {getStatusBadge()}
        </div>

        <div className="space-y-3 mb-4">
          <div className="flex items-center text-gray-600">
            <MapPin className="h-4 w-4 mr-2 flex-shrink-0" />
            <span className="text-sm">{location}</span>
          </div>

          <div className="flex items-center text-gray-600">
            <Building2 className="h-4 w-4 mr-2 flex-shrink-0" />
            <span className="text-sm">{area}</span>
          </div>

          <div className="flex items-center text-gray-600">
            <Clock className="h-4 w-4 mr-2 flex-shrink-0" />
            <span className="text-sm">
              Ends: {endTime.toLocaleDateString()}
            </span>
          </div>
        </div>

        <div className="border-t pt-4 space-y-2">
          <div className="flex justify-between">
            <span className="text-gray-600">Valuation</span>
            <span className="font-semibold">{valuation}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-600">Token Price</span>
            <span className="font-semibold">{tokenPrice}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-600">Sold</span>
            <span className="font-semibold">{tokensSold}%</span>
          </div>
        </div>

        <div className="mt-4">
          <div className="w-full bg-gray-200 rounded-full h-2 mb-4">
            <div
              className="bg-primary-600 h-2 rounded-full"
              style={{ width: `${tokensSold}%` }}
            ></div>
          </div>
        </div>

        <Link
          href={`/property/${name.toLowerCase().replace(/\s+/g, '-')}`}
          className="block w-full bg-primary-600 text-white text-center px-4 py-3 rounded-lg font-semibold hover:bg-primary-700 transition"
        >
          View Details
        </Link>
      </div>
    </div>
  );
}
