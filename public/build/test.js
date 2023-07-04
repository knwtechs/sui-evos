"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const utils_1 = require("./utils");
const sui_js_1 = require("@mysten/sui.js");
const config_1 = require("./config");
const CHUNK_SIZE = 200;
// Here you can pass an index to load_account to specify which account you want to load
// Ex: load_account(3) it will load the 4th account.
// You can obtain all your account by running `sui client addresses`
const signer = (0, utils_1.get_signer)((0, utils_1.load_account)());
const provider = signer.provider;
const recipients_ = (0, utils_1.load_airdrop_list)(config_1.WALLETS_LIST_TEST);
const get_objects_by_type = (provider, account, type, pages = 0) => __awaiter(void 0, void 0, void 0, function* () {
    let result = [];
    let eggs = yield provider.getOwnedObjects({ owner: account });
    let has_next_page = eggs.hasNextPage;
    let current = 1;
    while (has_next_page) {
        if (pages > 0 && current >= pages)
            break;
        eggs = yield provider.getOwnedObjects({ owner: account, cursor: eggs.nextCursor });
        result.push(...eggs.data.filter((obj) => { var _a; return ((_a = obj.data) === null || _a === void 0 ? void 0 : _a.type) == type; }));
        has_next_page = eggs.hasNextPage;
    }
    return result;
});
const select_nfts = (nfts, amount) => {
    let r = [];
    for (let i = 0; i < amount; i++) {
        r = nfts.pop();
    }
    return [r, nfts];
};
const airdrop_test = (recipients, provider, signer) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    const chunks = (0, utils_1.split_array)(recipients, CHUNK_SIZE);
    // Retrieve all the objects owned by the treasury
    let nfts = yield get_objects_by_type(provider, yield signer.getAddress(), config_1.COLLECTION_TYPE_TEST);
    let nft_id = nfts.filter(e => e.data).map(e => { var _a; return (_a = e.data) === null || _a === void 0 ? void 0 : _a.objectId; });
    let aidrop_amount = recipients.map(e => e.amount).reduce((acc, curr) => acc + curr, 0);
    if (aidrop_amount > nft_id.length) {
        console.log(`[AIRDROP] Not enough NFTs in treasury wallet! [${nft_id.length}/${aidrop_amount}]`);
        return;
    }
    for (let i = 0; i <= chunks.length; i += 1) {
        const chunk = chunks[i];
        let tx = new sui_js_1.TransactionBlock();
        let local = 0;
        for (let recipient of chunk) {
            const [objs, updated] = select_nfts(nfts, recipient.amount);
            nfts = updated;
            local += objs.reduce((acc, curr) => acc += curr.amount, 0);
            tx.transferObjects(objs.map(o => tx.pure(o)), tx.pure(recipient.address));
        }
        let txid = yield signer.signAndExecuteTransactionBlock({ transactionBlock: tx });
        console.log(`[${i + 1}/${chunks.length}] ${txid.digest} | ${local} | ${(_a = txid.effects) === null || _a === void 0 ? void 0 : _a.status.status}`);
        yield new Promise(f => setTimeout(f, config_1.DELAY));
    }
});
airdrop_test(recipients_, provider, signer)
    .then(() => console.log("\n\t+ Airdrop done."));
