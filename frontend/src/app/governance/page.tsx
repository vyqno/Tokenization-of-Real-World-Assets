'use client';

import { useState, useEffect } from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { useActiveAccount } from "thirdweb/react";
import { prepareContractCall, sendTransaction, readContract } from "thirdweb";
import { useLandRegistryContract } from '@/hooks/useContracts';
import { motion, AnimatePresence } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import {
  Vote, CheckCircle, XCircle, Clock, TrendingUp, Plus, Users,
  ThumbsUp, ThumbsDown, AlertCircle, FileText, Calendar, ShieldCheck
} from 'lucide-react';
import { toast } from 'sonner';
import { formatToken } from '@/utils/format';

interface Proposal {
  id: string;
  title: string;
  description: string;
  proposer: string;
  startTime: number;
  endTime: number;
  forVotes: bigint;
  againstVotes: bigint;
  status: 'active' | 'passed' | 'rejected' | 'pending';
  category: 'governance' | 'treasury' | 'property' | 'technical';
  hasVoted: boolean;
  userVote?: 'for' | 'against';
}

export default function GovernancePage() {
  const account = useActiveAccount();
  const landRegistry = useLandRegistryContract();
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [filter, setFilter] = useState<'all' | 'active' | 'ended'>('all');
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [voting, setVoting] = useState<string | null>(null);
  const [votingPower, setVotingPower] = useState(BigInt(0));
  const [isVerifier, setIsVerifier] = useState(false);
  const [checkingVerifier, setCheckingVerifier] = useState(true);

  useEffect(() => {
    if (account) {
      checkVerifierStatus();
      loadProposals();
      loadVotingPower();
    } else {
      setIsVerifier(false);
      setCheckingVerifier(false);
    }
  }, [account]);

  async function checkVerifierStatus() {
    if (!account) {
      setCheckingVerifier(false);
      return;
    }

    try {
      setCheckingVerifier(true);
      const verifierStatus = await readContract({
        contract: landRegistry,
        method: "function isVerifier(address) view returns (bool)",
        params: [account.address],
      }) as boolean;

      setIsVerifier(verifierStatus);

      if (verifierStatus) {
        toast.success('✓ Verifier access granted', { duration: 2000 });
      }
    } catch (error) {
      console.error('Error checking verifier status:', error);
      setIsVerifier(false);
    } finally {
      setCheckingVerifier(false);
    }
  }

  async function loadProposals() {
    try {
      // Demo data - replace with actual contract calls
      const demoProposals: Proposal[] = [
        {
          id: '1',
          title: 'Increase Verification Stake Requirement',
          description: 'Proposal to increase the minimum verification stake from 5% to 7% to improve property quality and reduce fraudulent registrations.',
          proposer: '0xabc...def',
          startTime: Date.now() / 1000 - 86400 * 2,
          endTime: Date.now() / 1000 + 86400 * 5,
          forVotes: BigInt(125000 * 1e18),
          againstVotes: BigInt(45000 * 1e18),
          status: 'active',
          category: 'governance',
          hasVoted: false,
        },
        {
          id: '2',
          title: 'Allocate Treasury Funds for Marketing',
          description: 'Allocate 50,000 USDC from treasury for Q1 2025 marketing campaign to increase platform adoption.',
          proposer: '0x123...456',
          startTime: Date.now() / 1000 - 86400,
          endTime: Date.now() / 1000 + 86400 * 6,
          forVotes: BigInt(95000 * 1e18),
          againstVotes: BigInt(55000 * 1e18),
          status: 'active',
          category: 'treasury',
          hasVoted: true,
          userVote: 'for',
        },
        {
          id: '3',
          title: 'Update Property Tokenization Fee',
          description: 'Reduce the property tokenization fee from 2% to 1.5% to attract more property owners.',
          proposer: '0x789...abc',
          startTime: Date.now() / 1000 - 86400 * 10,
          endTime: Date.now() / 1000 - 86400 * 3,
          forVotes: BigInt(180000 * 1e18),
          againstVotes: BigInt(20000 * 1e18),
          status: 'passed',
          category: 'property',
          hasVoted: true,
          userVote: 'for',
        },
      ];

      setProposals(demoProposals);
    } catch (error) {
      console.error('Error loading proposals:', error);
      toast.error('Failed to load proposals');
    }
  }

  async function loadVotingPower() {
    try {
      // Demo data - replace with actual contract calls
      setVotingPower(BigInt(15000 * 1e18));
    } catch (error) {
      console.error('Error loading voting power:', error);
    }
  }

  async function vote(proposalId: string, support: boolean) {
    if (!account) return;

    setVoting(proposalId);

    try {
      // In production, this would call the governance contract
      // const transaction = prepareContractCall({
      //   contract: governorContract,
      //   method: "function castVote(uint256 proposalId, uint8 support)",
      //   params: [BigInt(proposalId), support ? 1 : 0],
      // });
      //
      // const { transactionHash } = await sendTransaction({
      //   transaction,
      //   account,
      // });

      // Simulate vote
      await new Promise(resolve => setTimeout(resolve, 2000));

      setProposals(prev => prev.map(p =>
        p.id === proposalId
          ? {
              ...p,
              hasVoted: true,
              userVote: support ? 'for' : 'against',
              forVotes: support ? p.forVotes + votingPower : p.forVotes,
              againstVotes: !support ? p.againstVotes + votingPower : p.againstVotes,
            }
          : p
      ));

      toast.success(`Vote cast successfully!`);
    } catch (error: any) {
      console.error('Voting error:', error);
      toast.error(error.message || 'Failed to cast vote');
    } finally {
      setVoting(null);
    }
  }

  const filteredProposals = proposals.filter(p => {
    if (filter === 'active') return p.status === 'active';
    if (filter === 'ended') return p.status === 'passed' || p.status === 'rejected';
    return true;
  });

  const stats = {
    active: proposals.filter(p => p.status === 'active').length,
    total: proposals.length,
    voted: proposals.filter(p => p.hasVoted).length,
    votingPower,
  };

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
              <Vote className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-xl font-semibold mb-2 dark:text-white">Connect Your Wallet</h3>
              <p className="text-gray-600 dark:text-gray-400">
                Connect your wallet to participate in governance
              </p>
            </motion.div>
          </div>
        </main>
        <Footer />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col bg-gray-50 dark:bg-gray-900">
      <Navbar />

      <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 w-full">
        {/* Verifier Badge */}
        {isVerifier && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-gradient-to-r from-green-50 to-emerald-50 dark:from-green-900/20 dark:to-emerald-900/20 rounded-lg p-4 mb-6 border border-green-200 dark:border-green-800"
          >
            <div className="flex items-center gap-3">
              <ShieldCheck className="h-6 w-6 text-green-600 dark:text-green-400" />
              <div>
                <p className="font-semibold text-green-800 dark:text-green-200">
                  Verifier Access Active
                </p>
                <p className="text-sm text-green-700 dark:text-green-300">
                  You can approve, reject, or slash property registrations
                </p>
              </div>
            </div>
          </motion.div>
        )}

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8 flex items-center justify-between"
        >
          <div>
            <h1 className="text-4xl font-bold text-gray-900 dark:text-white mb-2">
              Governance
            </h1>
            <p className="text-gray-600 dark:text-gray-400">
              Participate in platform governance through on-chain voting
            </p>
          </div>
          <Button onClick={() => setShowCreateModal(true)} className="gap-2">
            <Plus className="h-4 w-4" />
            Create Proposal
          </Button>
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
                    Active Proposals
                  </CardTitle>
                  <Vote className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  {stats.active}
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
                    Voting Power
                  </CardTitle>
                  <TrendingUp className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  {formatToken(stats.votingPower)}
                </div>
                <div className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                  Governance tokens
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
                    Proposals Voted
                  </CardTitle>
                  <CheckCircle className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  {stats.voted}
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
                    Total Proposals
                  </CardTitle>
                  <Users className="h-5 w-5 text-primary-600" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-gray-900 dark:text-white">
                  {stats.total}
                </div>
              </CardContent>
            </Card>
          </motion.div>
        </div>

        {/* Filters */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
          className="mb-8"
        >
          <Card>
            <CardContent className="pt-6">
              <div className="flex flex-wrap gap-3">
                <Button
                  variant={filter === 'all' ? 'default' : 'outline'}
                  onClick={() => setFilter('all')}
                >
                  All Proposals
                </Button>
                <Button
                  variant={filter === 'active' ? 'default' : 'outline'}
                  onClick={() => setFilter('active')}
                >
                  Active
                </Button>
                <Button
                  variant={filter === 'ended' ? 'default' : 'outline'}
                  onClick={() => setFilter('ended')}
                >
                  Ended
                </Button>
              </div>
            </CardContent>
          </Card>
        </motion.div>

        {/* Proposals List */}
        <div className="space-y-6">
          <AnimatePresence>
            {filteredProposals.map((proposal, i) => (
              <ProposalCard
                key={proposal.id}
                proposal={proposal}
                index={i}
                onVote={vote}
                voting={voting === proposal.id}
                votingPower={votingPower}
              />
            ))}
          </AnimatePresence>

          {filteredProposals.length === 0 && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="text-center py-12"
            >
              <Vote className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-xl font-semibold mb-2 dark:text-white">No proposals found</h3>
              <p className="text-gray-600 dark:text-gray-400">
                {filter === 'active' ? 'No active proposals at the moment' : 'No proposals match your filter'}
              </p>
            </motion.div>
          )}
        </div>
      </main>

      <Footer />

      {/* Create Proposal Modal - simplified for demo */}
      {showCreateModal && (
        <div
          className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50"
          onClick={() => setShowCreateModal(false)}
        >
          <div
            className="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-2xl w-full"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-2xl font-bold mb-4 dark:text-white">Create Proposal</h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              Proposal creation requires significant governance token holdings. This feature will be fully integrated with the Governor contract.
            </p>
            <Button onClick={() => setShowCreateModal(false)} variant="outline" className="w-full">
              Close
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

interface ProposalCardProps {
  proposal: Proposal;
  index: number;
  onVote: (id: string, support: boolean) => void;
  voting: boolean;
  votingPower: bigint;
}

function ProposalCard({ proposal, index, onVote, voting, votingPower }: ProposalCardProps) {
  const totalVotes = proposal.forVotes + proposal.againstVotes;
  const forPercentage = totalVotes > BigInt(0)
    ? Number((proposal.forVotes * BigInt(100)) / totalVotes)
    : 0;
  const againstPercentage = 100 - forPercentage;

  const isActive = proposal.status === 'active';
  const timeRemaining = proposal.endTime - Date.now() / 1000;
  const daysLeft = Math.ceil(timeRemaining / 86400);

  const categoryColors = {
    governance: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200',
    treasury: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
    property: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
    technical: 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200',
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ delay: index * 0.05 }}
    >
      <Card>
        <CardHeader>
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <div className="flex items-center gap-3 mb-2">
                <CardTitle className="text-xl">{proposal.title}</CardTitle>
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${categoryColors[proposal.category]}`}>
                  {proposal.category}
                </span>
              </div>
              <CardDescription className="text-base">
                {proposal.description}
              </CardDescription>
            </div>
            {isActive && (
              <div className="flex items-center gap-2 text-sm text-green-600 dark:text-green-400 font-medium">
                <Clock className="h-4 w-4" />
                {daysLeft}d left
              </div>
            )}
          </div>
        </CardHeader>

        <CardContent>
          <div className="space-y-6">
            {/* Voting Results */}
            <div>
              <div className="flex items-center justify-between text-sm mb-3">
                <div className="flex items-center gap-2 text-green-600 dark:text-green-400">
                  <ThumbsUp className="h-4 w-4" />
                  <span className="font-semibold">{forPercentage}% For</span>
                  <span className="text-gray-500 dark:text-gray-400">
                    ({formatToken(proposal.forVotes)} votes)
                  </span>
                </div>
                <div className="flex items-center gap-2 text-red-600 dark:text-red-400">
                  <span className="text-gray-500 dark:text-gray-400">
                    ({formatToken(proposal.againstVotes)} votes)
                  </span>
                  <span className="font-semibold">{againstPercentage}% Against</span>
                  <ThumbsDown className="h-4 w-4" />
                </div>
              </div>

              <div className="relative h-3 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${forPercentage}%` }}
                  transition={{ duration: 1 }}
                  className="absolute h-full bg-green-500"
                />
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${againstPercentage}%` }}
                  transition={{ duration: 1 }}
                  className="absolute h-full bg-red-500 right-0"
                />
              </div>
            </div>

            {/* Proposal Info */}
            <div className="flex items-center gap-6 text-sm text-gray-600 dark:text-gray-400">
              <div className="flex items-center gap-2">
                <Users className="h-4 w-4" />
                <span>Proposer: {proposal.proposer}</span>
              </div>
              <div className="flex items-center gap-2">
                <Calendar className="h-4 w-4" />
                <span>
                  {new Date(proposal.startTime * 1000).toLocaleDateString()} - {' '}
                  {new Date(proposal.endTime * 1000).toLocaleDateString()}
                </span>
              </div>
            </div>

            {/* Voting Buttons */}
            {isActive && (
              <div className="flex gap-3">
                {proposal.hasVoted ? (
                  <div className="flex-1 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4 text-center">
                    <div className="flex items-center justify-center gap-2 text-blue-600 dark:text-blue-400">
                      <CheckCircle className="h-5 w-5" />
                      <span className="font-semibold">
                        You voted {proposal.userVote === 'for' ? 'For' : 'Against'}
                      </span>
                    </div>
                  </div>
                ) : (
                  <>
                    <Button
                      onClick={() => onVote(proposal.id, true)}
                      disabled={voting}
                      className="flex-1 bg-green-600 hover:bg-green-700"
                    >
                      <ThumbsUp className="mr-2 h-4 w-4" />
                      Vote For
                    </Button>
                    <Button
                      onClick={() => onVote(proposal.id, false)}
                      disabled={voting}
                      variant="destructive"
                      className="flex-1"
                    >
                      <ThumbsDown className="mr-2 h-4 w-4" />
                      Vote Against
                    </Button>
                  </>
                )}
              </div>
            )}

            {!isActive && (
              <div className={`p-4 rounded-lg text-center font-semibold ${
                proposal.status === 'passed'
                  ? 'bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400 border border-green-200 dark:border-green-800'
                  : 'bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 border border-red-200 dark:border-red-800'
              }`}>
                {proposal.status === 'passed' ? '✓ Proposal Passed' : '✗ Proposal Rejected'}
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    </motion.div>
  );
}
