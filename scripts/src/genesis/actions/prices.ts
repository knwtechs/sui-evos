import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from '../utils';
import {get_public_price, get_wl_price} from '../calls';

let account = load_account();
let signer = get_signer(account);

get_public_price(new TransactionBlock(), signer).then((pub) => {
  console.log(`\n\t+ Public = ${pub/(10**9)} SUI`)
  get_wl_price(new TransactionBlock(), signer).then((wl) => console.log(`\t+ WL = ${wl/(10**9)} SUI`))
})
