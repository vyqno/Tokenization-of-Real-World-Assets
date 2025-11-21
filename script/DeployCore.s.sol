// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { LandRegistry } from "../src/core/LandRegistry.sol";
import { StakingVault } from "../src/core/StakingVault.sol";
import { TokenFactory } from "../src/core/TokenFactory.sol";
import { PrimaryMarket } from "../src/trading/PrimaryMarket.sol";
import { LiquidityBootstrap } from "../src/trading/LiquidityBootstrap.sol";
import { PriceOracle } from "../src/trading/PriceOracle.sol";
import { AgencyMultisig } from "../src/governance/AgencyMultisig.sol";

/**
 * @title DeployCore
 * @notice Deploys complete LandToken Protocol infrastructure
 * @dev Deploys all core contracts in correct dependency order
 */
contract DeployCore is Script {
    // Deployed contracts
    LandRegistry public landRegistry;
    StakingVault public stakingVault;
    TokenFactory public tokenFactory;
    PrimaryMarket public primaryMarket;
    LiquidityBootstrap public liquidityBootstrap;
    PriceOracle public priceOracle;
    AgencyMultisig public agencyMultisig;

    function run()
        external
        returns (
            LandRegistry,
            StakingVault,
            TokenFactory,
            PrimaryMarket,
            LiquidityBootstrap,
            PriceOracle,
            AgencyMultisig
        )
    {
        // Load network configuration
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveConfig();

        console.log("=================================");
        console.log("Deploying LandToken Protocol");
        console.log("Network:", block.chainid);
        console.log("Deployer:", config.deployer);
        console.log("USDC:", config.usdcToken);
        console.log("=================================");

        vm.startBroadcast(config.deployerKey);

        // 1. Deploy LandRegistry
        console.log("\n1. Deploying LandRegistry...");
        landRegistry = new LandRegistry();
        console.log("  LandRegistry deployed at:", address(landRegistry));

        // 2. Deploy StakingVault
        console.log("\n2. Deploying StakingVault...");
        stakingVault = new StakingVault(
            config.usdcToken,
            address(landRegistry),
            config.deployer // Treasury
        );
        console.log("  StakingVault deployed at:", address(stakingVault));

        // 3. Deploy TokenFactory
        console.log("\n3. Deploying TokenFactory...");
        tokenFactory = new TokenFactory(
            address(landRegistry),
            config.deployer // Fee recipient
        );
        console.log("  TokenFactory deployed at:", address(tokenFactory));

        // 4. Deploy PrimaryMarket
        console.log("\n4. Deploying PrimaryMarket...");
        primaryMarket = new PrimaryMarket(address(landRegistry), config.usdcToken);
        console.log("  PrimaryMarket deployed at:", address(primaryMarket));

        // 5. Deploy LiquidityBootstrap
        console.log("\n5. Deploying LiquidityBootstrap...");
        if (config.uniswapRouter != address(0) && config.uniswapFactory != address(0)) {
            liquidityBootstrap = new LiquidityBootstrap(config.uniswapRouter, config.uniswapFactory, config.usdcToken);
            console.log("  LiquidityBootstrap deployed at:", address(liquidityBootstrap));
        } else {
            console.log("  Skipping LiquidityBootstrap (no DEX on this network)");
        }

        // 6. Deploy PriceOracle
        console.log("\n6. Deploying PriceOracle...");
        if (config.uniswapFactory != address(0)) {
            priceOracle = new PriceOracle(config.uniswapFactory, config.usdcToken);
            console.log("  PriceOracle deployed at:", address(priceOracle));
        } else {
            console.log("  Skipping PriceOracle (no DEX on this network)");
        }

        // 7. Deploy AgencyMultisig
        console.log("\n7. Deploying AgencyMultisig...");
        address[] memory signers = new address[](1);
        signers[0] = config.deployer;

        agencyMultisig = new AgencyMultisig(
            signers,
            1, // Only 1 signature required for hackathon
            address(landRegistry)
        );
        console.log("  AgencyMultisig deployed at:", address(agencyMultisig));

        // 8. Configure LandRegistry
        console.log("\n8. Configuring LandRegistry...");
        landRegistry.setStakingVault(address(stakingVault));
        landRegistry.setTokenFactory(address(tokenFactory));
        landRegistry.addVerifier(config.deployer);
        landRegistry.addVerifier(address(agencyMultisig));
        console.log("  Configuration complete");

        vm.stopBroadcast();

        // Print summary
        console.log("\n=================================");
        console.log("Deployment Summary");
        console.log("=================================");
        console.log("LandRegistry:", address(landRegistry));
        console.log("StakingVault:", address(stakingVault));
        console.log("TokenFactory:", address(tokenFactory));
        console.log("PrimaryMarket:", address(primaryMarket));
        console.log("LiquidityBootstrap:", address(liquidityBootstrap));
        console.log("PriceOracle:", address(priceOracle));
        console.log("AgencyMultisig:", address(agencyMultisig));
        console.log("=================================");

        // Save deployment addresses to file
        _saveDeployment(config);

        return
            (landRegistry, stakingVault, tokenFactory, primaryMarket, liquidityBootstrap, priceOracle, agencyMultisig);
    }

    /**
     * @notice Save deployment addresses to JSON file
     */
    function _saveDeployment(HelperConfig.NetworkConfig memory config) internal {
        string memory chainName = _getChainName(block.chainid);
        string memory fileName = string(abi.encodePacked("deployments/", chainName, ".json"));

        string memory json = string(
            abi.encodePacked(
                "{\n",
                '  "chainId": ',
                vm.toString(block.chainid),
                ",\n",
                '  "network": "',
                chainName,
                '",\n',
                '  "deployer": "',
                vm.toString(config.deployer),
                '",\n',
                '  "contracts": {\n',
                '    "LandRegistry": "',
                vm.toString(address(landRegistry)),
                '",\n',
                '    "StakingVault": "',
                vm.toString(address(stakingVault)),
                '",\n',
                '    "TokenFactory": "',
                vm.toString(address(tokenFactory)),
                '",\n',
                '    "PrimaryMarket": "',
                vm.toString(address(primaryMarket)),
                '",\n',
                '    "LiquidityBootstrap": "',
                vm.toString(address(liquidityBootstrap)),
                '",\n',
                '    "PriceOracle": "',
                vm.toString(address(priceOracle)),
                '",\n',
                '    "AgencyMultisig": "',
                vm.toString(address(agencyMultisig)),
                '"\n',
                "  }\n",
                "}"
            )
        );

        vm.writeFile(fileName, json);
        console.log("\nDeployment addresses saved to:", fileName);
    }

    /**
     * @notice Get chain name from chain ID
     */
    function _getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 11155111) return "sepolia";
        if (chainId == 80002) return "amoy";
        if (chainId == 137) return "polygon";
        if (chainId == 31337) return "anvil";
        return "unknown";
    }
}
