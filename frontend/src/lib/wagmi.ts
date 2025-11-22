import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia, polygonAmoy, polygon } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'RWA Tokenization',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'YOUR_PROJECT_ID',
  chains: [sepolia, polygonAmoy, polygon],
  ssr: true,
});
