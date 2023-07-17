"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const ids_1 = require("../../ids");
const utils_1 = require("../../../genesis/utils");
const get_evos_amount = async (signer) => {
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
        id: ids_1.INCUBATOR_ID,
        options: {
            showContent: true
        }
    })).data?.content;
};
const signer = (0, utils_1.get_signer)((0, utils_1.load_account)(3));
get_evos_amount(signer)
    .then(console.log);
