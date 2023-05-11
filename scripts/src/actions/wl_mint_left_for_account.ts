import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from '../utils';
import {wl_mint_left_for_account} from '../calls';

let account = load_account();
let signer = get_signer(account);
const txblock = new TransactionBlock();

wl_mint_left_for_account(
  txblock,
  signer,
  account.getPublicKey().toSuiAddress()
).then((spot) => console.log(`\n\t+ WL spots for ${account.getPublicKey().toSuiAddress()}: ${spot}\n`));