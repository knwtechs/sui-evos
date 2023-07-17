"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sui_js_1 = require("@mysten/sui.js");
const utils_1 = require("../utils");
const calls_1 = require("../calls");
let account = (0, utils_1.load_account)();
let signer = (0, utils_1.get_signer)(account);
(0, calls_1.get_public_price)(new sui_js_1.TransactionBlock(), signer).then((pub) => {
    console.log(`\n\t+ Public = ${pub / (10 ** 9)} SUI`);
    (0, calls_1.get_wl_price)(new sui_js_1.TransactionBlock(), signer).then((wl) => console.log(`\t+ WL = ${wl / (10 ** 9)} SUI`));
});
