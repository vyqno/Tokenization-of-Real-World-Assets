import { useReadContract } from 'wagmi';
import { contractAddresses } from '@/lib/contracts';
import PrimaryMarketABI from '@/contracts/abis/PrimaryMarket.json';

export function useSaleData(tokenAddress: `0x${string}` | undefined) {
  return useReadContract({
    address: contractAddresses.primaryMarket,
    abi: PrimaryMarketABI,
    functionName: 'sales',
    args: tokenAddress ? [tokenAddress] : undefined,
    query: {
      enabled: !!tokenAddress,
    },
  });
}

export function useUserPurchases(
  tokenAddress: `0x${string}` | undefined,
  userAddress: `0x${string}` | undefined
) {
  return useReadContract({
    address: contractAddresses.primaryMarket,
    abi: PrimaryMarketABI,
    functionName: 'purchases',
    args: tokenAddress && userAddress ? [tokenAddress, userAddress] : undefined,
    query: {
      enabled: !!tokenAddress && !!userAddress,
    },
  });
}
