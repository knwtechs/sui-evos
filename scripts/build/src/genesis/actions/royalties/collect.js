"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.distribute_royalties = void 0;
const sui_js_1 = require("@mysten/sui.js");
const ids_1 = require("../../ids");
const utils_1 = require("../../utils");
async function distribute_royalties(signer) {
    const tx = new sui_js_1.TransactionBlock();
    tx.moveCall({
        target: `${ids_1.ROYALTIES_PACKAGE_ID}::royalty::distribute_royalties`,
        arguments: [
            tx.pure(ids_1.COLLECTION_ID),
        ],
        typeArguments: [ids_1.GENESIS_PACKAGE_ID + "::" + ids_1.GENESIS_MODULE_NAME + "::EvosGenesisEgg", "0x2::sui::SUI"]
    });
    const txn = await signer.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
            showEffects: true,
            showObjectChanges: true,
        },
    });
    return (0, sui_js_1.getExecutionStatusType)(txn);
}
exports.distribute_royalties = distribute_royalties;
let signer = (0, utils_1.get_signer)((0, utils_1.load_account)());
distribute_royalties(signer)
    .then(console.log);
