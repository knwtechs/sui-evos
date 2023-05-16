import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from '../utils';
import {is_whitelisted} from '../calls';

let account = load_account();
let signer = get_signer(account);
const txblock = new TransactionBlock();
let check = "0x987dc7c35eec73687927a4a1f695db73e05a84ae6842e8ed19a320648e1e89a4";

is_whitelisted(
  txblock,
  signer,
  check
).then((tx) => {
  console.log(tx);
});