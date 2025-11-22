'use client';

import { useState } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useAccount } from 'wagmi';
import { Vote, CheckCircle, XCircle, Clock, TrendingUp } from 'lucide-react';

export default function GovernancePage() {
  const { isConnected } = useAccount();
  const [filter, setFilter] = useState<'all' | 'active' | 'ended'>('all');

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />

      <main className="flex-1 bg-gray-50 py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="mb-8">
            <h1 className="text-4xl font-bold mb-2">Governance</h1>
            <p className="text-gray-600">
              Participate in property governance through on-chain voting
            </p>
          </div>

          {/* Stats Overview */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div className="bg-white rounded-lg shadow-sm p-6">
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-600 text-sm">Active Proposals</span>
                <Vote className="h-5 w-5 text-primary-600" />
              </div>
              <div className="text-2xl font-bold">0</div>
            </div>

            <div className="bg-white rounded-lg shadow-sm p-6">
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-600 text-sm">Your Voting Power</span>
                <TrendingUp className="h-5 w-5 text-primary-600" />
              </div>
              <div className="text-2xl font-bold">0</div>
            </div>

            <div className="bg-white rounded-lg shadow-sm p-6">
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-600 text-sm">Proposals Voted</span>
                <CheckCircle className="h-5 w-5 text-primary-600" />
              </div>
              <div className="text-2xl font-bold">0</div>
            </div>

            <div className="bg-white rounded-lg shadow-sm p-6">
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-600 text-sm">Total Proposals</span>
                <Vote className="h-5 w-5 text-primary-600" />
              </div>
              <div className="text-2xl font-bold">0</div>
            </div>
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
                All Proposals
              </button>
              <button
                onClick={() => setFilter('active')}
                className={`px-4 py-2 rounded-lg font-medium transition ${
                  filter === 'active'
                    ? 'bg-primary-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                Active
              </button>
              <button
                onClick={() => setFilter('ended')}
                className={`px-4 py-2 rounded-lg font-medium transition ${
                  filter === 'ended'
                    ? 'bg-primary-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                Ended
              </button>
            </div>
          </div>

          {/* Proposals List */}
          {!isConnected ? (
            <div className="bg-white rounded-lg shadow-sm p-12 text-center">
              <Vote className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-xl font-semibold mb-2">Connect Your Wallet</h3>
              <p className="text-gray-600">
                Please connect your wallet to view and participate in governance
              </p>
            </div>
          ) : (
            <div className="space-y-6">
              {/* Example Proposal Card */}
              <ProposalCard
                id="1"
                title="Increase Property Maintenance Budget"
                property="Downtown Commercial Property"
                description="Proposal to increase the annual maintenance budget by 15% to ensure proper upkeep and enhance property value."
                status="active"
                forVotes={12500}
                againstVotes={3200}
                endDate={new Date(Date.now() + 3 * 24 * 60 * 60 * 1000)}
                proposer="0x1234...5678"
              />

              <ProposalCard
                id="2"
                title="Approve Property Sale to External Buyer"
                property="Suburban Residential Land"
                description="Vote to approve the sale of the property to an external buyer at $950,000, representing a 12% premium over current valuation."
                status="active"
                forVotes={8900}
                againstVotes={15600}
                endDate={new Date(Date.now() + 5 * 24 * 60 * 60 * 1000)}
                proposer="0xabcd...ef12"
              />

              <ProposalCard
                id="3"
                title="Distribute Rental Income to Token Holders"
                property="Industrial Warehouse"
                description="Proposal to distribute $45,000 in rental income proportionally to all token holders."
                status="ended"
                forVotes={22300}
                againstVotes={1200}
                endDate={new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)}
                proposer="0x9876...4321"
              />

              {/* Empty State */}
              {/* Uncomment this if there are no proposals */}
              {/* <div className="bg-white rounded-lg shadow-sm p-12 text-center">
                <Vote className="h-16 w-16 text-gray-400 mx-auto mb-4" />
                <h3 className="text-xl font-semibold mb-2">No Proposals Yet</h3>
                <p className="text-gray-600 mb-6">
                  Be the first to create a governance proposal
                </p>
                <button className="bg-primary-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-primary-700 transition">
                  Create Proposal
                </button>
              </div> */}
            </div>
          )}
        </div>
      </main>

      <Footer />
    </div>
  );
}

interface ProposalCardProps {
  id: string;
  title: string;
  property: string;
  description: string;
  status: 'active' | 'ended';
  forVotes: number;
  againstVotes: number;
  endDate: Date;
  proposer: string;
}

function ProposalCard({
  id,
  title,
  property,
  description,
  status,
  forVotes,
  againstVotes,
  endDate,
  proposer,
}: ProposalCardProps) {
  const totalVotes = forVotes + againstVotes;
  const forPercentage = totalVotes > 0 ? (forVotes / totalVotes) * 100 : 0;
  const againstPercentage = totalVotes > 0 ? (againstVotes / totalVotes) * 100 : 0;

  return (
    <div className="bg-white rounded-lg shadow-sm p-6 hover:shadow-md transition">
      <div className="flex justify-between items-start mb-4">
        <div className="flex-1">
          <div className="flex items-center gap-3 mb-2">
            <h3 className="text-xl font-bold">{title}</h3>
            {status === 'active' ? (
              <span className="bg-green-100 text-green-800 px-3 py-1 rounded-full text-sm font-medium">
                Active
              </span>
            ) : (
              <span className="bg-gray-100 text-gray-800 px-3 py-1 rounded-full text-sm font-medium">
                Ended
              </span>
            )}
          </div>
          <p className="text-sm text-gray-600 mb-2">Property: {property}</p>
          <p className="text-gray-700">{description}</p>
        </div>
      </div>

      <div className="space-y-3 mb-4">
        {/* For Votes */}
        <div>
          <div className="flex justify-between items-center mb-1">
            <div className="flex items-center">
              <CheckCircle className="h-4 w-4 text-green-600 mr-1" />
              <span className="text-sm font-medium">For</span>
            </div>
            <span className="text-sm font-semibold">
              {forVotes.toLocaleString()} ({forPercentage.toFixed(1)}%)
            </span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className="bg-green-600 h-2 rounded-full"
              style={{ width: `${forPercentage}%` }}
            ></div>
          </div>
        </div>

        {/* Against Votes */}
        <div>
          <div className="flex justify-between items-center mb-1">
            <div className="flex items-center">
              <XCircle className="h-4 w-4 text-red-600 mr-1" />
              <span className="text-sm font-medium">Against</span>
            </div>
            <span className="text-sm font-semibold">
              {againstVotes.toLocaleString()} ({againstPercentage.toFixed(1)}%)
            </span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className="bg-red-600 h-2 rounded-full"
              style={{ width: `${againstPercentage}%` }}
            ></div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between text-sm text-gray-600 mb-4">
        <div className="flex items-center">
          <Clock className="h-4 w-4 mr-1" />
          <span>
            {status === 'active'
              ? `Ends ${endDate.toLocaleDateString()}`
              : `Ended ${endDate.toLocaleDateString()}`}
          </span>
        </div>
        <span>Proposed by {proposer}</span>
      </div>

      {status === 'active' && (
        <div className="flex gap-3">
          <button className="flex-1 bg-green-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-green-700 transition">
            Vote For
          </button>
          <button className="flex-1 bg-red-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-red-700 transition">
            Vote Against
          </button>
        </div>
      )}
    </div>
  );
}
