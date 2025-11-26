import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { decodeSuiPrivateKey } from "@mysten/sui/cryptography";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { normalizeSuiAddress } from "@mysten/sui/utils";

import { join } from "path";
import { existsSync, writeFileSync } from "fs";

const secret = process.env.SUI_ADMIN_PRIVATE_KEY!;
const { secretKey } = decodeSuiPrivateKey(secret);
const signer = Ed25519Keypair.fromSecretKey(secretKey);

const suiClient = new SuiClient({ url: getFullnodeUrl("mainnet") });

// Load address CSV
async function loadAddressList(filePath: string): Promise<string[]> {
  const file = Bun.file(filePath);

  if (!(await file.exists())) {
    throw new Error(`File not found: ${filePath}`);
  }

  const text = await file.text();
  const lines = text.split("\n").filter((line) => line.trim().length > 0);

  if (lines.length === 0) return [];

  const addresses = lines[0].startsWith("0x") ? lines : lines.slice(1);

  return addresses.map((l) => l.trim().replace(/['"]/g, ""));
}

// Create batches
function createBatches<T>(array: T[], batchSize: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < array.length; i += batchSize) {
    out.push(array.slice(i, i + batchSize));
  }
  return out;
}

// Write success CSV
function writeSuccessRecord(
  batchIndex: number,
  addresses: string[],
  txDigest: string,
  timestamp: string,
) {
  const csvPath = join(process.cwd(), "successful_airdrops.csv");

  if (!existsSync(csvPath)) {
    writeFileSync(csvPath, "batch_index,address,tx_digest,timestamp\n");
  }

  const rows =
    addresses
      .map((addr) => `${batchIndex},${addr},${txDigest},${timestamp}`)
      .join("\n") + "\n";

  writeFileSync(csvPath, rows, { flag: "a" });
}

// Process a batch
async function processBatch(
  addresses: string[],
  batchIndex: number,
  totalBatches: number,
) {
  console.log(
    `\nProcessing batch ${batchIndex + 1}/${totalBatches} (${addresses.length} addresses)`,
  );

  try {
    const tx = new Transaction();

    const config = tx.sharedObjectRef({
      objectId:
        "0x5e5705f3497757d8e120e51143e81dab8e58d24ff1ba9bcf1e4af6c4b756fb9f",
      initialSharedVersion: "696183661",
      mutable: true,
    });

    const eventName = tx.pure.string("Sui Fundamentals Discord VIP Pass");

    for (const address of addresses) {
      tx.moveCall({
        package:
          "0xf469c36f014c1cd531ed119425e341beeaa569615c144e65a52cf2d0613d4fcb",
        module: "stamp",
        function: "mint_to",
        typeArguments: [
          "0xa66240bda1ccf0e28363a87c05a8972dc674516c06cdaa4cefcd5711f3d4cac1::collections::SuiFundamentalsDiscordVIPPass",
        ],
        arguments: [
          config,
          eventName,
          tx.pure.address(normalizeSuiAddress(address)),
        ],
      });
    }

    tx.setSender(signer.toSuiAddress());

    console.log("Executing transaction...");
    const result = await suiClient.dryRunTransactionBlock({
      transactionBlock: await tx.build({ client: suiClient }),
    });

    console.log({ result });

    if (result.effects?.status?.status === "success") {
      const ts = new Date().toISOString();
      console.log(
        `successful batch ${batchIndex} from ${addresses[0]} to ${addresses[addresses.length - 1]}`,
      );
      //
      // console.log(`Batch ${batchIndex + 1} successful: ${result.digest}`);
      //
      // writeSuccessRecord(batchIndex + 1, addresses, result.digest!, ts);
      return true;
    }

    console.error(`? Batch ${batchIndex + 1} failed`, result.effects?.status);
    return false;
  } catch (err) {
    console.error(`? Error in batch ${batchIndex + 1}`, err);
    return false;
  }
}

// Main
async function main() {
  console.log(`Using signer address: ${signer.toSuiAddress()}`);

  const addresses = await loadAddressList("discord_vip_pass.csv");

  if (!addresses || addresses.length === 0) {
    console.error("No addresses loaded.");
    return;
  }

  console.log(`Total addresses: ${addresses.length}`);

  const BATCH_SIZE = 500;
  const batches = createBatches(addresses, BATCH_SIZE);

  console.log(`Created ${batches.length} batches`);

  let ok = 0;
  let fail = 0;

  for (let i = 0; i < batches.length; i++) {
    const batch = batches?.[i];
    if (!batch) throw new Error(`Invalid Index: ${i} for batch`);

    const first = batch[0];

    const res = await suiClient.getOwnedObjects({
      owner: first!,
      filter: {
        MatchAll: [
          {
            StructType:
              "0xf469c36f014c1cd531ed119425e341beeaa569615c144e65a52cf2d0613d4fcb::stamp::Stamp<0xa66240bda1ccf0e28363a87c05a8972dc674516c06cdaa4cefcd5711f3d4cac1::collections::SuiFundamentalsDiscordVIPPass>",
          },
        ],
      },
      options: { showContent: true },
    });

    console.log({ res: res.data[0]?.data?.content.fields });

    // const status = await processBatch(batch, i, batches.length);
    // status ? ok++ : fail++;

    if (i < batches.length - 1) {
      await Bun.sleep(2000);
    }
  }

  console.log("\n=== SUMMARY ===");
  console.log("Batches:", batches.length);
  console.log("Success:", ok);
  console.log("Failed:", fail);
  console.log("Records saved ? successful_airdrops.csv");
}

main().catch(console.error);
