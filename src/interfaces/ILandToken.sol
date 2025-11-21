// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { LandLib } from "../libraries/LandLib.sol";

/**
 * @title ILandToken
 * @notice Interface for the LandToken contract
 */
interface ILandToken is IERC20 {
    // Token status enum
    enum TokenStatus {
        Pending,
        Verified,
        Trading
    }

    // Events
    event StatusChanged(TokenStatus indexed oldStatus, TokenStatus indexed newStatus);
    event PropertyMetadataUpdated(string ipfsHash);

    // Functions
    function initialize(
        address _owner,
        uint256 _totalSupply,
        uint256 _ownerAllocation,
        LandLib.PropertyMetadata memory metadata,
        bytes32 _propertyId
    ) external;

    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;

    function activateTrading() external;

    function pause() external;

    function unpause() external;

    function updateIPFSHash(string memory newHash) external;

    // View functions
    function LAND_REGISTRY() external view returns (address);

    function PROPERTY_ID() external view returns (bytes32);

    function ipfsDocumentHash() external view returns (string memory);

    function latitude() external view returns (int256);

    function longitude() external view returns (int256);

    function landAreaSqFt() external view returns (uint256);

    function initialValuation() external view returns (uint256);

    function originalOwner() external view returns (address);

    function ownerAllocation() external view returns (uint256);

    function status() external view returns (TokenStatus);

    function deploymentTimestamp() external view returns (uint256);

    function getTokenInfo()
        external
        view
        returns (
            string memory name_,
            string memory symbol_,
            uint256 totalSupply_,
            address owner_,
            TokenStatus status_,
            uint256 valuation_
        );

    function getPropertyMetadata()
        external
        view
        returns (string memory ipfs, int256 lat, int256 lon, uint256 area, uint256 valuation);
}
