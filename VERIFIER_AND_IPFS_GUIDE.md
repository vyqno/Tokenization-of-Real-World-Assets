# Verifier Authentication & IPFS Integration Guide

This guide explains how verifier authentication works and how to add IPFS storage for property documents.

---

## 🔐 Part 1: How Verifier Authentication Works

### Smart Contract Level

The `LandRegistry.sol` contract manages verifiers through a mapping:

```solidity
// In LandRegistry.sol
mapping(address => bool) public isVerifier;

modifier onlyVerifier() {
    if (!isVerifier[msg.sender]) revert NotVerifier();
    _;
}
```

**Key Functions:**
- `addVerifier(address verifier)` - Owner adds a new verifier
- `removeVerifier(address verifier)` - Owner removes a verifier
- `isVerifier(address)` - Public view function to check verifier status

**Initial Setup:**
- The contract deployer (owner) is automatically set as the first verifier
- Owner can add additional verifiers via `addVerifier()`

### Frontend Implementation

The frontend now checks verifier status using ThirdWeb SDK:

```typescript
// In governance/page.tsx
const [isVerifier, setIsVerifier] = useState(false);

async function checkVerifierStatus() {
  const verifierStatus = await readContract({
    contract: landRegistry,
    method: "function isVerifier(address) view returns (bool)",
    params: [account.address],
  }) as boolean;

  setIsVerifier(verifierStatus);
}
```

### How to Add Verifiers

**Option 1: Using Foundry Cast (Recommended for Development)**

```bash
# Add a verifier
cast send $LAND_REGISTRY_ADDRESS \
  "addVerifier(address)" \
  0xYOUR_VERIFIER_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Check if address is verifier
cast call $LAND_REGISTRY_ADDRESS \
  "isVerifier(address)(bool)" \
  0xADDRESS_TO_CHECK \
  --rpc-url $RPC_URL
```

**Option 2: Via Frontend (Admin Panel)**

Create an admin page at `/admin`:

```typescript
// frontend/src/app/admin/page.tsx
'use client';

import { useState } from 'react';
import { useActiveAccount } from "thirdweb/react";
import { prepareContractCall, sendTransaction } from "thirdweb";
import { useLandRegistryContract } from '@/hooks/useContracts';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { toast } from 'sonner';

export default function AdminPage() {
  const account = useActiveAccount();
  const landRegistry = useLandRegistryContract();
  const [verifierAddress, setVerifierAddress] = useState('');
  const [loading, setLoading] = useState(false);

  async function addVerifier() {
    if (!account || !verifierAddress) {
      toast.error('Please enter a valid address');
      return;
    }

    try {
      setLoading(true);

      const transaction = prepareContractCall({
        contract: landRegistry,
        method: "function addVerifier(address verifier)",
        params: [verifierAddress],
      });

      const { transactionHash } = await sendTransaction({
        transaction,
        account,
      });

      toast.success(`Verifier added! Tx: ${transactionHash}`);
      setVerifierAddress('');
    } catch (error: any) {
      console.error('Error adding verifier:', error);
      toast.error(error.message || 'Failed to add verifier');
    } finally {
      setLoading(false);
    }
  }

  async function removeVerifier() {
    // Similar implementation for removal
  }

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-4">Admin Panel</h1>

      <div className="space-y-4">
        <h2 className="text-xl font-semibold">Manage Verifiers</h2>

        <div className="flex gap-2">
          <Input
            type="text"
            value={verifierAddress}
            onChange={(e) => setVerifierAddress(e.target.value)}
            placeholder="0x... Verifier Address"
            className="flex-1"
          />
          <Button onClick={addVerifier} disabled={loading}>
            {loading ? 'Adding...' : 'Add Verifier'}
          </Button>
        </div>
      </div>
    </div>
  );
}
```

**Option 3: Using Etherscan/Block Explorer**

1. Go to your deployed LandRegistry contract on Etherscan
2. Go to "Write Contract" tab
3. Connect your wallet (must be contract owner)
4. Call `addVerifier` with the address
5. Confirm the transaction

### User Types in the System

| User Type | Permissions | How to Identify |
|-----------|-------------|-----------------|
| **Property Owner** | Register properties, receive tokens | Any wallet can register |
| **Verifier** | Approve/reject/slash properties | Must be added via `addVerifier()` |
| **Investor** | Buy tokens, vote on governance | Any wallet can buy |
| **Contract Owner** | Add/remove verifiers, manage system | Deployer address (Ownable) |

### Visual Indicators in UI

The governance page now shows a verifier badge:

```typescript
{isVerifier && (
  <div className="bg-green-50 dark:bg-green-900/20 rounded-lg p-4 mb-6">
    <div className="flex items-center gap-2">
      <ShieldCheck className="h-5 w-5 text-green-600" />
      <span className="font-semibold text-green-800 dark:text-green-200">
        Verifier Access Active
      </span>
    </div>
    <p className="text-sm text-green-700 dark:text-green-300 mt-1">
      You can approve, reject, or slash property registrations
    </p>
  </div>
)}
```

---

## 📦 Part 2: IPFS Integration (Currently NOT Implemented)

### Current Implementation

**Property metadata is stored ON-CHAIN** in the smart contract:

```solidity
struct PropertyMetadata {
    string location;
    uint256 valuation;
    uint256 area;
    string legalDescription;
    string ownerName;
    string coordinates;
}
```

**Pros:**
- ✅ Completely decentralized
- ✅ Guaranteed availability
- ✅ No external dependencies

**Cons:**
- ❌ Expensive for large data
- ❌ Cannot store images/PDFs
- ❌ Limited to text-only metadata

### Why Add IPFS?

IPFS (InterPlanetary File System) allows you to store:
- 📄 Legal documents (title deeds, ownership papers)
- 📸 Property images and videos
- 📊 Inspection reports
- 📋 Detailed property information

**Only the IPFS hash (CID) is stored on-chain**, making it gas-efficient.

### How to Add IPFS Integration

#### Step 1: Modify Smart Contract

Add IPFS hash to PropertyMetadata:

```solidity
struct PropertyMetadata {
    string location;
    uint256 valuation;
    uint256 area;
    string legalDescription;
    string ownerName;
    string coordinates;
    string ipfsHash;  // NEW: IPFS CID for documents
}
```

#### Step 2: Choose IPFS Provider

**Option A: ThirdWeb Storage (Recommended)**

ThirdWeb provides built-in IPFS storage:

```bash
cd frontend
npm install @thirdweb-dev/storage
```

**Option B: Pinata**

```bash
npm install @pinata/sdk
```

**Option C: web3.storage**

```bash
npm install web3.storage
```

#### Step 3: Update Frontend - File Upload Component

Create `/frontend/src/components/IPFSUpload.tsx`:

```typescript
'use client';

import { useState } from 'react';
import { ThirdwebStorage } from '@thirdweb-dev/storage';
import { Upload, FileText, Image, X } from 'lucide-react';
import { Button } from './ui/button';
import { toast } from 'sonner';

interface UploadedFile {
  name: string;
  type: string;
  ipfsUrl: string;
  ipfsHash: string;
}

export function IPFSUpload({ onUploadComplete }: {
  onUploadComplete: (files: UploadedFile[]) => void
}) {
  const [uploading, setUploading] = useState(false);
  const [uploadedFiles, setUploadedFiles] = useState<UploadedFile[]>([]);

  // Initialize ThirdWeb Storage
  const storage = new ThirdwebStorage({
    clientId: process.env.NEXT_PUBLIC_THIRDWEB_CLIENT_ID!,
  });

  async function handleFileUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setUploading(true);
    toast.info('Uploading to IPFS...');

    try {
      const uploaded: UploadedFile[] = [];

      for (const file of Array.from(files)) {
        // Upload to IPFS via ThirdWeb
        const ipfsUrl = await storage.upload(file);
        const ipfsHash = ipfsUrl.replace('ipfs://', '');

        uploaded.push({
          name: file.name,
          type: file.type,
          ipfsUrl,
          ipfsHash,
        });
      }

      setUploadedFiles([...uploadedFiles, ...uploaded]);
      onUploadComplete(uploaded);

      toast.success(`Uploaded ${uploaded.length} file(s) to IPFS`);
    } catch (error: any) {
      console.error('IPFS upload error:', error);
      toast.error('Failed to upload to IPFS');
    } finally {
      setUploading(false);
    }
  }

  function removeFile(index: number) {
    const newFiles = uploadedFiles.filter((_, i) => i !== index);
    setUploadedFiles(newFiles);
    onUploadComplete(newFiles);
  }

  return (
    <div className="space-y-4">
      <div className="border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg p-6">
        <input
          type="file"
          id="ipfs-upload"
          multiple
          accept="image/*,.pdf,.doc,.docx"
          onChange={handleFileUpload}
          disabled={uploading}
          className="hidden"
        />
        <label
          htmlFor="ipfs-upload"
          className="flex flex-col items-center cursor-pointer"
        >
          <Upload className="h-12 w-12 text-gray-400 mb-2" />
          <p className="text-sm font-medium text-gray-700 dark:text-gray-300">
            {uploading ? 'Uploading to IPFS...' : 'Click to upload documents'}
          </p>
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
            Images, PDFs, Word documents
          </p>
        </label>
      </div>

      {/* Uploaded Files List */}
      {uploadedFiles.length > 0 && (
        <div className="space-y-2">
          <p className="text-sm font-medium">Uploaded Files:</p>
          {uploadedFiles.map((file, index) => (
            <div
              key={index}
              className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg p-3"
            >
              <div className="flex items-center gap-2">
                {file.type.startsWith('image/') ? (
                  <Image className="h-4 w-4 text-blue-600" />
                ) : (
                  <FileText className="h-4 w-4 text-gray-600" />
                )}
                <div>
                  <p className="text-sm font-medium">{file.name}</p>
                  <p className="text-xs text-gray-500">
                    IPFS: {file.ipfsHash.slice(0, 10)}...{file.ipfsHash.slice(-8)}
                  </p>
                </div>
              </div>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => removeFile(index)}
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
```

#### Step 4: Update Register Page

Modify `/frontend/src/app/register/page.tsx`:

```typescript
import { IPFSUpload } from '@/components/IPFSUpload';

// In RegisterPage component:
const [ipfsFiles, setIpfsFiles] = useState<any[]>([]);

// In the form:
<div className="space-y-2">
  <label className="text-sm font-medium">Property Documents</label>
  <IPFSUpload
    onUploadComplete={(files) => setIpfsFiles(files)}
  />
</div>

// When registering, combine IPFS hashes:
const ipfsHash = ipfsFiles.map(f => f.ipfsHash).join(',');

const metadata = {
  location: formData.location,
  valuation: BigInt(Math.floor(parseFloat(formData.valuation) * 1e6)),
  area: BigInt(formData.area),
  legalDescription: formData.legalDescription,
  ownerName: formData.ownerName,
  coordinates: formData.coordinates,
  ipfsHash: ipfsHash,  // Add IPFS hashes
};
```

#### Step 5: Display IPFS Content

Create a component to view IPFS files:

```typescript
export function IPFSViewer({ ipfsHash }: { ipfsHash: string }) {
  const ipfsUrl = `https://ipfs.io/ipfs/${ipfsHash}`;
  // Or use ThirdWeb gateway: `https://gateway.ipfscdn.io/ipfs/${ipfsHash}`

  return (
    <a
      href={ipfsUrl}
      target="_blank"
      rel="noopener noreferrer"
      className="text-blue-600 hover:underline"
    >
      View on IPFS
    </a>
  );
}
```

### IPFS Gateways

Use these public gateways to access IPFS content:

- `https://ipfs.io/ipfs/{CID}`
- `https://gateway.ipfscdn.io/ipfs/{CID}` (ThirdWeb)
- `https://cloudflare-ipfs.com/ipfs/{CID}`
- `https://gateway.pinata.cloud/ipfs/{CID}`

### Complete Example: Property with IPFS

```typescript
// Upload flow:
1. User selects property images and documents
2. Frontend uploads to IPFS → gets CID: "QmX5f7..."
3. Store CID in smart contract metadata
4. Property is registered with IPFS reference

// Retrieval flow:
1. Read property from contract → get IPFS hash
2. Construct gateway URL: https://ipfs.io/ipfs/QmX5f7...
3. Display images/documents to users
```

### Cost Comparison

| Storage Method | Gas Cost | Capacity | Availability |
|----------------|----------|----------|--------------|
| On-chain only | High (~100k gas per property) | Limited (text only) | Permanent |
| On-chain + IPFS | Low (~20k gas for hash) | Unlimited (any file type) | Permanent (if pinned) |

---

## 🎯 Recommended Setup

### For Development
1. ✅ Keep text metadata on-chain (location, valuation, etc.)
2. ✅ Use IPFS for documents and images
3. ✅ Use ThirdWeb Storage (easiest integration)

### For Production
1. ✅ Pin IPFS files to multiple providers (Pinata + web3.storage)
2. ✅ Store critical data on-chain
3. ✅ Use CDN-backed IPFS gateways for fast loading
4. ✅ Implement backup retrieval methods

---

## 📋 Summary

### Verifier System
- ✅ **NOW IMPLEMENTED** - Frontend checks `isVerifier(address)`
- ✅ Verifier badge shown in governance page
- ✅ Only verifiers can approve/reject/slash properties
- ✅ Contract owner can add/remove verifiers

### IPFS Integration
- ❌ **NOT CURRENTLY IMPLEMENTED**
- ✅ Ready to add using ThirdWeb Storage
- ✅ Would enable document/image uploads
- ✅ More cost-effective for large data

**Next Steps:**
1. Deploy contracts and add verifier addresses
2. (Optional) Implement IPFS for richer property data
3. Test with real property registrations

---

**Last Updated:** 2025-11-22
