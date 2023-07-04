import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from '../../../genesis/utils';
import {deposit} from '../../calls';

let account = load_account();
let signer = get_signer(account);
const txblock = new TransactionBlock();

deposit(
  txblock,
  signer,
  1
).then((status) => console.log(`\n\Deposit: ${status}`));