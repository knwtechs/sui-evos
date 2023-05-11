"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sui_js_1 = require("@mysten/sui.js");
const utils_1 = require("../utils");
const calls_1 = require("../calls");
let account = (0, utils_1.load_account)();
let signer = (0, utils_1.get_signer)(account);
const txblock = new sui_js_1.TransactionBlock();
let check = "0x64e213419792a92dd2cc557a0e453f337a6b4d77385a0a1ea6fcdd579eded4ab";
(0, calls_1.is_whitelisted)(txblock, signer, check).then((tx) => {
    console.log(tx);
});
