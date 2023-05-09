import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from './utils';
import {is_whitelisted} from './calls';

let account = load_account();
let signer = get_signer(account);
const txblock = new TransactionBlock();

is_whitelisted(
  txblock,
  signer,
  account.getPublicKey().toSuiAddress()
).then((tx) => {
  console.log(tx);
});