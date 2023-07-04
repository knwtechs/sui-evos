import { RawSigner, TransactionBlock } from "@mysten/sui.js";
import { EVOS_PACKAGE_ID } from "../../ids";
import { get_signer, load_account } from "../../../genesis/utils";


const enable_orderbook = async (signer: RawSigner) => {
    const tx = new TransactionBlock();
    
    tx.moveCall({
        target: `${EVOS_PACKAGE_ID}::evos::enable_orderbook`,
        arguments: [
            tx.pure("0xa8177796bc4b06e084328e943541a393895ec47e988ed51e68278c665c61f6b4"),
            tx.object("0xa792f3aa9e7301429e72fa19b19fa307b9a12dc27882d300032300a3a2653c71"),
        ],
    });

    //console.log("orderbook: ", txid);

    return await signer.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
            showEffects: true,
            showObjectChanges: true
        }
    });
}

const signer = get_signer(load_account(3))

enable_orderbook(signer)
    .then(console.log)