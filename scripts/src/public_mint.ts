import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from './utils';
import {public_mint} from './calls';

let account = load_account();
let signer = get_signer(account);
const txblock = new TransactionBlock();

public_mint(
  txblock,
  signer,
  1
).then((status) => console.log(`\n\tMint: ${status}`));