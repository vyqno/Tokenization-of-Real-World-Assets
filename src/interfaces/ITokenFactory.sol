// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LandLib } from "../libraries/LandLib.sol";

/**
 * @title ITokenFactory
 * @notice Interface for the TokenFactory contract
 */
interface ITokenFactory {
    // Events
    event TokenCreated(
        address indexed tokenAddress, bytes32 indexed propertyId, address indexed owner, uint256 totalSupply
    );
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    // Functions
    function createLandToken(address owner, LandLib.PropertyMetadata memory metadata, bytes32 propertyId)
        external
        returns (address tokenAddress);

    function propertyToToken(bytes32 propertyId) external view returns (address);

    function allTokens(uint256 index) external view returns (address);

    function getAllTokens() external view returns (address[] memory);

    function computeTokenAddress(bytes32 propertyId) external view returns (address);

    function setFeeRecipient(address newRecipient) external;
}
