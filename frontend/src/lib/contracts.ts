export const contractAddresses = {
  landRegistry: process.env.NEXT_PUBLIC_LAND_REGISTRY_ADDRESS as `0x${string}`,
  stakingVault: process.env.NEXT_PUBLIC_STAKING_VAULT_ADDRESS as `0x${string}`,
  tokenFactory: process.env.NEXT_PUBLIC_TOKEN_FACTORY_ADDRESS as `0x${string}`,
  primaryMarket: process.env.NEXT_PUBLIC_PRIMARY_MARKET_ADDRESS as `0x${string}`,
  liquidityBootstrap: process.env.NEXT_PUBLIC_LIQUIDITY_BOOTSTRAP_ADDRESS as `0x${string}`,
  priceOracle: process.env.NEXT_PUBLIC_PRICE_ORACLE_ADDRESS as `0x${string}`,
  landGovernor: process.env.NEXT_PUBLIC_LAND_GOVERNOR_ADDRESS as `0x${string}`,
  agencyMultisig: process.env.NEXT_PUBLIC_AGENCY_MULTISIG_ADDRESS as `0x${string}`,
  usdc: process.env.NEXT_PUBLIC_USDC_ADDRESS as `0x${string}`,
};

export const CHAIN_ID = parseInt(process.env.NEXT_PUBLIC_CHAIN_ID || '11155111');
export const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL || '';
