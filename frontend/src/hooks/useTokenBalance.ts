import { useReadContract } from 'wagmi';
import LandTokenABI from '@/contracts/abis/LandToken.json';
import USDCABI from '@/contracts/abis/USDC.json';
import { contractAddresses } from '@/lib/contracts';

export function useTokenBalance(
  tokenAddress: `0x${string}` | undefined,
  userAddress: `0x${string}` | undefined
) {
  return useReadContract({
    address: tokenAddress,
    abi: LandTokenABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!tokenAddress && !!userAddress,
    },
  });
}

export function useUSDCBalance(userAddress: `0x${string}` | undefined) {
  return useReadContract({
    address: contractAddresses.usdc,
    abi: USDCABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress,
    },
  });
}

export function useUSDCAllowance(
  userAddress: `0x${string}` | undefined,
  spenderAddress: `0x${string}` | undefined
) {
  return useReadContract({
    address: contractAddresses.usdc,
    abi: USDCABI,
    functionName: 'allowance',
    args: userAddress && spenderAddress ? [userAddress, spenderAddress] : undefined,
    query: {
      enabled: !!userAddress && !!spenderAddress,
    },
  });
}
