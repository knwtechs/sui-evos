"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sui_js_1 = require("@mysten/sui.js");
const utils_1 = require("./utils");
const calls_1 = require("./calls");
let account = (0, utils_1.load_account)();
let signer = (0, utils_1.get_signer)(account);
const txblock = new sui_js_1.TransactionBlock();
(0, calls_1.wl_mint_left_for_account)(txblock, signer, account.getPublicKey().toSuiAddress()).then((spot) => console.log(`\n\t+ WL spots for ${account.getPublicKey().toSuiAddress()}: ${spot}\n`));
