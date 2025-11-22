import { getContract } from "thirdweb";
import { client } from "@/lib/thirdweb";
import { ACTIVE_CHAIN, CONTRACT_ADDRESSES } from "@/lib/config";
import LandRegistryABI from "@/contracts/abis/LandRegistry.json";
import PrimaryMarketABI from "@/contracts/abis/PrimaryMarket.json";
import LandTokenABI from "@/contracts/abis/LandToken.json";
import USDCABI from "@/contracts/abis/USDC.json";

export function useLandRegistryContract() {
  return getContract({
    client,
    chain: ACTIVE_CHAIN,
    address: CONTRACT_ADDRESSES.landRegistry,
    abi: LandRegistryABI,
  });
}

export function usePrimaryMarketContract() {
  return getContract({
    client,
    chain: ACTIVE_CHAIN,
    address: CONTRACT_ADDRESSES.primaryMarket,
    abi: PrimaryMarketABI,
  });
}

export function useUSDCContract() {
  return getContract({
    client,
    chain: ACTIVE_CHAIN,
    address: CONTRACT_ADDRESSES.usdc,
    abi: USDCABI,
  });
}

export function useLandTokenContract(tokenAddress: string) {
  return getContract({
    client,
    chain: ACTIVE_CHAIN,
    address: tokenAddress,
    abi: LandTokenABI,
  });
}

export function useStakingVaultContract() {
  return getContract({
    client,
    chain: ACTIVE_CHAIN,
    address: CONTRACT_ADDRESSES.stakingVault,
  });
}
