// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ILandRegistry } from "../interfaces/ILandRegistry.sol";
import { ILandToken } from "../interfaces/ILandToken.sol";
import { ValidationLib } from "../libraries/ValidationLib.sol";

/**
 * @title AgencyMultisig
 * @notice Multi-signature wallet for property verification agency
 * @dev Requires multiple signatures for critical operations
 */
contract AgencyMultisig is ReentrancyGuard {
    using ValidationLib for *;

    // Multisig signers
    address[] public signers;
    mapping(address => bool) public isSigner;
    uint256 public requiredSignatures;

    // LandRegistry reference
    ILandRegistry public landRegistry;

    /**
     * @notice Transaction types
     */
    enum TransactionType {
        VerifyProperty,
        RejectProperty,
        SlashProperty,
        PauseToken,
        AddVerifier,
        RemoveVerifier
    }

    /**
     * @notice Transaction data
     */
    struct Transaction {
        uint256 id;
        TransactionType txType;
        bytes32 propertyId; // For property operations
        address targetAddress; // For verifier operations
        string data; // Additional data (e.g., evidence)
        uint256 confirmations;
        mapping(address => bool) isConfirmed;
        bool executed;
        uint256 createdAt;
    }

    // Transaction tracking
    mapping(uint256 => Transaction) public transactions;
    uint256 public transactionCount;

    // Events
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event RequirementChanged(uint256 required);
    event TransactionSubmitted(uint256 indexed txId, TransactionType txType, address indexed submitter);
    event TransactionConfirmed(uint256 indexed txId, address indexed signer);
    event TransactionRevoked(uint256 indexed txId, address indexed signer);
    event TransactionExecuted(uint256 indexed txId);

    // Errors
    error NotSigner();
    error InvalidRequirement();
    error TransactionNotFound(uint256 txId);
    error AlreadyConfirmed(uint256 txId);
    error NotConfirmed(uint256 txId);
    error AlreadyExecuted(uint256 txId);
    error InsufficientConfirmations(uint256 required, uint256 actual);

    // Modifiers
    modifier onlySigner() {
        if (!isSigner[msg.sender]) revert NotSigner();
        _;
    }

    modifier txExists(uint256 txId) {
        if (txId == 0 || txId > transactionCount) revert TransactionNotFound(txId);
        _;
    }

    modifier notExecuted(uint256 txId) {
        if (transactions[txId].executed) revert AlreadyExecuted(txId);
        _;
    }

    /**
     * @notice Constructor
     * @param _signers Array of signer addresses
     * @param _required Number of required signatures
     * @param _landRegistry Address of LandRegistry contract
     */
    constructor(address[] memory _signers, uint256 _required, address _landRegistry) {
        ValidationLib.validateAddress(_landRegistry);

        if (_signers.length == 0) revert InvalidRequirement();
        if (_required == 0 || _required > _signers.length) revert InvalidRequirement();

        for (uint256 i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            ValidationLib.validateAddress(signer);

            if (isSigner[signer]) continue; // Skip duplicates

            signers.push(signer);
            isSigner[signer] = true;

            emit SignerAdded(signer);
        }

        requiredSignatures = _required;
        landRegistry = ILandRegistry(_landRegistry);

        emit RequirementChanged(_required);
    }

    /**
     * @notice Submit a transaction for verification
     * @param txType Type of transaction
     * @param propertyId Property ID (for property operations)
     * @param targetAddress Target address (for verifier operations)
     * @param data Additional data
     * @return txId Transaction ID
     */
    function submitTransaction(TransactionType txType, bytes32 propertyId, address targetAddress, string memory data)
        external
        onlySigner
        returns (uint256 txId)
    {
        txId = ++transactionCount;

        Transaction storage newTx = transactions[txId];
        newTx.id = txId;
        newTx.txType = txType;
        newTx.propertyId = propertyId;
        newTx.targetAddress = targetAddress;
        newTx.data = data;
        newTx.confirmations = 0;
        newTx.executed = false;
        newTx.createdAt = block.timestamp;

        emit TransactionSubmitted(txId, txType, msg.sender);

        // Auto-confirm for submitter
        confirmTransaction(txId);

        return txId;
    }

    /**
     * @notice Confirm a transaction
     * @param txId Transaction ID
     */
    function confirmTransaction(uint256 txId) public onlySigner txExists(txId) notExecuted(txId) {
        Transaction storage transaction = transactions[txId];

        if (transaction.isConfirmed[msg.sender]) revert AlreadyConfirmed(txId);

        transaction.isConfirmed[msg.sender] = true;
        transaction.confirmations += 1;

        emit TransactionConfirmed(txId, msg.sender);

        // Auto-execute if threshold reached
        if (transaction.confirmations >= requiredSignatures) {
            executeTransaction(txId);
        }
    }

    /**
     * @notice Revoke confirmation
     * @param txId Transaction ID
     */
    function revokeConfirmation(uint256 txId) external onlySigner txExists(txId) notExecuted(txId) {
        Transaction storage transaction = transactions[txId];

        if (!transaction.isConfirmed[msg.sender]) revert NotConfirmed(txId);

        transaction.isConfirmed[msg.sender] = false;
        transaction.confirmations -= 1;

        emit TransactionRevoked(txId, msg.sender);
    }

    /**
     * @notice Execute a confirmed transaction
     * @param txId Transaction ID
     */
    function executeTransaction(uint256 txId) public nonReentrant txExists(txId) notExecuted(txId) {
        Transaction storage transaction = transactions[txId];

        if (transaction.confirmations < requiredSignatures) {
            revert InsufficientConfirmations(requiredSignatures, transaction.confirmations);
        }

        transaction.executed = true;

        // Execute based on type
        if (transaction.txType == TransactionType.VerifyProperty) {
            landRegistry.verifyProperty(transaction.propertyId, true);
        } else if (transaction.txType == TransactionType.RejectProperty) {
            landRegistry.verifyProperty(transaction.propertyId, false);
        } else if (transaction.txType == TransactionType.SlashProperty) {
            landRegistry.slashProperty(transaction.propertyId, transaction.data);
        } else if (transaction.txType == TransactionType.PauseToken) {
            ILandToken(transaction.targetAddress).pause();
        } else if (transaction.txType == TransactionType.AddVerifier) {
            landRegistry.addVerifier(transaction.targetAddress);
        } else if (transaction.txType == TransactionType.RemoveVerifier) {
            landRegistry.removeVerifier(transaction.targetAddress);
        }

        emit TransactionExecuted(txId);
    }

    /**
     * @notice Add a new signer (requires multisig)
     * @param newSigner Address to add
     */
    function addSigner(address newSigner) external onlySigner {
        ValidationLib.validateAddress(newSigner);

        if (isSigner[newSigner]) return;

        signers.push(newSigner);
        isSigner[newSigner] = true;

        emit SignerAdded(newSigner);
    }

    /**
     * @notice Remove a signer (requires multisig)
     * @param signer Address to remove
     */
    function removeSigner(address signer) external onlySigner {
        if (!isSigner[signer]) return;

        isSigner[signer] = false;

        // Remove from array
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }

        // Adjust required signatures if needed
        if (requiredSignatures > signers.length) {
            requiredSignatures = signers.length;
            emit RequirementChanged(requiredSignatures);
        }

        emit SignerRemoved(signer);
    }

    /**
     * @notice Change required signatures (requires multisig)
     * @param _required New required count
     */
    function changeRequirement(uint256 _required) external onlySigner {
        if (_required == 0 || _required > signers.length) revert InvalidRequirement();

        requiredSignatures = _required;

        emit RequirementChanged(_required);
    }

    /**
     * @notice Get transaction details
     * @param txId Transaction ID
     * @return id Transaction ID
     * @return txType Transaction type
     * @return propertyId Property ID
     * @return targetAddress Target address
     * @return data Additional data
     * @return confirmations Confirmation count
     * @return executed Execution status
     */
    function getTransaction(uint256 txId)
        external
        view
        returns (
            uint256 id,
            TransactionType txType,
            bytes32 propertyId,
            address targetAddress,
            string memory data,
            uint256 confirmations,
            bool executed
        )
    {
        Transaction storage transaction = transactions[txId];

        return (
            transaction.id,
            transaction.txType,
            transaction.propertyId,
            transaction.targetAddress,
            transaction.data,
            transaction.confirmations,
            transaction.executed
        );
    }

    /**
     * @notice Check if address confirmed transaction
     * @param txId Transaction ID
     * @param signer Signer address
     * @return bool True if confirmed
     */
    function isConfirmedBy(uint256 txId, address signer) external view returns (bool) {
        return transactions[txId].isConfirmed[signer];
    }

    /**
     * @notice Get number of signers
     * @return uint256 Signer count
     */
    function getSignerCount() external view returns (uint256) {
        return signers.length;
    }

    /**
     * @notice Get all signers
     * @return address[] Array of signers
     */
    function getSigners() external view returns (address[] memory) {
        return signers;
    }

    /**
     * @notice Get pending transactions (not executed)
     * @return uint256[] Array of pending transaction IDs
     */
    function getPendingTransactions() external view returns (uint256[] memory) {
        uint256 pendingCount = 0;

        // Count pending
        for (uint256 i = 1; i <= transactionCount; i++) {
            if (!transactions[i].executed) {
                pendingCount++;
            }
        }

        // Populate array
        uint256[] memory pending = new uint256[](pendingCount);
        uint256 index = 0;

        for (uint256 i = 1; i <= transactionCount; i++) {
            if (!transactions[i].executed) {
                pending[index++] = i;
            }
        }

        return pending;
    }
}
