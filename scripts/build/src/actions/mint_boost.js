"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const utils_1 = require("../utils");
const calls_1 = require("../calls");
let signer = (0, utils_1.get_signer)((0, utils_1.load_account)());
const WALLETS_LIST = "/Users/filipposofi/Documents/Development/blockchain/sui/KunnowTechnologies/ev0s/scripts/aboost/list.txt";
const RECIPIENTS = (0, utils_1.load_addresses_from_list)(WALLETS_LIST);
const do_all = async (recipients) => {
    for (let i = 0; i < recipients.length; i++) {
        let recipient = recipients[i];
        let t = Date.now();
        let amount = Math.ceil(Number((Math.random() * (10 - 1) + 1)));
        try {
            let status = await (0, calls_1.presale_mint)(signer, recipient, amount);
            console.log(`\t+ [${((Date.now() - t) / 1000).toFixed(2)}s][${i + 1}/${recipients.length}] Airdrop to ${recipient} ${amount} nfts: ${status}`);
            await new Promise(f => setTimeout(f, (Math.random() * (2500 - 800) + 800)));
        }
        catch (e) {
            console.log(e);
        }
    }
};
do_all(RECIPIENTS)
    .then(() => console.log("\n\t+ Airdrop done."));
