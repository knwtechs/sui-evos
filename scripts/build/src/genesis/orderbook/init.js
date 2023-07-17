"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sui_js_1 = require("@mysten/sui.js");
const ids_1 = require("../ids");
const utils_1 = require("../utils");
const init_orderbook = async () => {
    const tx = new sui_js_1.TransactionBlock();
    const signer = (0, utils_1.get_signer)((0, utils_1.load_account)());
    const token_type = `${ids_1.GENESIS_PACKAGE_ID}::evosgenesisegg::EvosGenesisEgg`;
    const witness = tx.moveCall({
        target: `0x16c5f17f2d55584a6e6daa442ccf83b4530d10546a8e7dedda9ba324e012fc40::witness::from_publisher`,
        typeArguments: [token_type],
        arguments: [tx.object(ids_1.PUBLISHER_ID)],
    });
    const orderbook = tx.moveCall({
        target: `0x4e0629fa51a62b0c1d7c7b9fc89237ec5b6f630d7798ad3f06d820afb93a995a::orderbook::create_unprotected`,
        typeArguments: [token_type, sui_js_1.SUI_TYPE_ARG],
        arguments: [witness, tx.object(ids_1.TRANSFER_POLICY)],
    });
    console.log("orderbook: ", orderbook);
    return await signer.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
            showEffects: true,
            showObjectChanges: true
        }
    });
};
init_orderbook()
    .then(console.log);
