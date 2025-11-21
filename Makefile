.PHONY: all test clean install update build deploy-sepolia deploy-amoy deploy-polygon

# Load environment variables
-include .env

# Colors for output
GREEN := \033[0;32m
NC := \033[0m # No Color

all: clean install build test

###################
# Install & Setup #
###################

install:
	@echo "$(GREEN)Installing dependencies...$(NC)"
	forge install

update:
	@echo "$(GREEN)Updating dependencies...$(NC)"
	forge update

###################
# Build & Test    #
###################

build:
	@echo "$(GREEN)Building contracts...$(NC)"
	forge build

test:
	@echo "$(GREEN)Running tests...$(NC)"
	forge test -vvv

test-unit:
	@echo "$(GREEN)Running unit tests...$(NC)"
	forge test --match-path "test/unit/**/*.sol" -vvv

test-integration:
	@echo "$(GREEN)Running integration tests...$(NC)"
	forge test --match-path "test/integration/**/*.sol" -vvv

test-fork-sepolia:
	@echo "$(GREEN)Running fork tests on Sepolia...$(NC)"
	forge test --match-path "test/fork/**/*.sol" --fork-url $(SEPOLIA_RPC_URL) -vvv

test-fork-amoy:
	@echo "$(GREEN)Running fork tests on Amoy...$(NC)"
	forge test --match-path "test/fork/**/*.sol" --fork-url $(AMOY_RPC_URL) -vvv

coverage:
	@echo "$(GREEN)Generating coverage report...$(NC)"
	forge coverage

gas-report:
	@echo "$(GREEN)Generating gas report...$(NC)"
	forge test --gas-report

snapshot:
	@echo "$(GREEN)Creating gas snapshot...$(NC)"
	forge snapshot

clean:
	@echo "$(GREEN)Cleaning build artifacts...$(NC)"
	forge clean
	rm -rf out cache

format:
	@echo "$(GREEN)Formatting code...$(NC)"
	forge fmt

###################
# Deployment      #
###################

# Deploy to Sepolia
deploy-sepolia:
	@echo "$(GREEN)Deploying to Sepolia...$(NC)"
	forge script script/DeployCore.s.sol:DeployCore --rpc-url sepolia --broadcast --verify -vvvv

# Deploy to Polygon Amoy Testnet
deploy-amoy:
	@echo "$(GREEN)Deploying to Polygon Amoy...$(NC)"
	forge script script/DeployCore.s.sol:DeployCore --rpc-url amoy --broadcast --verify -vvvv

# Deploy to Polygon Mainnet
deploy-polygon:
	@echo "$(GREEN)Deploying to Polygon Mainnet...$(NC)"
	forge script script/DeployCore.s.sol:DeployCore --rpc-url polygon --broadcast --verify -vvvv

# Deploy to local Anvil
deploy-local:
	@echo "$(GREEN)Deploying to local Anvil...$(NC)"
	forge script script/DeployCore.s.sol:DeployCore --rpc-url localhost --broadcast -vvvv

###################
# Verification    #
###################

verify-sepolia:
	@echo "$(GREEN)Verifying contracts on Sepolia Etherscan...$(NC)"
	forge verify-contract --chain-id 11155111 --watch $(CONTRACT_ADDRESS) $(CONTRACT_NAME) --etherscan-api-key $(ETHERSCAN_API_KEY)

verify-amoy:
	@echo "$(GREEN)Verifying contracts on Amoy PolygonScan...$(NC)"
	forge verify-contract --chain-id 80002 --watch $(CONTRACT_ADDRESS) $(CONTRACT_NAME) --etherscan-api-key $(POLYGONSCAN_API_KEY)

verify-polygon:
	@echo "$(GREEN)Verifying contracts on Polygon PolygonScan...$(NC)"
	forge verify-contract --chain-id 137 --watch $(CONTRACT_ADDRESS) $(CONTRACT_NAME) --etherscan-api-key $(POLYGONSCAN_API_KEY)

###################
# Interactions    #
###################

# Register a property
register-property:
	@echo "$(GREEN)Registering property...$(NC)"
	forge script script/Interactions.s.sol:RegisterProperty --rpc-url $(RPC_URL) --broadcast -vvv

# Verify a property
verify-property:
	@echo "$(GREEN)Verifying property...$(NC)"
	forge script script/Interactions.s.sol:VerifyProperty --rpc-url $(RPC_URL) --broadcast -vvv

# Buy tokens from primary market
buy-tokens:
	@echo "$(GREEN)Buying tokens...$(NC)"
	forge script script/Interactions.s.sol:BuyTokens --rpc-url $(RPC_URL) --broadcast -vvv

# Create liquidity pool
create-pool:
	@echo "$(GREEN)Creating liquidity pool...$(NC)"
	forge script script/Interactions.s.sol:CreatePool --rpc-url $(RPC_URL) --broadcast -vvv

###################
# Local Testing   #
###################

# Start local Anvil node
anvil:
	@echo "$(GREEN)Starting Anvil local node...$(NC)"
	anvil --chain-id 31337

# Deploy and test locally
local-test: deploy-local
	@echo "$(GREEN)Running local deployment test...$(NC)"

###################
# Documentation   #
###################

docs:
	@echo "$(GREEN)Generating documentation...$(NC)"
	forge doc

###################
# Help            #
###################

help:
	@echo "Available targets:"
	@echo "  install           - Install dependencies"
	@echo "  build             - Build contracts"
	@echo "  test              - Run all tests"
	@echo "  test-unit         - Run unit tests"
	@echo "  test-integration  - Run integration tests"
	@echo "  deploy-sepolia    - Deploy to Sepolia"
	@echo "  deploy-amoy       - Deploy to Polygon Amoy"
	@echo "  deploy-polygon    - Deploy to Polygon Mainnet"
	@echo "  verify-sepolia    - Verify on Sepolia Etherscan"
	@echo "  verify-amoy       - Verify on Amoy PolygonScan"
	@echo "  clean             - Remove build artifacts"
	@echo "  format            - Format code"
	@echo "  anvil             - Start local Anvil node"
