import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from './utils';
import {get_public_start} from './calls';

let account = load_account();
let signer = get_signer(account);
const txblock = new TransactionBlock();

get_public_start(
  txblock,
  signer
).then((millis) => console.log(`\n\Public start: ${new Date(millis).toLocaleString()}`));