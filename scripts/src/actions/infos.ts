import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from '../utils';
import {get_public_price, get_wl_price, get_wl_start, get_public_start} from '../calls';

let account = load_account();
let signer = get_signer(account);

get_public_start(new TransactionBlock(), signer).then(async (pubStart) => {
  await new Promise(f => setTimeout(f, 1000));
  console.log(`\n[DATES]`)
  console.log("\t+ Public = ", new Date(pubStart))
  console.log("\t+ WL = ", new Date(await get_wl_start(new TransactionBlock(), signer)))
  console.log(`\n[PRICES]`)
  console.log(`\t+ Public = ${(await get_public_price(new TransactionBlock(), signer)) / (10**9)} SUI`)
  console.log(`\t+ WL = ${(await get_wl_price(new TransactionBlock(), signer)) / (10**9)} SUI\n`)
});
