import { sepolia } from "thirdweb/chains";

// ThirdWeb Configuration
export const THIRDWEB_CLIENT_ID = process.env.NEXT_PUBLIC_THIRDWEB_CLIENT_ID!;

// Network Configuration
export const CHAIN_ID = parseInt(process.env.NEXT_PUBLIC_CHAIN_ID || "11155111");
export const ACTIVE_CHAIN = sepolia;

// Contract Addresses
export const CONTRACT_ADDRESSES = {
  landRegistry: process.env.NEXT_PUBLIC_LAND_REGISTRY as `0x${string}`,
  stakingVault: process.env.NEXT_PUBLIC_STAKING_VAULT as `0x${string}`,
  tokenFactory: process.env.NEXT_PUBLIC_TOKEN_FACTORY as `0x${string}`,
  primaryMarket: process.env.NEXT_PUBLIC_PRIMARY_MARKET as `0x${string}`,
  liquidityBootstrap: process.env.NEXT_PUBLIC_LIQUIDITY_BOOTSTRAP as `0x${string}`,
  priceOracle: process.env.NEXT_PUBLIC_PRICE_ORACLE as `0x${string}`,
  agencyMultisig: process.env.NEXT_PUBLIC_AGENCY_MULTISIG as `0x${string}`,
  usdc: process.env.NEXT_PUBLIC_USDC as `0x${string}`,
};

// Block Explorer
export const BLOCK_EXPLORER = process.env.NEXT_PUBLIC_BLOCK_EXPLORER || "https://sepolia.etherscan.io";

// Constants
export const TOKEN_PRICE = 10; // 10 USDC per token
export const MIN_STAKE_PERCENTAGE = 5; // 5% of valuation
export const SALE_DURATION = 72 * 60 * 60; // 72 hours in seconds
export const MAX_PURCHASE_PERCENTAGE = 10; // 10% max per buyer
