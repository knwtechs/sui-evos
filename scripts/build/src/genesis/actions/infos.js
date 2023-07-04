"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sui_js_1 = require("@mysten/sui.js");
const utils_1 = require("../utils");
const calls_1 = require("../calls");
let account = (0, utils_1.load_account)();
let signer = (0, utils_1.get_signer)(account);
(0, calls_1.get_public_start)(new sui_js_1.TransactionBlock(), signer).then(async (pubStart) => {
    await new Promise(f => setTimeout(f, 1000));
    console.log(`\n[DATES]`);
    console.log("\t+ Public = ", new Date(pubStart));
    console.log("\t+ WL = ", new Date(await (0, calls_1.get_wl_start)(new sui_js_1.TransactionBlock(), signer)));
    console.log(`\n[PRICES]`);
    console.log(`\t+ Public = ${(await (0, calls_1.get_public_price)(new sui_js_1.TransactionBlock(), signer)) / (10 ** 9)} SUI`);
    console.log(`\t+ WL = ${(await (0, calls_1.get_wl_price)(new sui_js_1.TransactionBlock(), signer)) / (10 ** 9)} SUI\n`);
});
