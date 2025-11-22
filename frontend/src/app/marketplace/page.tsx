'use client';

import { useState, useEffect } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useActiveAccount } from "thirdweb/react";
import { readContract } from "thirdweb";
import { useLandRegistryContract, usePrimaryMarketContract } from '@/hooks/useContracts';
import { motion, AnimatePresence } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Search, Filter, MapPin, TrendingUp, Building2, DollarSign, Calendar } from 'lucide-react';
import Link from 'next/link';
import { formatUSDC } from '@/utils/format';
import { toast } from 'sonner';

interface Property {
  propertyId: string;
  tokenAddress: string;
  owner: string;
  location: string;
  valuation: bigint;
  area: bigint;
  status: number;
  registrationTime: bigint;
  tokensSold?: number;
  saleActive?: boolean;
}

export default function MarketplacePage() {
  const account = useActiveAccount();
  const landRegistry = useLandRegistryContract();
  const primaryMarket = usePrimaryMarketContract();

  const [properties, setProperties] = useState<Property[]>([]);
  const [filteredProperties, setFilteredProperties] = useState<Property[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [sortBy, setSortBy] = useState<'newest' | 'valuation' | 'area'>('newest');

  useEffect(() => {
    loadProperties();
  }, [account]);

  useEffect(() => {
    filterAndSortProperties();
  }, [properties, searchTerm, statusFilter, sortBy]);

  async function loadProperties() {
    if (!account) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);

      // Get all token addresses from LandRegistry
      const tokens = await readContract({
        contract: landRegistry,
        method: "function getAllTokens() view returns (address[])",
        params: [],
      }) as string[];

      console.log('Found tokens:', tokens);

      if (tokens.length === 0) {
        setProperties([]);
        setLoading(false);
        return;
      }

      // Load property data for each token
      const loadedProperties: Property[] = [];

      for (const tokenAddress of tokens) {
        try {
          // Get property ID from token address mapping
          const propertyId = await readContract({
            contract: landRegistry,
            method: "function tokenToProperty(address) view returns (bytes32)",
            params: [tokenAddress],
          }) as string;

          // Get property details
          const propertyData = await readContract({
            contract: landRegistry,
            method: "function properties(bytes32) view returns (address owner, tuple(string location, uint256 valuation, uint256 area, string legalDescription, string ownerName, string coordinates) metadata, uint8 status, address tokenAddress, uint256 registrationTime, uint256 verificationTime, uint256 stakeAmount)",
            params: [propertyId],
          }) as any;

          // Get sale info from PrimaryMarket
          let saleInfo: any = null;
          let tokensSoldPercent = 0;
          let saleActive = false;

          try {
            saleInfo = await readContract({
              contract: primaryMarket,
              method: "function sales(address) view returns (address tokenAddress, uint256 tokensForSale, uint256 tokensSold, uint256 pricePerToken, uint256 startTime, uint256 endTime, address beneficiary, bool active, bool finalized)",
              params: [tokenAddress],
            }) as any;

            if (saleInfo && saleInfo.active) {
              saleActive = true;
              tokensSoldPercent = Number((BigInt(saleInfo.tokensSold) * BigInt(100)) / BigInt(saleInfo.tokensForSale));
            }
          } catch (e) {
            // Sale might not exist
            console.log('No sale data for', tokenAddress);
          }

          loadedProperties.push({
            propertyId,
            tokenAddress,
            owner: propertyData.owner,
            location: propertyData.metadata.location,
            valuation: BigInt(propertyData.metadata.valuation),
            area: BigInt(propertyData.metadata.area),
            status: propertyData.status,
            registrationTime: BigInt(propertyData.registrationTime),
            tokensSold: tokensSoldPercent,
            saleActive,
          });
        } catch (error) {
          console.error('Error loading property:', tokenAddress, error);
        }
      }

      setProperties(loadedProperties);
      toast.success(`Loaded ${loadedProperties.length} properties`);
    } catch (error: any) {
      console.error('Error loading properties:', error);
      toast.error('Failed to load properties');
    } finally {
      setLoading(false);
    }
  }

  function filterAndSortProperties() {
    let filtered = [...properties];

    if (searchTerm) {
      filtered = filtered.filter(p =>
        p.location.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    if (statusFilter !== 'all') {
      const statusMap: { [key: string]: number } = {
        'pending': 1,
        'verified': 2,
        'active': 2,
      };
      filtered = filtered.filter(p => p.status === statusMap[statusFilter]);
    }

    filtered.sort((a, b) => {
      switch (sortBy) {
        case 'newest':
          return Number(b.registrationTime - a.registrationTime);
        case 'valuation':
          return Number(b.valuation - a.valuation);
        case 'area':
          return Number(b.area - a.area);
        default:
          return 0;
      }
    });

    setFilteredProperties(filtered);
  }

  const getStatusBadge = (status: number) => {
    const badges = {
      1: { text: 'Pending', class: 'bg-yellow-100 text-yellow-800' },
      2: { text: 'Verified', class: 'bg-green-100 text-green-800' },
      3: { text: 'Rejected', class: 'bg-red-100 text-red-800' },
      5: { text: 'Tokenized', class: 'bg-blue-100 text-blue-800' },
    };
    return badges[status as keyof typeof badges] || { text: 'Unknown', class: 'bg-gray-100 text-gray-800' };
  };

  return (
    <div className="min-h-screen flex flex-col bg-gray-50">
      <Navbar />

      <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 w-full">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8"
        >
          <h1 className="text-4xl font-bold text-gray-900 mb-2">
            Property Marketplace
          </h1>
          <p className="text-gray-600">
            Browse and invest in tokenized real-world assets
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="bg-white rounded-lg shadow-sm p-6 mb-8"
        >
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="md:col-span-2">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
                <input
                  type="text"
                  placeholder="Search by location..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                />
              </div>
            </div>

            <div>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              >
                <option value="all">All Status</option>
                <option value="pending">Pending</option>
                <option value="verified">Verified</option>
                <option value="active">Active Sale</option>
              </select>
            </div>

            <div>
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as any)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              >
                <option value="newest">Newest First</option>
                <option value="valuation">Highest Value</option>
                <option value="area">Largest Area</option>
              </select>
            </div>
          </div>

          <div className="mt-4 flex items-center gap-4 text-sm text-gray-600">
            <span className="flex items-center gap-2">
              <Filter className="h-4 w-4" />
              {filteredProperties.length} properties found
            </span>
          </div>
        </motion.div>

        {!account ? (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="bg-white rounded-lg shadow-sm p-12 text-center"
          >
            <Building2 className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold mb-2">Connect Your Wallet</h3>
            <p className="text-gray-600">
              Please connect your wallet to view available properties
            </p>
          </motion.div>
        ) : loading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[1, 2, 3, 4, 5, 6].map((i) => (
              <Card key={i} className="animate-pulse">
                <div className="h-48 bg-gradient-to-br from-gray-200 to-gray-300 rounded-t-lg"></div>
                <CardHeader>
                  <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
                  <div className="h-3 bg-gray-200 rounded w-1/2"></div>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    <div className="h-3 bg-gray-200 rounded"></div>
                    <div className="h-3 bg-gray-200 rounded w-5/6"></div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        ) : filteredProperties.length === 0 ? (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="bg-white rounded-lg shadow-sm p-12 text-center"
          >
            <Building2 className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold mb-2">No Properties Found</h3>
            <p className="text-gray-600 mb-6">
              Try adjusting your filters or search terms
            </p>
            <Button onClick={() => { setSearchTerm(''); setStatusFilter('all'); }}>
              Clear Filters
            </Button>
          </motion.div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <AnimatePresence>
              {filteredProperties.map((property, index) => (
                <PropertyCard
                  key={property.propertyId}
                  property={property}
                  index={index}
                  statusBadge={getStatusBadge(property.status)}
                />
              ))}
            </AnimatePresence>
          </div>
        )}
      </main>

      <Footer />
    </div>
  );
}

interface PropertyCardProps {
  property: Property;
  index: number;
  statusBadge: { text: string; class: string };
}

function PropertyCard({ property, index, statusBadge }: PropertyCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ delay: index * 0.05 }}
      whileHover={{ y: -8 }}
      className="group"
    >
      <Link href={`/property/${property.propertyId}`}>
        <Card className="overflow-hidden cursor-pointer transition-shadow hover:shadow-2xl">
          <div className="h-48 bg-gradient-to-br from-primary-400 via-primary-500 to-primary-600 relative overflow-hidden">
            <motion.div
              className="absolute inset-0 bg-black/20"
              whileHover={{ opacity: 0 }}
              transition={{ duration: 0.3 }}
            />
            <div className="absolute top-4 right-4">
              <span className={`px-3 py-1 rounded-full text-xs font-medium ${statusBadge.class}`}>
                {statusBadge.text}
              </span>
            </div>
            {property.saleActive && (
              <div className="absolute top-4 left-4">
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-green-500 text-white flex items-center gap-1">
                  <TrendingUp className="h-3 w-3" />
                  Active Sale
                </span>
              </div>
            )}
          </div>

          <CardHeader>
            <CardTitle className="text-xl group-hover:text-primary-600 transition">
              {property.location.split(',')[0]}
            </CardTitle>
            <CardDescription className="flex items-center gap-1">
              <MapPin className="h-3 w-3" />
              {property.location}
            </CardDescription>
          </CardHeader>

          <CardContent>
            <div className="space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600 flex items-center gap-1">
                  <DollarSign className="h-4 w-4" />
                  Valuation
                </span>
                <span className="font-semibold text-gray-900">
                  {formatUSDC(property.valuation)}
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600 flex items-center gap-1">
                  <Building2 className="h-4 w-4" />
                  Area
                </span>
                <span className="font-semibold text-gray-900">
                  {property.area.toString()} m²
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600 flex items-center gap-1">
                  <Calendar className="h-4 w-4" />
                  Registered
                </span>
                <span className="text-sm text-gray-600">
                  {new Date(Number(property.registrationTime) * 1000).toLocaleDateString()}
                </span>
              </div>

              {property.saleActive && property.tokensSold !== undefined && (
                <div className="pt-3 border-t">
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-gray-600">Tokens Sold</span>
                    <span className="font-semibold">{property.tokensSold}%</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${property.tokensSold}%` }}
                      transition={{ duration: 1, delay: index * 0.1 }}
                      className="bg-primary-600 h-2 rounded-full"
                    />
                  </div>
                </div>
              )}
            </div>

            <Button className="w-full mt-4 group-hover:bg-primary-700 transition">
              View Details
            </Button>
          </CardContent>
        </Card>
      </Link>
    </motion.div>
  );
}
