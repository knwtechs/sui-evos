import { RawSigner, TransactionBlock, getExecutionStatusType } from "@mysten/sui.js";
import { ROYALTIES_PACKAGE_ID, COLLECTION_ID, GENESIS_MODULE_NAME, GENESIS_PACKAGE_ID } from "../../ids";
import { get_signer, load_account } from "../../utils";

export async function distribute_royalties(signer: RawSigner) {
    const tx = new TransactionBlock();

    tx.moveCall({
      target: `${ROYALTIES_PACKAGE_ID}::royalty::distribute_royalties`,
      arguments: [
        tx.pure(COLLECTION_ID),
      ],
      typeArguments: [GENESIS_PACKAGE_ID + "::" + GENESIS_MODULE_NAME + "::EvosGenesisEgg", "0x2::sui::SUI"]
    });
  
    const txn = await signer.signAndExecuteTransactionBlock({
      transactionBlock: tx,
      options: {
        showEffects: true,
        showObjectChanges: true,
      },
    });
    return getExecutionStatusType(txn);
}

let signer = get_signer(load_account());

distribute_royalties(signer)
    .then(console.log);