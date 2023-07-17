"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sui_js_1 = require("@mysten/sui.js");
const ids_1 = require("../../ids");
const utils_1 = require("../../../genesis/utils");
const enable_orderbook = async (signer) => {
    const tx = new sui_js_1.TransactionBlock();
    tx.moveCall({
        target: `${ids_1.EVOS_PACKAGE_ID}::evos::enable_orderbook`,
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
};
const signer = (0, utils_1.get_signer)((0, utils_1.load_account)(3));
enable_orderbook(signer)
    .then(console.log);
