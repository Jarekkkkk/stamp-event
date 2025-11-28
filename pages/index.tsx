import {
  ConnectButton,
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { useEffect, useState } from "react";
import Papa from "papaparse";
import { Toaster } from "react-hot-toast";
import toast from "react-hot-toast";
import { normalizeStructTag, normalizeSuiAddress } from "@mysten/sui/utils";

const PACKAGE =
  "0x71ace10bed80a93f30bc296c1622a10c2956f87f93393c200e401ef735ad8cb4";
const CONFIG =
  "0x5e5705f3497757d8e120e51143e81dab8e58d24ff1ba9bcf1e4af6c4b756fb9f";
const ADMIN_CAP =
  "0x535681c0cd88aea86ef321958c3dff33ea3aa3e5400ddd9f44fb57f214ed0f66";
const PUBLISHER =
  "0xfca2f7ec19fa71acad6ea7fbc5301da7bcb614a58bc37d40d2f3f6cbe5cd8c98";
const EVENTS_DF_KEY =
  "0x48f704fd831a20e26d03fdac777acadbeb2e29c405a6a66012294dcf6b2f4127";

export const showSuccess = (msg: string) => toast.success(msg);
export const showError = (msg: string) => toast.error(msg);

export default function Home() {
  const suiClient = useSuiClient();
  const currentAccount = useCurrentAccount();
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();
  const [loading, setLoading] = useState(false);

  // Inputs for different commands
  const [eventDescription, setEventDescription] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const [managerAddress, setManagerAddress] = useState("");
  const [recipientAddress, setRecipientAddress] = useState("");
  const [csvFile, setCsvFile] = useState<File | null>(null);
  const [batchSize, setBatchSize] = useState(500);
  const [newCollectionType, setNewCollectionType] = useState(""); // for creating new collection
  const [selectedCollectionType, setSelectedCollectionType] = useState(""); // for mint/batch
  const [newEventName, setNewEventName] = useState(""); // for New Event input
  const [selectedEventName, setSelectedEventName] = useState(""); // for Mint/Bach dropdown menu

  const handleTx = async (txBuilder: Transaction) => {
    if (!currentAccount) return;
    setLoading(true);

    try {
      txBuilder.setSender(currentAccount.address);

      // const res = await suiClient.dryRunTransactionBlock({
      //   transactionBlock: await txBuilder.build({ client: suiClient }),
      // });

      signAndExecute(
        { transaction: txBuilder },
        {
          onSuccess: (result) => {
            console.log("Transaction successful:", result);
            showSuccess("Transaction executed successfully!");
          },
          onError: (error) => {
            console.error("Transaction failed:", error);
            showError("Transaction failed: " + error.message);
          },
        },
      );
    } catch (error) {
      console.error("Transaction error:", error);
      showError(
        error instanceof Error ? error.message : "Something went wrong",
      );
    } finally {
      setLoading(false);
    }
  };

  // Individual command handlers
  const newCollection = () => {
    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE}::stamp::new_collection`,
      typeArguments: [newCollectionType],
      arguments: [tx.object(CONFIG), tx.object(PUBLISHER)],
    });
    handleTx(tx);
  };

  const newEvent = () => {
    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE}::stamp::new_event`,
      arguments: [
        tx.object(CONFIG),
        tx.object(ADMIN_CAP),
        tx.pure.string(newEventName),
        tx.pure.string(eventDescription),
        tx.pure.string(imageUrl),
      ],
    });
    handleTx(tx);
  };

  const addManager = () => {
    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE}::stamp::add_manager`,
      arguments: [
        tx.object(CONFIG),
        tx.object(ADMIN_CAP),
        tx.pure.address(managerAddress),
      ],
    });
    handleTx(tx);
  };

  const removeManager = () => {
    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE}::stamp::remove_manager`,
      arguments: [
        tx.object(CONFIG),
        tx.object(ADMIN_CAP),
        tx.pure.address(managerAddress),
      ],
    });
    handleTx(tx);
  };

  const mintTo = () => {
    const tx = new Transaction();
    console.log({ selectedCollectionType });
    tx.moveCall({
      target: `${PACKAGE}::stamp::mint_to`,
      typeArguments: [selectedCollectionType],
      arguments: [
        tx.object(CONFIG),
        tx.pure.string(selectedEventName),
        tx.pure.address(recipientAddress),
      ],
    });
    handleTx(tx);
  };

  // Batch Mint
  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setCsvFile(e.target.files[0]);
    }
  };

  const createBatches = (array: string[], size: number) => {
    const out = [];
    for (let i = 0; i < array.length; i += size) {
      out.push(array.slice(i, i + size));
    }
    return out;
  };

  const batchMint = async () => {
    if (!csvFile || !currentAccount) return;
    setLoading(true);

    Papa.parse(csvFile, {
      complete: async (results) => {
        try {
          const addresses: string[] = results.data
            .flat()
            .map((a: any) => normalizeSuiAddress(a))
            .filter((a) => a.startsWith("0x"));

          const batches = createBatches(addresses, batchSize);

          for (let i = 0; i < batches.length; i++) {
            const batch = batches[i];
            const tx = new Transaction();
            const config = tx.object(CONFIG);
            const event = tx.pure.string(selectedEventName);

            tx.moveCall({
              target: `${PACKAGE}::stamp::batch_mint`,
              typeArguments: [selectedCollectionType],
              arguments: [config, event, tx.pure.vector("address", batch)],
            });

            tx.setSender(currentAccount.address);

            // Show a prompt before signing each batch
            const confirm = window.confirm(
              `Batch ${i + 1} of ${batches.length}: Click OK to sign this batch in your wallet`,
            );

            if (!confirm) {
              showError("Batch mint canceled by user");
              break; // stop batch mint if user cancels
            }

            try {
              await new Promise<void>(async (resolve, reject) => {
                tx.setGasBudget(4 * 10 ** 9);
                tx.setGasPrice(0.001 * 10 ** 9);
                // const res = await suiClient.dryRunTransactionBlock({
                //   transactionBlock: await tx.build({ client: suiClient }),
                // });
                // console.log({ res });
                signAndExecute(
                  { transaction: tx },
                  {
                    onSuccess: () => {
                      showSuccess(`Batch ${i + 1} executed successfully`);
                      resolve();
                    },
                    onError: (err) => {
                      showError(`Batch ${i + 1} failed: ${err.message}`);
                      reject(err);
                    },
                  },
                );
              });
            } catch (err) {
              console.error("Batch error:", err);
              break; // stop loop on first failure
            }
          }

          showSuccess("Batch minting process finished");
        } catch (error) {
          showError(
            error instanceof Error ? error.message : "Something went wrong",
          );
        } finally {
          setLoading(false);
        }
      },
    });
  };

  const [collections, setCollections] = useState<
    { name: string; id: string }[]
  >([]);
  const [events, setEvents] = useState<{ name: string; id: string }[]>([]);

  useEffect(() => {
    const fetchEventsAndCollections = async () => {
      try {
        // fetch collections
        const collectionsResponse = await suiClient.getObject({
          id: CONFIG,
          options: { showContent: true },
        });

        const registeredCollections =
          (collectionsResponse?.data?.content as any)?.fields
            ?.registered_collections?.fields?.contents || [];

        const collectionsList = registeredCollections.map((entry: any) => ({
          name: entry.fields.key.fields.name,
          id: entry.fields.value,
        }));

        setCollections(collectionsList);

        // fetch events
        const eventsResponse = await suiClient.getDynamicFields({
          parentId: EVENTS_DF_KEY,
        });

        const eventsList = eventsResponse.data.map((entry: any) => ({
          name: entry.name.value,
          id: entry.objectId,
        }));

        setEvents(eventsList);

        // set default eventName if empty
        if (!selectedEventName && eventsList.length > 0) {
          setSelectedEventName(eventsList[0].name);
        }

        console.log({ collectionsList });
        if (collectionsList?.[0]) {
          setSelectedCollectionType(
            normalizeStructTag(collectionsList[0].name),
          );
        }
      } catch (err) {
        console.error("Failed to fetch events or collections:", err);
        showError("Failed to fetch events or collections");
      }
    };

    fetchEventsAndCollections();
  }, [suiClient]);

  console.log({ selectedCollectionType });

  return (
    <div style={{ padding: "2rem", fontFamily: "Arial, sans-serif" }}>
      <Toaster position="top-right" reverseOrder={false} />
      <h1>Sui dApp - Admin Actions</h1>
      <ConnectButton />
      {currentAccount && (
        <div style={{ marginTop: "2rem" }}>
          <h2>Connected Account: {currentAccount.address}</h2>

          {/* New Collection */}
          <div style={{ marginTop: "1rem" }}>
            <input
              placeholder="Collection Type"
              value={newCollectionType}
              onChange={(e) => setNewCollectionType(e.target.value)}
            />
            <button
              onClick={() => {
                if (!newCollectionType) return;
                const tx = new Transaction();
                tx.moveCall({
                  target: `${PACKAGE}::stamp::new_collection`,
                  typeArguments: [newCollectionType],
                  arguments: [tx.object(CONFIG), tx.object(PUBLISHER)],
                });
                handleTx(tx);
              }}
              disabled={loading}
            >
              {loading ? "Processing..." : "New Collection"}
            </button>
          </div>

          {/* New Event */}
          <div style={{ marginTop: "1rem" }}>
            <input
              placeholder="Event Name"
              value={newEventName}
              onChange={(e) => setNewEventName(e.target.value)}
            />
            <input
              placeholder="Event Description"
              value={eventDescription}
              onChange={(e) => setEventDescription(e.target.value)}
            />
            <input
              placeholder="Image URL"
              value={imageUrl}
              onChange={(e) => setImageUrl(e.target.value)}
            />
            <button
              onClick={() => {
                if (!newEventName) return;
                const tx = new Transaction();
                tx.moveCall({
                  target: `${PACKAGE}::stamp::new_event`,
                  arguments: [
                    tx.object(CONFIG),
                    tx.object(ADMIN_CAP),
                    tx.pure.string(newEventName),
                    tx.pure.string(eventDescription),
                    tx.pure.string(imageUrl),
                  ],
                });
                handleTx(tx);
              }}
              disabled={loading}
            >
              {loading ? "Processing..." : "New Event"}
            </button>
          </div>

          {/* Add / Remove Manager */}
          <div style={{ marginTop: "1rem" }}>
            <input
              placeholder="Manager Address"
              value={managerAddress}
              onChange={(e) => setManagerAddress(e.target.value)}
            />
            <button onClick={addManager} disabled={loading}>
              {loading ? "Processing..." : "Add Manager"}
            </button>
            <button onClick={removeManager} disabled={loading}>
              {loading ? "Processing..." : "Remove Manager"}
            </button>
          </div>

          {/* Mint To */}
          <div style={{ marginTop: "1rem" }}>
            <label>
              Collection Type:
              <select
                value={selectedCollectionType}
                onChange={(e) => setSelectedCollectionType(e.target.value)}
                style={{ marginLeft: "10px" }}
              >
                {collections.map((c) => (
                  <option key={c.id} value={c.name}>
                    {c.name.split("::").pop()}
                  </option>
                ))}
              </select>
            </label>

            <label style={{ marginLeft: "10px" }}>
              Event Name:
              <select
                value={selectedEventName}
                onChange={(e) => setSelectedEventName(e.target.value)}
                style={{ marginLeft: "10px" }}
              >
                {events.map((e) => (
                  <option key={e.id} value={e.name}>
                    {e.name}
                  </option>
                ))}
              </select>
            </label>

            <input
              placeholder="Recipient Address"
              value={recipientAddress}
              onChange={(e) => setRecipientAddress(e.target.value)}
              style={{ marginLeft: "10px" }}
            />

            <button
              onClick={mintTo}
              disabled={loading}
              style={{ marginLeft: "10px" }}
            >
              {loading ? "Processing..." : "Mint To"}
            </button>
          </div>

          {/* Batch Mint */}
          <div style={{ marginTop: "2rem" }}>
            <label>
              Collection Type:
              <select
                value={selectedCollectionType}
                onChange={(e) => setSelectedCollectionType(e.target.value)}
                style={{ marginLeft: "10px" }}
              >
                {collections.map((c) => (
                  <option key={c.id} value={c.name}>
                    {c.name.split("::").pop()}
                  </option>
                ))}
              </select>
            </label>

            <label style={{ marginLeft: "10px" }}>
              Event Name:
              <select
                value={selectedEventName}
                onChange={(e) => setSelectedEventName(e.target.value)}
                style={{ marginLeft: "10px" }}
              >
                {events.map((e) => (
                  <option key={e.id} value={e.name}>
                    {e.name}
                  </option>
                ))}
              </select>
            </label>

            <input
              type="file"
              accept=".csv"
              onChange={handleFileUpload}
              style={{ marginLeft: "10px" }}
            />

            <input
              type="number"
              value={batchSize}
              onChange={(e) => setBatchSize(Number(e.target.value))}
              style={{ width: "80px", marginLeft: "10px" }}
            />

            <button
              onClick={batchMint}
              disabled={loading || !csvFile}
              style={{ marginLeft: "10px" }}
            >
              {loading ? "Processing..." : "Batch Mint"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
