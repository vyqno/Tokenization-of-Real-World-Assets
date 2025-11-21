// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LandLib
 * @notice Shared library containing structs, enums, and helper functions for the Land Token Protocol
 * @dev Used across all core contracts to maintain consistency
 */
library LandLib {
    /**
     * @notice Status of a property in the tokenization lifecycle
     */
    enum PropertyStatus {
        None, // Not registered
        Pending, // Awaiting verification
        Verified, // Approved, tokens minted
        Rejected, // Denied, stake refunded
        Slashed, // Fraudulent, stake seized
        Trading // Active on DEX

    }

    /**
     * @notice Metadata about a physical property
     * @dev All strings are expected to follow specific formats
     */
    struct PropertyMetadata {
        string surveyNumber; // Government survey number (e.g., "123/A")
        string location; // City/area name (e.g., "Kengeri, Bangalore")
        int256 latitude; // GPS coordinate (scaled by 1e6, e.g., 12970000 = 12.97)
        int256 longitude; // GPS coordinate (scaled by 1e6, e.g., 77490000 = 77.49)
        uint256 areaSqFt; // Land area in square feet
        string ipfsHash; // IPFS hash of property documents
        uint256 valuation; // Property value in smallest unit (e.g., USDC with 6 decimals)
    }

    /**
     * @notice Complete data for a registered property
     * @dev Combines metadata with registration/verification data
     */
    struct PropertyData {
        bytes32 id; // Unique property identifier (hash)
        address owner; // Property owner's address
        PropertyMetadata metadata; // Property details
        PropertyStatus status; // Current status
        uint256 stakeAmount; // USDC staked for verification
        address tokenAddress; // Address of minted ERC20 token (if verified)
        uint256 registeredAt; // Timestamp of registration
        uint256 verifiedAt; // Timestamp of verification (0 if not verified)
    }

    /**
     * @notice Configuration for token allocation
     */
    struct TokenAllocation {
        uint256 totalSupply; // Total tokens to mint
        uint256 ownerAllocation; // Tokens for property owner (51%)
        uint256 platformFee; // Platform fee in tokens (2.5%)
        uint256 publicSale; // Tokens for public sale
    }

    /**
     * @dev Custom errors for gas-efficient reverts
     */
    error InvalidSurveyNumber();
    error InvalidLocation();
    error InvalidCoordinates();
    error InvalidArea();
    error InvalidValuation();
    error InvalidIPFSHash();

    /**
     * @notice Validates property metadata
     * @param metadata The PropertyMetadata struct to validate
     * @return bool True if valid
     */
    function validateMetadata(PropertyMetadata memory metadata) internal pure returns (bool) {
        // Survey number must not be empty
        if (bytes(metadata.surveyNumber).length == 0) revert InvalidSurveyNumber();

        // Location must not be empty
        if (bytes(metadata.location).length == 0) revert InvalidLocation();

        // Coordinates must be non-zero and within valid ranges
        // Latitude: -90 to +90 degrees (scaled by 1e6)
        // Longitude: -180 to +180 degrees (scaled by 1e6)
        if (
            metadata.latitude == 0 || metadata.longitude == 0 || metadata.latitude < -90_000_000
                || metadata.latitude > 90_000_000 || metadata.longitude < -180_000_000 || metadata.longitude > 180_000_000
        ) {
            revert InvalidCoordinates();
        }

        // Area must be greater than 0
        if (metadata.areaSqFt == 0) revert InvalidArea();

        // Valuation must be greater than 0
        if (metadata.valuation == 0) revert InvalidValuation();

        // IPFS hash must not be empty (basic check)
        if (bytes(metadata.ipfsHash).length == 0) revert InvalidIPFSHash();

        return true;
    }

    /**
     * @notice Calculates token allocation based on property valuation
     * @param valuation Property value in smallest unit
     * @param tokenPriceInValuation Price per token (e.g., 10 USDC = 10e6)
     * @return allocation TokenAllocation struct with calculated values
     */
    function calculateTokenAllocation(uint256 valuation, uint256 tokenPriceInValuation)
        internal
        pure
        returns (TokenAllocation memory allocation)
    {
        // Total supply = (valuation / token price) * 10^18 (ERC20 standard with 18 decimals)
        // e.g., ₹69,00,000 / ₹10 = 690,000 tokens → 690,000e18
        allocation.totalSupply = (valuation / tokenPriceInValuation) * 1e18;

        // Platform fee: 2.5% of total supply (250 basis points)
        allocation.platformFee = (allocation.totalSupply * 250) / 10_000;

        // Owner allocation: 51% of TOTAL supply
        allocation.ownerAllocation = (allocation.totalSupply * 51) / 100;

        // Public sale: remaining tokens (total - platform fee - owner allocation)
        allocation.publicSale = allocation.totalSupply - allocation.platformFee - allocation.ownerAllocation;

        return allocation;
    }

    /**
     * @notice Generates a unique property ID from metadata
     * @param metadata Property metadata
     * @param timestamp Registration timestamp
     * @return bytes32 Unique property ID
     */
    function generatePropertyId(PropertyMetadata memory metadata, uint256 timestamp) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(metadata.surveyNumber, metadata.latitude, metadata.longitude, timestamp));
    }

    /**
     * @notice Calculates minimum stake required (5% of valuation)
     * @param valuation Property valuation
     * @return uint256 Minimum stake amount
     */
    function calculateMinStake(uint256 valuation) internal pure returns (uint256) {
        return (valuation * 5) / 100;
    }

    /**
     * @notice Checks if a status transition is valid
     * @param from Current status
     * @param to New status
     * @return bool True if transition is allowed
     */
    function isValidStatusTransition(PropertyStatus from, PropertyStatus to) internal pure returns (bool) {
        // None -> Pending (initial registration)
        if (from == PropertyStatus.None && to == PropertyStatus.Pending) return true;

        // Pending -> Verified (approval)
        if (from == PropertyStatus.Pending && to == PropertyStatus.Verified) return true;

        // Pending -> Rejected (denial)
        if (from == PropertyStatus.Pending && to == PropertyStatus.Rejected) return true;

        // Pending -> Slashed (fraud detected)
        if (from == PropertyStatus.Pending && to == PropertyStatus.Slashed) return true;

        // Verified -> Trading (tokens listed)
        if (from == PropertyStatus.Verified && to == PropertyStatus.Trading) return true;

        return false;
    }

    /**
     * @notice Extracts first word from location string for token symbol
     * @param location Location string (e.g., "Kengeri, Bangalore")
     * @return string First word in uppercase (e.g., "KENGERI")
     */
    function extractLocationPrefix(string memory location) internal pure returns (string memory) {
        bytes memory locationBytes = bytes(location);
        uint256 length = 0;

        // Find first space or comma
        for (uint256 i = 0; i < locationBytes.length && i < 10; i++) {
            if (locationBytes[i] == 0x20 || locationBytes[i] == 0x2C) {
                // space or comma
                break;
            }
            length++;
        }

        // Extract substring
        bytes memory prefix = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            prefix[i] = locationBytes[i];
        }

        return string(prefix);
    }
}
