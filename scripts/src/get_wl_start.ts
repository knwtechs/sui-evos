import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from './utils';
import {get_wl_start} from './calls';

let account = load_account();
let signer = get_signer(account);
const txblock = new TransactionBlock();

get_wl_start(
  txblock,
  signer
).then((ms) => console.log(`\n\WL start: ${new Date(ms).toLocaleString()}`));