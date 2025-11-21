// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";

/**
 * @title HelperConfig
 * @notice Network-specific configuration for multi-chain deployment
 * @dev Supports Sepolia, Polygon Amoy, Polygon Mainnet, and local Anvil
 */
contract HelperConfig is Script {
    /**
     * @notice Network configuration struct
     */
    struct NetworkConfig {
        address usdcToken; // USDC or mock stablecoin
        address uniswapRouter; // Uniswap V2 Router (or QuickSwap on Polygon)
        address uniswapFactory; // Uniswap V2 Factory
        address deployer; // Deployer address
        uint256 deployerKey; // Private key for deployment
    }

    NetworkConfig public activeConfig;

    // Chain IDs
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant AMOY_CHAIN_ID = 80002;
    uint256 constant POLYGON_CHAIN_ID = 137;
    uint256 constant ANVIL_CHAIN_ID = 31337;

    /**
     * @notice Constructor - automatically selects config based on chain ID
     */
    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeConfig = getSepoliaConfig();
        } else if (block.chainid == AMOY_CHAIN_ID) {
            activeConfig = getAmoyConfig();
        } else if (block.chainid == POLYGON_CHAIN_ID) {
            activeConfig = getPolygonMainnetConfig();
        } else {
            activeConfig = getAnvilConfig();
        }
    }

    /**
     * @notice Get active network configuration
     */
    function getActiveConfig() public view returns (NetworkConfig memory) {
        return activeConfig;
    }

    /**
     * @notice Get Sepolia testnet configuration
     */
    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            usdcToken: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // Sepolia USDC
            uniswapRouter: 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008, // Uniswap V2 Router
            uniswapFactory: 0x7e0987E5B3A30e3F2828572BC659a3E65C8EE22c, // Uniswap V2 Factory
            deployer: msg.sender,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    /**
     * @notice Get Polygon Amoy testnet configuration
     */
    function getAmoyConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            usdcToken: 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582, // Amoy USDC (mock)
            uniswapRouter: 0x8954AfA98594b838bda56FE4C12a09D7739D179b, // QuickSwap Router
            uniswapFactory: 0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32, // QuickSwap Factory
            deployer: msg.sender,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    /**
     * @notice Get Polygon mainnet configuration
     */
    function getPolygonMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            usdcToken: 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359, // Native USDC on Polygon
            uniswapRouter: 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff, // QuickSwap Router
            uniswapFactory: 0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32, // QuickSwap Factory
            deployer: msg.sender,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    /**
     * @notice Get Anvil local testnet configuration
     */
    function getAnvilConfig() public returns (NetworkConfig memory) {
        // Deploy mock tokens for local testing
        vm.startBroadcast();

        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);

        // For local testing, we'd need to deploy Uniswap contracts
        // For simplicity, using zero addresses (will need to deploy separately)
        address mockRouter = address(0);
        address mockFactory = address(0);

        vm.stopBroadcast();

        return NetworkConfig({
            usdcToken: address(usdc),
            uniswapRouter: mockRouter,
            uniswapFactory: mockFactory,
            deployer: msg.sender,
            deployerKey: vm.envOr(
                "ANVIL_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
            ) // Default Anvil key
         });
    }
}

/**
 * @title MockERC20
 * @notice Mock ERC20 token for local testing
 */
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        // Mint 1 million tokens to deployer for testing
        uint256 initialSupply = 1_000_000 * (10 ** decimals);
        balanceOf[msg.sender] = initialSupply;
        totalSupply = initialSupply;

        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // Mint function for testing
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}
