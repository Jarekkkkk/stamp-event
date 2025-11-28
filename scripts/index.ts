import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { decodeSuiPrivateKey } from "@mysten/sui/cryptography";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { normalizeSuiAddress } from "@mysten/sui/utils";
import dotenv from "dotenv";
dotenv.config();

import fs from "fs";
import fsPromise from "fs/promises";
import path from "path";
import process from "process";

const secret = process.env.SUI_ADMIN_PRIVATE_KEY!;
console.log({ secret });
const { secretKey } = decodeSuiPrivateKey(secret);
const signer = Ed25519Keypair.fromSecretKey(secretKey);

const suiClient = new SuiClient({ url: getFullnodeUrl("mainnet") });

/* --------------------------
   Load address CSV (Node)
----------------------------- */
async function loadAddressList(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }

  const text = await fsPromise.readFile(filePath, "utf8");
  const lines = text.split("\n").filter((l) => l.trim().length > 0);

  if (lines.length === 0) return [];

  const addresses = lines[0].startsWith("0x") ? lines : lines.slice(1);

  return addresses.map((l) => l.trim().replace(/['"]/g, ""));
}

/* --------------------------
   Create batches
----------------------------- */
function createBatches(array, size) {
  const out = [];
  for (let i = 0; i < array.length; i += size) {
    out.push(array.slice(i, i + size));
  }
  return out;
}

/* --------------------------
   Write CSV records
----------------------------- */
function writeSuccessRecord(batchIndex, addresses, txDigest, timestamp) {
  const csvPath = path.join(process.cwd(), "successful_airdrops.csv");

  if (!fs.existsSync(csvPath)) {
    fs.writeFileSync(csvPath, "batch_index,address,tx_digest,timestamp\n");
  }

  const rows =
    addresses
      .map((addr) => `${batchIndex},${addr},${txDigest},${timestamp}`)
      .join("\n") + "\n";

  fs.writeFileSync(csvPath, rows, { flag: "a" });
}

/* --------------------------
   Process a batch
----------------------------- */
async function processBatch(addresses, batchIndex, totalBatches) {
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

    console.log("Executing dry run...");
    // const result = await suiClient.dryRunTransactionBlock({
    //   transactionBlock: await tx.build({ client: suiClient }),
    // });
    const result = await suiClient.signAndExecuteTransaction({
      transaction: tx,
      signer,
      options: {
        showEffects: true,
      },
    });

    if (result.effects?.status?.status === "success") {
      const ts = new Date().toISOString();
      console.log(
        `SUCCESS batch ${batchIndex}: ${addresses[0]} ? ${
          addresses[addresses.length - 1]
        }`,
      );

      // dryRun has no digest; create a predictable placeholder
      const digest = result?.digest ?? `dryrun-${batchIndex}-${Date.now()}`;

      console.log({ index: batchIndex + 1, addresses, digest, ts });
      writeSuccessRecord(batchIndex + 1, addresses, digest, ts);

      return true;
    }

    console.error("Failed", result.effects?.status);
    return false;
  } catch (err) {
    console.error("Error:", err);
    return false;
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  console.log(`Admin address: ${signer.toSuiAddress()}`);

  const addresses = await loadAddressList("discord_vip_pass.csv");

  if (!addresses.length) {
    console.error("No addresses found.");
    return;
  }

  console.log(`Loaded ${addresses.length} addresses`);

  const BATCH_SIZE = 500;
  const batches = createBatches(addresses, BATCH_SIZE);

  console.log(`Created ${batches.length} batches`);

  let ok = 0;
  let fail = 0;

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];

    // actual batch call (commented originally)
    const okBatch = await processBatch(batch, i, batches.length);
    okBatch ? ok++ : fail++;

    if (i < batches.length - 1) await sleep(2000);
  }

  console.log("\n=== SUMMARY ===");
  console.log("Batches:", batches.length);
  console.log("Success:", ok);
  console.log("Fail:", fail);
}

main().catch(console.error);
