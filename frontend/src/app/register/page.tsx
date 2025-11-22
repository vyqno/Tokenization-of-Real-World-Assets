'use client';

import { useState } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useAccount, useWriteContract, useReadContract } from 'wagmi';
import { parseUSDC } from '@/utils/format';
import { contractAddresses } from '@/lib/contracts';
import LandRegistryABI from '@/contracts/abis/LandRegistry.json';
import USDCABI from '@/contracts/abis/USDC.json';
import { AlertCircle, CheckCircle, Loader2 } from 'lucide-react';

export default function RegisterPage() {
  const { address, isConnected } = useAccount();
  const { writeContract, isPending: isRegistering } = useWriteContract();

  const [formData, setFormData] = useState({
    location: '',
    valuation: '',
    area: '',
    legalDescription: '',
    ownerName: '',
    coordinates: '',
  });

  const [status, setStatus] = useState<{
    type: 'success' | 'error' | null;
    message: string;
  }>({ type: null, message: '' });

  const handleInputChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>
  ) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const calculateMinStake = (valuation: string): bigint => {
    if (!valuation) return BigInt(0);
    const val = parseUSDC(valuation);
    return (val * BigInt(5)) / BigInt(100); // 5% of valuation
  };

  const handleApprove = async () => {
    if (!formData.valuation) return;

    const minStake = calculateMinStake(formData.valuation);

    try {
      await writeContract({
        address: contractAddresses.usdc,
        abi: USDCABI,
        functionName: 'approve',
        args: [contractAddresses.stakingVault, minStake],
      });

      setStatus({
        type: 'success',
        message: 'USDC approved! You can now register the property.',
      });
    } catch (error: any) {
      setStatus({
        type: 'error',
        message: error.message || 'Failed to approve USDC',
      });
    }
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!isConnected) {
      setStatus({ type: 'error', message: 'Please connect your wallet' });
      return;
    }

    try {
      const metadata = {
        location: formData.location,
        valuation: parseUSDC(formData.valuation),
        area: BigInt(formData.area),
        legalDescription: formData.legalDescription,
        ownerName: formData.ownerName,
        coordinates: formData.coordinates,
      };

      const minStake = calculateMinStake(formData.valuation);

      await writeContract({
        address: contractAddresses.landRegistry,
        abi: LandRegistryABI,
        functionName: 'registerProperty',
        args: [metadata, minStake],
      });

      setStatus({
        type: 'success',
        message: 'Property registered successfully! Awaiting verification.',
      });

      // Reset form
      setFormData({
        location: '',
        valuation: '',
        area: '',
        legalDescription: '',
        ownerName: '',
        coordinates: '',
      });
    } catch (error: any) {
      setStatus({
        type: 'error',
        message: error.message || 'Failed to register property',
      });
    }
  };

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />

      <main className="flex-1 bg-gray-50 py-12">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="bg-white rounded-lg shadow-lg p-8">
            <h1 className="text-3xl font-bold mb-2">Register Property</h1>
            <p className="text-gray-600 mb-8">
              Submit your property for tokenization. You will need to stake 5% of the
              property valuation in USDC.
            </p>

            {status.type && (
              <div
                className={`mb-6 p-4 rounded-lg flex items-start ${
                  status.type === 'success'
                    ? 'bg-green-50 text-green-800'
                    : 'bg-red-50 text-red-800'
                }`}
              >
                {status.type === 'success' ? (
                  <CheckCircle className="h-5 w-5 mr-2 flex-shrink-0 mt-0.5" />
                ) : (
                  <AlertCircle className="h-5 w-5 mr-2 flex-shrink-0 mt-0.5" />
                )}
                <span>{status.message}</span>
              </div>
            )}

            <form onSubmit={handleRegister} className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Property Location
                  </label>
                  <input
                    type="text"
                    name="location"
                    value={formData.location}
                    onChange={handleInputChange}
                    required
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    placeholder="123 Main St, City, Country"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Valuation (USDC)
                  </label>
                  <input
                    type="number"
                    name="valuation"
                    value={formData.valuation}
                    onChange={handleInputChange}
                    required
                    step="0.01"
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    placeholder="1000000"
                  />
                  {formData.valuation && (
                    <p className="text-sm text-gray-500 mt-1">
                      Min stake: {(parseFloat(formData.valuation) * 0.05).toFixed(2)} USDC
                    </p>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Area (sq meters)
                  </label>
                  <input
                    type="number"
                    name="area"
                    value={formData.area}
                    onChange={handleInputChange}
                    required
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    placeholder="1000"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Owner Name
                  </label>
                  <input
                    type="text"
                    name="ownerName"
                    value={formData.ownerName}
                    onChange={handleInputChange}
                    required
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    placeholder="John Doe"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Coordinates (Lat, Long)
                  </label>
                  <input
                    type="text"
                    name="coordinates"
                    value={formData.coordinates}
                    onChange={handleInputChange}
                    required
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    placeholder="40.7128, -74.0060"
                  />
                </div>

                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Legal Description
                  </label>
                  <textarea
                    name="legalDescription"
                    value={formData.legalDescription}
                    onChange={handleInputChange}
                    required
                    rows={4}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    placeholder="Detailed legal description of the property..."
                  />
                </div>
              </div>

              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <h3 className="font-semibold text-blue-900 mb-2">Important Notes:</h3>
                <ul className="text-sm text-blue-800 space-y-1 list-disc list-inside">
                  <li>You must approve USDC spending before registration</li>
                  <li>Minimum stake: 5% of property valuation</li>
                  <li>Stake will be returned with 2% bonus upon verification approval</li>
                  <li>Properties undergo multisig verification (can take 1-7 days)</li>
                </ul>
              </div>

              <div className="flex gap-4">
                <button
                  type="button"
                  onClick={handleApprove}
                  disabled={!isConnected || !formData.valuation}
                  className="flex-1 bg-secondary-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  1. Approve USDC
                </button>

                <button
                  type="submit"
                  disabled={!isConnected || isRegistering}
                  className="flex-1 bg-primary-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-primary-700 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                >
                  {isRegistering ? (
                    <>
                      <Loader2 className="animate-spin mr-2 h-5 w-5" />
                      Registering...
                    </>
                  ) : (
                    '2. Register Property'
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}
