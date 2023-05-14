"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const utils_1 = require("../utils");
const calls_1 = require("../calls");
let signer = (0, utils_1.get_signer)((0, utils_1.load_account)());
const WALLETS_LIST = "/Users/filipposofi/Documents/Development/blockchain/sui/KunnowTechnologies/ev0s/scripts/aairdrop/list.txt";
const RECIPIENTS = (0, utils_1.load_airdrop_list)(WALLETS_LIST);
const DELAY = 250;
const do_all = async (recipients) => {
    for (let i = 0; i < recipients.length; i++) {
        let recipient = recipients[i];
        let t = Date.now();
        try {
            let status = await (0, calls_1.presale_mint)(signer, recipient.address, recipient.amount);
            console.log(`\t+ [${((Date.now() - t) / 1000).toFixed(2)}s][${i + 1}/${recipients.length}] Airdrop to ${recipient.address} ${recipient.amount} nfts: ${status}`);
            await new Promise(f => setTimeout(f, DELAY));
        }
        catch (e) { }
    }
};
do_all(RECIPIENTS)
    .then(() => console.log("\n\t+ Airdrop done."));
