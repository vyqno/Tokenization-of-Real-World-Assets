export enum PropertyStatus {
  None,
  Pending,
  Verified,
  Rejected,
  Slashed,
  Tokenized,
}

export interface PropertyMetadata {
  location: string;
  valuation: bigint;
  area: bigint;
  legalDescription: string;
  ownerName: string;
  coordinates: string;
}

export interface PropertyData {
  owner: `0x${string}`;
  metadata: PropertyMetadata;
  status: PropertyStatus;
  tokenAddress: `0x${string}`;
  registrationTime: bigint;
  verificationTime: bigint;
  stakeAmount: bigint;
}

export interface Sale {
  tokenAddress: `0x${string}`;
  tokensForSale: bigint;
  tokensSold: bigint;
  pricePerToken: bigint;
  startTime: bigint;
  endTime: bigint;
  beneficiary: `0x${string}`;
  active: boolean;
  finalized: boolean;
}

export interface Proposal {
  id: bigint;
  proposer: `0x${string}`;
  description: string;
  forVotes: bigint;
  againstVotes: bigint;
  startBlock: bigint;
  endBlock: bigint;
  executed: boolean;
  canceled: boolean;
}
