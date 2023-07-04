import { RawSigner, TransactionBlock } from "@mysten/sui.js";
import { EVOS_PACKAGE_ID, INCUBATOR_ID } from "../../ids";
import { get_signer, load_account } from "../../../genesis/utils";


const get_evos_amount = async (signer: RawSigner) => {
    // const tx = new TransactionBlock();
    
    // tx.moveCall({
    //     target: `${EVOS_PACKAGE_ID}::evos::index`,
    //     arguments: [
    //         tx.object(INCUBATOR_ID),
    //     ],
    // });

    // return await signer.devInspectTransactionBlock({
    //     transactionBlock: tx
    // });
    return (await signer.provider.getObject({
        id: INCUBATOR_ID,
        options: {
            showContent: true
        }
    })).data?.content;
}

const signer = get_signer(load_account(3))

get_evos_amount(signer)
    .then(console.log)