"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const utils_1 = require("../utils");
const sui_js_1 = require("@mysten/sui.js");
const signer = (0, utils_1.get_signer)((0, utils_1.load_account)());
const provider = signer.provider;
const WALLETS_LIST = "/absolute/path/to/list.txt";
const RECIPIENTS = (0, utils_1.load_airdrop_list)(WALLETS_LIST);
const DELAY = 750;
const COLLECTION_TYPE = "";
function splitArray(array, n) {
    const chunkSize = Math.ceil(array.length / n);
    const result = [];
    for (let i = 0; i < array.length; i += chunkSize) {
        result.push(array.slice(i, i + chunkSize));
    }
    return result;
}
const get_objects_by_type = async (provider, account, type, pages = 0) => {
    let result = [];
    let eggs = await provider.getOwnedObjects({ owner: account });
    let has_next_page = eggs.hasNextPage;
    let current = 1;
    while (has_next_page) {
        if (pages > 0 && current >= pages)
            break;
        eggs = await provider.getOwnedObjects({ owner: account, cursor: eggs.nextCursor });
        result.push(...eggs.data.filter((obj) => obj.data?.type == type));
        has_next_page = eggs.hasNextPage;
    }
    return result;
};
const select_nfts = (nfts, amount) => {
    let r = [];
    for (let i = 0; i < amount; i++) {
        r = nfts.pop();
    }
    return [r, nfts];
};
const do_all_native = async (recipients, provider, signer) => {
    const CHUNK_SIZE = 50;
    const chunks = splitArray(recipients, CHUNK_SIZE);
    // Retrieve all the objects owned by the treasury
    let nfts = await get_objects_by_type(provider, await signer.getAddress(), COLLECTION_TYPE);
    let nft_id = nfts.filter(e => e.data).map(e => e.data?.objectId);
    let aidrop_amount = recipients.map(e => e.amount).reduce((acc, curr) => acc + curr, 0);
    if (aidrop_amount > nft_id.length) {
        // NOT ENOUGH NFTS IN TREASURY TO PERFORM THIS AIRDROP
        return;
    }
    for (let i = 0; i <= chunks.length; i += 1) {
        const chunk = chunks[i];
        let tx = new sui_js_1.TransactionBlock();
        let local = 0;
        for (let recipient of chunk) {
            const [objs, updated] = select_nfts(nfts, recipient.amount);
            local += objs.reduce((acc, curr) => acc += curr.amount, 0);
            nfts = updated;
            tx.transferObjects(objs.map(o => tx.pure(o)), tx.pure(recipient.address));
        }
        let txid = await signer.signAndExecuteTransactionBlock({ transactionBlock: tx });
        console.log(`[${i + 1}/${chunks.length}] ${txid.digest} | ${local} | ${txid.effects?.status.status}`);
        await new Promise(f => setTimeout(f, DELAY));
    }
};
do_all_native(RECIPIENTS, provider, signer)
    .then(() => console.log("\n\t+ Airdrop done."));
