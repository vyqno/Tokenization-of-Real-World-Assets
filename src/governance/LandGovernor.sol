// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
        ProposalState state;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) votingPower; // Snapshot of voting power
    }

    // Proposal tracking
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    // Governance parameters
    uint256 public constant VOTING_PERIOD = 50_400; // ~7 days on Polygon (2s blocks)
    uint256 public constant QUORUM = 75; // 75% of total supply
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

        // Check proposer has enough tokens (1% of supply)
        uint256 proposerBalance = IERC20(LAND_TOKEN).balanceOf(msg.sender);
        uint256 totalSupply = IERC20(LAND_TOKEN).totalSupply();
        uint256 threshold = (totalSupply * PROPOSAL_THRESHOLD) / 100;

        if (proposerBalance < threshold) {
            revert InsufficientVotingPower(threshold, proposerBalance);
        }

        proposalId = ++proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.proposalType = proposalType;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.startBlock = block.number;
        newProposal.endBlock = block.number + VOTING_PERIOD;
        newProposal.state = ProposalState.Active;

        emit ProposalCreated(
            proposalId, msg.sender, description, proposalType, newProposal.startBlock, newProposal.endBlock
        );

        return proposalId;
    }

    /**
     * @notice Cast a vote on a proposal
     * @param proposalId Proposal to vote on
     * @param support True for yes, false for no
     */
    function vote(uint256 proposalId, bool support) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        // Check voting is active
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

        // Get voting power (current token balance)
        uint256 votes = IERC20(LAND_TOKEN).balanceOf(msg.sender);
        ValidationLib.validateNonZero(votes);

        // Record vote
        proposal.hasVoted[msg.sender] = true;
        proposal.votingPower[msg.sender] = votes;

        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    /**
     * @notice Execute a successful proposal
     * @param proposalId Proposal to execute
     */
    function execute(uint256 proposalId) external nonReentrant {
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
     * @notice Get voting power used by address on proposal
     * @param proposalId Proposal ID
     * @param voter Voter address
     * @return uint256 Voting power used
     */
    function getVotingPower(uint256 proposalId, address voter) external view returns (uint256) {
        return proposals[proposalId].votingPower[voter];
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
