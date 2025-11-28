import {
  ConnectButton,
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { Transaction } from "@mysten/sui/transactions";
import { useState } from "react";

export default function Home() {
  const currentAccount = useCurrentAccount();
  const suiClient = useSuiClient();
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();
  const [loading, setLoading] = useState(false);

  const handleTransaction = async () => {
    if (!currentAccount) return;

    setLoading(true);
    try {
      if (!currentAccount) return;
      const txb = new Transaction();

      const [coin] = txb.splitCoins(txb.gas, [10000]); // 0.001 SUI
      txb.transferObjects([coin], currentAccount.address);

      signAndExecute(
        {
          transaction: txb,
        },
        {
          onSuccess: (result) => {
            console.log("Transaction successful:", result);
            alert("Transaction successful!");
          },
          onError: (error) => {
            console.error("Transaction failed:", error);
            alert("Transaction failed!");
          },
        },
      );
    } catch (error) {
      console.error("Error creating transaction:", error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ padding: "2rem", fontFamily: "Arial, sans-serif" }}>
      <h1>Sui dApp with Next.js</h1>

      <div style={{ marginBottom: "2rem" }}>
        <ConnectButton />
      </div>

      {currentAccount && (
        <div>
          <h2>Connected Account</h2>
          <p>
            <strong>Address:</strong> {currentAccount.address}
          </p>

          <div style={{ marginTop: "2rem" }}>
            <button
              onClick={handleTransaction}
              disabled={loading}
              style={{
                padding: "10px 20px",
                backgroundColor: "#0070f3",
                color: "white",
                border: "none",
                borderRadius: "5px",
                cursor: loading ? "not-allowed" : "pointer",
                opacity: loading ? 0.6 : 1,
              }}
            >
              {loading ? "Processing..." : "Send Test Transaction"}
            </button>
          </div>
        </div>
      )}

      {!currentAccount && (
        <div>
          <p>Please connect your wallet to interact with the Sui blockchain.</p>
        </div>
      )}
    </div>
  );
}
