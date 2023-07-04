"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sui_js_1 = require("@mysten/sui.js");
const utils_1 = require("../utils");
const calls_1 = require("../calls");
let account = (0, utils_1.load_account)();
let signer = (0, utils_1.get_signer)(account);
const txblock = new sui_js_1.TransactionBlock();
let check = "0x987dc7c35eec73687927a4a1f695db73e05a84ae6842e8ed19a320648e1e89a4";
(0, calls_1.is_whitelisted)(txblock, signer, check).then((tx) => {
    console.log(tx);
});
