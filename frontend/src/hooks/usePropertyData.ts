import { useReadContract } from 'wagmi';
import { contractAddresses } from '@/lib/contracts';
import LandRegistryABI from '@/contracts/abis/LandRegistry.json';

export function usePropertyData(propertyId: `0x${string}`) {
  return useReadContract({
    address: contractAddresses.landRegistry,
    abi: LandRegistryABI,
    functionName: 'properties',
    args: [propertyId],
  });
}

export function useTotalPropertiesRegistered() {
  return useReadContract({
    address: contractAddresses.landRegistry,
    abi: LandRegistryABI,
    functionName: 'totalPropertiesRegistered',
  });
}

export function useTotalPropertiesVerified() {
  return useReadContract({
    address: contractAddresses.landRegistry,
    abi: LandRegistryABI,
    functionName: 'totalPropertiesVerified',
  });
}

export function useOwnerProperties(owner: `0x${string}` | undefined) {
  return useReadContract({
    address: contractAddresses.landRegistry,
    abi: LandRegistryABI,
    functionName: 'ownerProperties',
    args: owner ? [owner, BigInt(0)] : undefined,
    query: {
      enabled: !!owner,
    },
  });
}
