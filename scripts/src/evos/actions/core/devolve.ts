import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from '../../../genesis/utils';
import {on_undelegated_evos} from '../../calls';

let account = load_account();
let signer = get_signer(account);
const txblock = new TransactionBlock();

on_undelegated_evos(
  txblock,
  signer,
  1
).then((status) => console.log(`\n\Deposit: ${status}`));