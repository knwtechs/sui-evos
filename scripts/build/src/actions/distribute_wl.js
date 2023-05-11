"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const utils_1 = require("../utils");
const calls_1 = require("../calls");
let signer = (0, utils_1.get_signer)((0, utils_1.load_account)());
const WALLETS_LIST = "/Users/filipposofi/Documents/Development/blockchain/sui/KunnowTechnologies/ev0s/scripts/awhitelist/list.txt";
const ACCOUNTS = (0, utils_1.load_addresses_from_list)(WALLETS_LIST);
const DELAY = 1000;
const do_all = async (accounts) => {
    for (let i = 0; i < accounts.length; i++) {
        let account = accounts[i];
        try {
            let status = await (0, calls_1.wl_user)(signer, account);
            console.log(`\n\t [${i + 1}/${accounts.length}] WL registered for ${account}: ${status}`);
            await new Promise(f => setTimeout(f, DELAY));
        }
        catch (e) { }
    }
};
console.log(`\n\t+ There are ${ACCOUNTS.length} WL to register...\n`);
do_all(ACCOUNTS)
    .then(() => console.log("\n\t+ WL distributed."));
