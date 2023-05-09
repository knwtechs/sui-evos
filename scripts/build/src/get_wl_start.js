"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sui_js_1 = require("@mysten/sui.js");
const utils_1 = require("./utils");
const calls_1 = require("./calls");
let account = (0, utils_1.load_account)();
let signer = (0, utils_1.get_signer)(account);
const txblock = new sui_js_1.TransactionBlock();
(0, calls_1.get_wl_start)(txblock, signer).then((ms) => console.log(`\n\WL start: ${new Date(ms).toLocaleString()}`));
