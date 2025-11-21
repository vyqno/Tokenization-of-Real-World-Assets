// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LandLib } from "../libraries/LandLib.sol";

/**
 * @title ILandRegistry
 * @notice Interface for the LandRegistry contract
 */
interface ILandRegistry {
    // Events
    event PropertyRegistered(bytes32 indexed propertyId, address indexed owner, uint256 valuation);
    event PropertyVerified(bytes32 indexed propertyId, address indexed tokenAddress);
    event PropertyRejected(bytes32 indexed propertyId, string reason);
    event PropertySlashed(bytes32 indexed propertyId, uint256 slashedAmount);
    event VerifierAdded(address indexed verifier);
    event VerifierRemoved(address indexed verifier);
    event StakingVaultUpdated(address indexed oldVault, address indexed newVault);
    event TokenFactoryUpdated(address indexed oldFactory, address indexed newFactory);

    // Functions
    function registerProperty(LandLib.PropertyMetadata calldata metadata, uint256 stakeAmount)
        external
        returns (bytes32 propertyId);

    function verifyProperty(bytes32 propertyId, bool approved) external;

    function slashProperty(bytes32 propertyId, string calldata evidence) external;

    function getPropertyData(bytes32 propertyId) external view returns (LandLib.PropertyData memory);

    function getPropertyStatus(bytes32 propertyId) external view returns (LandLib.PropertyStatus);

    function getOwnerProperties(address owner) external view returns (bytes32[] memory);

    function isVerifier(address account) external view returns (bool);

    function addVerifier(address verifier) external;

    function removeVerifier(address verifier) external;

    function setStakingVault(address vault) external;

    function setTokenFactory(address factory) external;

    function calculateMinStake(uint256 valuation) external pure returns (uint256);
}
