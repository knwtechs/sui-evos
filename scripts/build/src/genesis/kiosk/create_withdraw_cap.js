"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sui_js_1 = require("@mysten/sui.js");
const ids_1 = require("../ids");
const utils_1 = require("../utils");
const ob_request_package_id = "0xe2c7a6843cb13d9549a9d2dc1c266b572ead0b4b9f090e7c3c46de2714102b43";
const create_withdraw_policy_and_cap = async () => {
    const tx = new sui_js_1.TransactionBlock();
    const signer = (0, utils_1.get_signer)((0, utils_1.load_account)());
    const token_type = `${ids_1.GENESIS_PACKAGE_ID}::evosgenesisegg::EvosGenesisEgg`;
    const [policy, policyCap] = tx.moveCall({
        target: `${ob_request_package_id}::withdraw_request::init_policy`,
        typeArguments: [token_type],
        arguments: [tx.object(ids_1.PUBLISHER_ID)],
    });
    tx.transferObjects([policyCap], tx.pure(await signer.getAddress(), "address"));
    tx.moveCall({
        target: `0x2::transfer::public_share_object`,
        typeArguments: [`${ob_request_package_id}::request::Policy<${ob_request_package_id}::request::WithNft<${token_type}, ${ob_request_package_id}::withdraw_request::WITHDRAW_REQ>>`],
        arguments: [policy],
    });
    return await signer.signAndExecuteTransactionBlock({ transactionBlock: tx });
};
create_withdraw_policy_and_cap()
    .then(console.log);
