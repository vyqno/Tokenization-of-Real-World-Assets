// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { LandRegistry } from "../../src/core/LandRegistry.sol";
import { StakingVault } from "../../src/core/StakingVault.sol";
import { TokenFactory } from "../../src/core/TokenFactory.sol";
import { LandToken } from "../../src/core/LandToken.sol";
import { PrimaryMarket } from "../../src/trading/PrimaryMarket.sol";
import { LiquidityBootstrap } from "../../src/trading/LiquidityBootstrap.sol";
import { PriceOracle } from "../../src/trading/PriceOracle.sol";
import { LandGovernor } from "../../src/governance/LandGovernor.sol";
import { AgencyMultisig } from "../../src/governance/AgencyMultisig.sol";
import { LandLib } from "../../src/libraries/LandLib.sol";
import { MockERC20 } from "./Mocks.sol";
import { MockUniswapV2Factory } from "./Mocks.sol";
import { MockUniswapV2Router } from "./Mocks.sol";

/**
 * @title TestBase
 * @notice Base contract for all tests with common setup and utilities
 */
abstract contract TestBase is Test {
    // Core contracts
    LandRegistry public landRegistry;
    StakingVault public stakingVault;
    TokenFactory public tokenFactory;
    PrimaryMarket public primaryMarket;
    LiquidityBootstrap public liquidityBootstrap;
    PriceOracle public priceOracle;
    AgencyMultisig public agencyMultisig;

    // Mock tokens
    MockERC20 public usdc;
    MockUniswapV2Factory public uniswapFactory;
    MockUniswapV2Router public uniswapRouter;

    // Test accounts
    address public owner;
    address public verifier;
    address public treasury;
    address public landowner;
    address public buyer1;
    address public buyer2;
    address public buyer3;

    // Constants
    uint256 public constant INITIAL_BALANCE = 10_000_000e6; // 10M USDC
    uint256 public constant PROPERTY_VALUATION = 6_900_000e6; // ₹69 Lakhs
    uint256 public constant MIN_STAKE = 345_000e6; // 5% of valuation

    function setUp() public virtual {
        // Setup accounts
        owner = address(this);
        verifier = makeAddr("verifier");
        treasury = makeAddr("treasury");
        landowner = makeAddr("landowner");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");

        // Deploy mock tokens and DEX
        usdc = new MockERC20("USD Coin", "USDC", 6);
        uniswapFactory = new MockUniswapV2Factory();
        uniswapRouter = new MockUniswapV2Router(address(uniswapFactory));

        // Fund test accounts
        _fundAccounts();

        // Deploy core protocol
        _deployCoreContracts();

        // Setup roles and permissions
        _setupRoles();
    }

    function _fundAccounts() internal {
        usdc.mint(owner, INITIAL_BALANCE);
        usdc.mint(landowner, INITIAL_BALANCE);
        usdc.mint(buyer1, INITIAL_BALANCE);
        usdc.mint(buyer2, INITIAL_BALANCE);
        usdc.mint(buyer3, INITIAL_BALANCE);
        usdc.mint(treasury, INITIAL_BALANCE);
    }

    function _deployCoreContracts() internal {
        // Deploy in correct dependency order
        landRegistry = new LandRegistry();

        stakingVault = new StakingVault(address(usdc), address(landRegistry), treasury);

        tokenFactory = new TokenFactory(address(landRegistry), treasury);

        primaryMarket = new PrimaryMarket(address(landRegistry), address(usdc));

        liquidityBootstrap = new LiquidityBootstrap(address(uniswapRouter), address(uniswapFactory), address(usdc));

        priceOracle = new PriceOracle(address(uniswapFactory), address(usdc));

        // Setup multi-sig
        address[] memory signers = new address[](2);
        signers[0] = owner;
        signers[1] = verifier;

        agencyMultisig = new AgencyMultisig(
            signers,
            1, // 1 signature for testing
            address(landRegistry)
        );
    }

    function _setupRoles() internal {
        landRegistry.setStakingVault(address(stakingVault));
        landRegistry.setTokenFactory(address(tokenFactory));
        landRegistry.addVerifier(verifier);
        landRegistry.addVerifier(address(agencyMultisig));

        // Fund staking vault with enough USDC to pay bonuses
        usdc.mint(address(stakingVault), INITIAL_BALANCE);
    }

    // Helper functions for tests
    function createPropertyMetadata() public pure returns (LandLib.PropertyMetadata memory) {
        return LandLib.PropertyMetadata({
            surveyNumber: "123/A",
            location: "Kengeri, Bangalore",
            latitude: 12_970_000,
            longitude: 77_490_000,
            areaSqFt: 10_000,
            ipfsHash: "QmExampleHash123456789abcdefghijklmnopqrstuv",
            valuation: PROPERTY_VALUATION
        });
    }

    function stakeAndRegisterProperty(address propertyOwner, uint256 stakeAmount) public returns (bytes32 propertyId) {
        vm.startPrank(propertyOwner);

        // Approve and stake
        usdc.approve(address(stakingVault), stakeAmount);
        stakingVault.depositStake(stakeAmount);

        // Register property
        LandLib.PropertyMetadata memory metadata = createPropertyMetadata();
        propertyId = landRegistry.registerProperty(metadata, stakeAmount);

        vm.stopPrank();

        return propertyId;
    }

    function verifyProperty(bytes32 propertyId, bool approved) public {
        vm.prank(verifier);
        landRegistry.verifyProperty(propertyId, approved);
    }

    function getTokenFromProperty(bytes32 propertyId) public view returns (address) {
        LandLib.PropertyData memory propData = landRegistry.getPropertyData(propertyId);
        return propData.tokenAddress;
    }

    // Assertion helpers
    function assertPropertyStatus(bytes32 propertyId, LandLib.PropertyStatus expectedStatus) public view {
        LandLib.PropertyStatus actualStatus = landRegistry.getPropertyStatus(propertyId);
        assertEq(uint256(actualStatus), uint256(expectedStatus), "Property status mismatch");
    }

    function assertUSDCBalance(address account, uint256 expectedBalance) public view {
        uint256 actualBalance = usdc.balanceOf(account);
        assertEq(actualBalance, expectedBalance, "USDC balance mismatch");
    }

    function assertTokenBalance(address token, address account, uint256 expectedBalance) public view {
        uint256 actualBalance = MockERC20(token).balanceOf(account);
        assertEq(actualBalance, expectedBalance, "Token balance mismatch");
    }
}
