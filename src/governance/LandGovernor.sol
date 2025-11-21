// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ValidationLib } from "../libraries/ValidationLib.sol";
import { MathLib } from "../libraries/MathLib.sol";

/**
 * @title LandGovernor
 * @notice Per-property DAO for land token holders
 * @dev Token holders can vote on proposals related to the physical property
 */
contract LandGovernor is ReentrancyGuard {
    using ValidationLib for *;
    using MathLib for *;

    // Land token for this governor
    address public immutable LAND_TOKEN;

    /**
     * @notice Types of proposals
     */
    enum ProposalType {
        SellLand, // Vote to sell physical land
        ChangeManagement, // Change property management
        UpdateDocuments, // Update property documents
        DistributeDividends, // Distribute rental income
        Other // General proposal

    }

    /**
     * @notice Proposal states
     */
    enum ProposalState {
        Pending, // Proposal created
        Active, // Voting period active
        Defeated, // Vote failed
        Succeeded, // Vote passed
        Executed // Proposal executed

    }

    /**
     * @notice Proposal data
     */
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        ProposalType proposalType;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startBlock;
        uint256 endBlock;
        uint256 executionETA; // Execution time (after timelock)
        ProposalState state;
        mapping(address => bool) hasVoted;
    }

    // Proposal tracking
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    // Governance parameters (adjustable for realistic values)
    uint256 public constant VOTING_PERIOD = 50_400; // ~7 days on Polygon (2s blocks)
    uint256 public constant VOTING_DELAY = 1; // 1 block delay before voting starts
    uint256 public constant EXECUTION_DELAY = 172_800; // 4 days timelock (~2s blocks)
    uint256 public constant QUORUM = 20; // 20% of total supply (more realistic)
    uint256 public constant PROPOSAL_THRESHOLD = 1; // 1% to propose

    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        ProposalType proposalType,
        uint256 startBlock,
        uint256 endBlock
    );
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, ProposalType proposalType);
    event ProposalDefeated(uint256 indexed proposalId);

    // Errors
    error InsufficientVotingPower(uint256 required, uint256 actual);
    error VotingNotActive(uint256 proposalId, ProposalState state);
    error AlreadyVoted(uint256 proposalId);
    error ProposalNotSucceeded(uint256 proposalId, ProposalState state);
    error QuorumNotReached(uint256 required, uint256 actual);
    error TimelockNotExpired(uint256 eta, uint256 currentTime);
    error VotingNotStarted(uint256 proposalId, uint256 startBlock, uint256 currentBlock);

    /**
     * @notice Constructor
     * @param _landToken Address of land token for this governor
     */
    constructor(address _landToken) {
        ValidationLib.validateAddress(_landToken);
        LAND_TOKEN = _landToken;
    }

    /**
     * @notice Create a new proposal
     * @param description Proposal description
     * @param proposalType Type of proposal
     * @return proposalId ID of created proposal
     */
    function propose(string memory description, ProposalType proposalType) external returns (uint256 proposalId) {
        ValidationLib.validateNonEmptyString(description);

        // Check proposer has enough voting power (1% of supply at current block)
        uint256 proposerVotes = IVotes(LAND_TOKEN).getVotes(msg.sender);
        uint256 totalSupply = IERC20(LAND_TOKEN).totalSupply();
        uint256 threshold = (totalSupply * PROPOSAL_THRESHOLD) / 100;

        if (proposerVotes < threshold) {
            revert InsufficientVotingPower(threshold, proposerVotes);
        }

        proposalId = ++proposalCount;

        uint256 startBlock = block.number + VOTING_DELAY;
        uint256 endBlock = startBlock + VOTING_PERIOD;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.proposalType = proposalType;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.executionETA = 0; // Set when proposal succeeds
        newProposal.state = ProposalState.Pending;

        emit ProposalCreated(proposalId, msg.sender, description, proposalType, startBlock, endBlock);

        return proposalId;
    }

    /**
     * @notice Cast a vote on a proposal
     * @param proposalId Proposal to vote on
     * @param support True for yes, false for no
     */
    function vote(uint256 proposalId, bool support) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        // Activate proposal if it's still pending and voting has started
        if (proposal.state == ProposalState.Pending && block.number >= proposal.startBlock) {
            proposal.state = ProposalState.Active;
        }

        // Check voting period
        if (block.number < proposal.startBlock) {
            revert VotingNotStarted(proposalId, proposal.startBlock, block.number);
        }

        if (proposal.state != ProposalState.Active) {
            revert VotingNotActive(proposalId, proposal.state);
        }

        if (block.number > proposal.endBlock) {
            revert VotingNotActive(proposalId, ProposalState.Defeated);
        }

        // Check hasn't voted
        if (proposal.hasVoted[msg.sender]) {
            revert AlreadyVoted(proposalId);
        }

        // Get voting power at proposal start block (snapshot)
        uint256 votes = IVotes(LAND_TOKEN).getPastVotes(msg.sender, proposal.startBlock);
        ValidationLib.validateNonZero(votes);

        // Record vote
        proposal.hasVoted[msg.sender] = true;

        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    /**
     * @notice Queue a successful proposal (sets timelock)
     * @param proposalId Proposal to queue
     */
    function queue(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        // Check voting has ended
        if (block.number <= proposal.endBlock) {
            revert VotingNotActive(proposalId, proposal.state);
        }

        // Update state if still active
        if (proposal.state == ProposalState.Active) {
            _updateProposalState(proposalId);
        }

        // Check proposal succeeded
        if (proposal.state != ProposalState.Succeeded) {
            revert ProposalNotSucceeded(proposalId, proposal.state);
        }

        // Set execution ETA (timelock)
        proposal.executionETA = block.number + EXECUTION_DELAY;
    }

    /**
     * @notice Execute a successful proposal after timelock
     * @param proposalId Proposal to execute
     */
    function execute(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        // Check proposal is in succeeded state
        if (proposal.state != ProposalState.Succeeded) {
            revert ProposalNotSucceeded(proposalId, proposal.state);
        }

        // Check timelock has expired
        if (proposal.executionETA == 0 || block.number < proposal.executionETA) {
            revert TimelockNotExpired(proposal.executionETA, block.number);
        }

        proposal.state = ProposalState.Executed;

        emit ProposalExecuted(proposalId, proposal.proposalType);

        // Note: Actual execution logic (e.g., selling land) would be handled off-chain
        // This is intentional for the hackathon MVP
    }

    /**
     * @notice Update proposal state after voting ends
     * @param proposalId Proposal to update
     */
    function _updateProposalState(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];

        uint256 totalSupply = IERC20(LAND_TOKEN).totalSupply();
        uint256 quorumVotes = (totalSupply * QUORUM) / 100;

        // Check quorum and majority
        if (proposal.forVotes >= quorumVotes && proposal.forVotes > proposal.againstVotes) {
            proposal.state = ProposalState.Succeeded;
        } else {
            proposal.state = ProposalState.Defeated;
            emit ProposalDefeated(proposalId);
        }
    }

    /**
     * @notice Get proposal state
     * @param proposalId Proposal ID
     * @return ProposalState Current state
     */
    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        // If voting period ended but state not updated
        if (proposal.state == ProposalState.Active && block.number > proposal.endBlock) {
            uint256 totalSupply = IERC20(LAND_TOKEN).totalSupply();
            uint256 quorumVotes = (totalSupply * QUORUM) / 100;

            if (proposal.forVotes >= quorumVotes && proposal.forVotes > proposal.againstVotes) {
                return ProposalState.Succeeded;
            } else {
                return ProposalState.Defeated;
            }
        }

        return proposal.state;
    }

    /**
     * @notice Get proposal details
     * @param proposalId Proposal ID
     * @return id Proposal ID
     * @return proposer Proposer address
     * @return description Proposal description
     * @return proposalType Type of proposal
     * @return forVotes Votes in favor
     * @return againstVotes Votes against
     * @return startBlock Start block
     * @return endBlock End block
     * @return state Current state
     */
    function getProposal(uint256 proposalId)
        external
        view
        returns (
            uint256 id,
            address proposer,
            string memory description,
            ProposalType proposalType,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 startBlock,
            uint256 endBlock,
            ProposalState state
        )
    {
        Proposal storage proposal = proposals[proposalId];

        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.proposalType,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startBlock,
            proposal.endBlock,
            proposal.state
        );
    }

    /**
     * @notice Check if address has voted on proposal
     * @param proposalId Proposal ID
     * @param voter Voter address
     * @return bool True if voted
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    /**
     * @notice Get voting power for address at proposal snapshot
     * @param proposalId Proposal ID
     * @param voter Voter address
     * @return uint256 Voting power at snapshot
     */
    function getVotingPower(uint256 proposalId, address voter) external view returns (uint256) {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.startBlock == 0) return 0;
        return IVotes(LAND_TOKEN).getPastVotes(voter, proposal.startBlock);
    }

    /**
     * @notice Check if proposal has reached quorum
     * @param proposalId Proposal ID
     * @return bool True if quorum reached
     */
    function hasReachedQuorum(uint256 proposalId) external view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalSupply = IERC20(LAND_TOKEN).totalSupply();
        uint256 quorumVotes = (totalSupply * QUORUM) / 100;

        return proposal.forVotes >= quorumVotes;
    }

    /**
     * @notice Get blocks remaining in voting period
     * @param proposalId Proposal ID
     * @return uint256 Blocks remaining (0 if ended)
     */
    function getBlocksRemaining(uint256 proposalId) external view returns (uint256) {
        Proposal storage proposal = proposals[proposalId];

        if (block.number >= proposal.endBlock) return 0;

        return proposal.endBlock - block.number;
    }
}
