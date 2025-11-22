'use client';

import { useState } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useActiveAccount } from "thirdweb/react";
import { prepareContractCall, sendTransaction } from "thirdweb";
import { useLandRegistryContract, useUSDCContract } from '@/hooks/useContracts';
import { AlertCircle, CheckCircle, Loader2 } from 'lucide-react';
import { CONTRACT_ADDRESSES, MIN_STAKE_PERCENTAGE } from '@/lib/config';

export default function RegisterPage() {
  const account = useActiveAccount();
  const landRegistry = useLandRegistryContract();
  const usdcContract = useUSDCContract();

  const [formData, setFormData] = useState({
    location: '',
    valuation: '',
    area: '',
    legalDescription: '',
    ownerName: '',
    coordinates: '',
  });

  const [status, setStatus] = useState<{
    type: 'success' | 'error' | 'info' | null;
    message: string;
  }>({ type: null, message: '' });

  const [isApproving, setIsApproving] = useState(false);
  const [isRegistering, setIsRegistering] = useState(false);
  const [isApproved, setIsApproved] = useState(false);

  const handleInputChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>
  ) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const calculateMinStake = (valuation: string): bigint => {
    if (!valuation || isNaN(parseFloat(valuation))) return BigInt(0);
    const valuationWei = BigInt(Math.floor(parseFloat(valuation) * 1e6));
    return (valuationWei * BigInt(MIN_STAKE_PERCENTAGE)) / BigInt(100);
  };

  const handleApprove = async () => {
    if (!account) {
      setStatus({ type: 'error', message: 'Please connect your wallet first' });
      return;
    }

    if (!formData.valuation) {
      setStatus({ type: 'error', message: 'Please enter property valuation' });
      return;
    }

    setIsApproving(true);
    setStatus({ type: 'info', message: 'Approving USDC...' });

    try {
      const minStake = calculateMinStake(formData.valuation);

      const transaction = prepareContractCall({
        contract: usdcContract,
        method: "function approve(address spender, uint256 amount) returns (bool)",
        params: [CONTRACT_ADDRESSES.stakingVault, minStake],
      });

      const { transactionHash } = await sendTransaction({
        transaction,
        account,
      });

      setIsApproved(true);
      setStatus({
        type: 'success',
        message: `USDC approved! Transaction: ${transactionHash}`,
      });
    } catch (error: any) {
      console.error('Approval error:', error);
      setStatus({
        type: 'error',
        message: error.message || 'Failed to approve USDC',
      });
    } finally {
      setIsApproving(false);
    }
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!account) {
      setStatus({ type: 'error', message: 'Please connect your wallet' });
      return;
    }

    if (!isApproved) {
      setStatus({ type: 'error', message: 'Please approve USDC first' });
      return;
    }

    setIsRegistering(true);
    setStatus({ type: 'info', message: 'Registering property...' });

    try {
      const metadata = {
        location: formData.location,
        valuation: BigInt(Math.floor(parseFloat(formData.valuation) * 1e6)),
        area: BigInt(formData.area),
        legalDescription: formData.legalDescription,
        ownerName: formData.ownerName,
        coordinates: formData.coordinates,
      };

      const minStake = calculateMinStake(formData.valuation);

      const transaction = prepareContractCall({
        contract: landRegistry,
        method: "function registerProperty((string location, uint256 valuation, uint256 area, string legalDescription, string ownerName, string coordinates) metadata, uint256 stakeAmount) returns (bytes32)",
        params: [metadata, minStake],
      });

      const { transactionHash } = await sendTransaction({
        transaction,
        account,
      });

      setStatus({
        type: 'success',
        message: `Property registered successfully! Transaction: ${transactionHash}`,
      });

      setFormData({
        location: '',
        valuation: '',
        area: '',
        legalDescription: '',
        ownerName: '',
        coordinates: '',
      });
      setIsApproved(false);
    } catch (error: any) {
      console.error('Registration error:', error);
      setStatus({
        type: 'error',
        message: error.message || 'Failed to register property',
      });
    } finally {
      setIsRegistering(false);
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
              Submit your property for tokenization. Stake 5% of property valuation in USDC.
            </p>

            {status.type && (
              <div
                className={`mb-6 p-4 rounded-lg flex items-start ${
                  status.type === 'success'
                    ? 'bg-green-50 text-green-800'
                    : status.type === 'error'
                    ? 'bg-red-50 text-red-800'
                    : 'bg-blue-50 text-blue-800'
                }`}
              >
                {status.type === 'success' ? (
                  <CheckCircle className="h-5 w-5 mr-2 flex-shrink-0 mt-0.5" />
                ) : (
                  <AlertCircle className="h-5 w-5 mr-2 flex-shrink-0 mt-0.5" />
                )}
                <span className="text-sm">{status.message}</span>
              </div>
            )}

            {!account ? (
              <div className="text-center py-12">
                <AlertCircle className="h-16 w-16 text-gray-400 mx-auto mb-4" />
                <h3 className="text-xl font-semibold mb-2">Connect Your Wallet</h3>
                <p className="text-gray-600">
                  Please connect your wallet to register a property
                </p>
              </div>
            ) : (
              <form onSubmit={handleRegister} className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Property Location *
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
                      Valuation (USDC) *
                    </label>
                    <input
                      type="number"
                      name="valuation"
                      value={formData.valuation}
                      onChange={handleInputChange}
                      required
                      step="0.01"
                      min="0"
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                      placeholder="1000000"
                    />
                    {formData.valuation && (
                      <p className="text-sm text-gray-500 mt-1">
                        Min stake: {(parseFloat(formData.valuation) * (MIN_STAKE_PERCENTAGE / 100)).toFixed(2)} USDC
                      </p>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Area (sq meters) *
                    </label>
                    <input
                      type="number"
                      name="area"
                      value={formData.area}
                      onChange={handleInputChange}
                      required
                      min="0"
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                      placeholder="1000"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Owner Name *
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

                  <div className="md:col-span-2">
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Coordinates (Lat, Long) *
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
                      Legal Description *
                    </label>
                    <textarea
                      name="legalDescription"
                      value={formData.legalDescription}
                      onChange={handleInputChange}
                      required
                      rows={4}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                      placeholder="Detailed legal description..."
                    />
                  </div>
                </div>

                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <h3 className="font-semibold text-blue-900 mb-2">Important Notes:</h3>
                  <ul className="text-sm text-blue-800 space-y-1 list-disc list-inside">
                    <li>Approve USDC before registration</li>
                    <li>Min stake: {MIN_STAKE_PERCENTAGE}% of valuation</li>
                    <li>Stake returned with 2% bonus on approval</li>
                    <li>Verification takes 1-7 days</li>
                  </ul>
                </div>

                <div className="flex gap-4">
                  <button
                    type="button"
                    onClick={handleApprove}
                    disabled={!formData.valuation || isApproving || isApproved}
                    className="flex-1 bg-secondary-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary-700 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                  >
                    {isApproving ? (
                      <>
                        <Loader2 className="animate-spin mr-2 h-5 w-5" />
                        Approving...
                      </>
                    ) : isApproved ? (
                      <>
                        <CheckCircle className="mr-2 h-5 w-5" />
                        Approved
                      </>
                    ) : (
                      '1. Approve USDC'
                    )}
                  </button>

                  <button
                    type="submit"
                    disabled={!isApproved || isRegistering}
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
            )}
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}
