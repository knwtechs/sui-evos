import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from '../utils';
import {is_whitelisted} from '../calls';

let account = load_account();
let signer = get_signer(account);
const txblock = new TransactionBlock();
let check = "0x64e213419792a92dd2cc557a0e453f337a6b4d77385a0a1ea6fcdd579eded4ab";

is_whitelisted(
  txblock,
  signer,
  check
).then((tx) => {
  console.log(tx);
});