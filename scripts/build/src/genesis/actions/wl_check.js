"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const utils_1 = require("../utils");
const calls_1 = require("../calls");
const sui_js_1 = require("@mysten/sui.js");
let signer = (0, utils_1.get_signer)((0, utils_1.load_account)());
const WALLETS_LIST = "/Users/filipposofi/Documents/Development/blockchain/sui/KunnowTechnologies/ev0s/scripts/awhitelist/list.txt";
const RECIPIENTS = (0, utils_1.load_addresses_from_list)(WALLETS_LIST);
const do_all = async (recipients) => {
    let i = 0;
    while (i < recipients.length) {
        let recipient = recipients[i];
        try {
            let is_wl = await (0, calls_1.is_whitelisted)(new sui_js_1.TransactionBlock(), signer, recipient);
            console.log(`\t+ [${i + 1}] ${recipient}: ${is_wl ? String(is_wl).toLocaleLowerCase() : String(is_wl).toLocaleUpperCase()}`);
            await new Promise(f => setTimeout(f, 200));
        }
        catch (e) {
            console.log(`\t+ [${i + 1}] [INVALID_ADDRESS] ${recipient}`);
        }
        i++;
    }
};
console.log("[\n[WL-CHECK]\n");
do_all(RECIPIENTS)
    .then(() => console.log("\n\t+ Airdrop done."));
