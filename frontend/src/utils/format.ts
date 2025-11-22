import { formatUnits, parseUnits } from 'viem';

export function formatAddress(address: string | undefined): string {
  if (!address) return '';
  return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
}

export function formatUSDC(value: bigint): string {
  return `$${parseFloat(formatUnits(value, 6)).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

export function formatToken(value: bigint, decimals: number = 18): string {
  return parseFloat(formatUnits(value, decimals)).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  });
}

export function parseUSDC(value: string): bigint {
  return parseUnits(value, 6);
}

export function parseTokenAmount(value: string, decimals: number = 18): bigint {
  return parseUnits(value, decimals);
}

export function formatPercentage(value: number): string {
  return `${value.toFixed(2)}%`;
}
