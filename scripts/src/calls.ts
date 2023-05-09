import {
  RawSigner, 
  SuiAddress, 
  TransactionBlock,
  getExecutionStatusType
} from "@mysten/sui.js";
import { GENESIS_PACKAGE_ID, GENESIS_MODULE_NAME, MINT_TRACKER_ID } from './ids';
import {get_balance} from './utils';

const SUI_CLOCK_ID = "0x6";
const MAX_MINT_PER_WL = 2;
const MAX_BATCH_SIZE_PUBLIC = 5;

export async function public_mint(
  tx: TransactionBlock,
  signer: RawSigner,
  amount: number,
) {

  if(amount > MAX_BATCH_SIZE_PUBLIC){
    console.log(`You cannot buy more than ${MAX_MINT_PER_WL}`);
    return
  }

  let price = 5_000_000;
  price *= amount;

  let signer_address =  await signer.getAddress();
  let admin_balance = await get_balance(signer_address, signer.provider);
  console.log(admin_balance);
  console.log(signer_address);

  let coins = await signer.provider.getCoins({
    owner: await signer.getAddress(),
    coinType: '0x2::sui::SUI',
  });

  let filtered_coins = coins.data.filter((v) => Number(v.balance) > price);
  if(!(filtered_coins.length > 0)){
    console.log("INSUFFICIENT BALANCE");
    return;
  }
  let recipient = signer.getAddress();
  let coin_id = filtered_coins[0].coinObjectId;
  const coin = tx.object(coin_id);
  const paid = tx.splitCoins(coin, [tx.pure(price)]);
  tx.transferObjects([coin], tx.pure(recipient));

  tx.moveCall({
    target: `${GENESIS_PACKAGE_ID}::${GENESIS_MODULE_NAME}::public_mint`,
    arguments: [
      tx.object(MINT_TRACKER_ID),
      paid,
      tx.pure(1),
      tx.object(SUI_CLOCK_ID)
    ]
  });
  
  const txn = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });
  let status = getExecutionStatusType(txn);
  if(status == 'success'){
    console.log("SUCCESS");
  }
  return status;
}

export async function whitelist_mint(
  tx: TransactionBlock,
  signer: RawSigner,
  amount: number,
) {
  
  if(amount > MAX_MINT_PER_WL){
    console.log(`You cannot buy more than ${MAX_MINT_PER_WL}`);
    return
  }

  let price = 5_000_000;
  price *= amount;

  let signer_address =  await signer.getAddress();
  let admin_balance = await get_balance(signer_address, signer.provider);
  console.log(admin_balance);
  console.log(signer_address);

  let coins = await signer.provider.getCoins({
    owner: await signer.getAddress(),
    coinType: '0x2::sui::SUI',
  });

  let filtered_coins = coins.data.filter((v) => Number(v.balance) > price);
  if(!(filtered_coins.length > 0)){
    console.log("INSUFFICIENT BALANCE");
    return;
  }
  let recipient = signer.getAddress();
  let coin_id = filtered_coins[0].coinObjectId;
  const coin = tx.object(coin_id);
  const paid = tx.splitCoins(coin, [tx.pure(price)]);
  tx.transferObjects([coin], tx.pure(recipient));

  tx.moveCall({
    target: `${GENESIS_PACKAGE_ID}::${GENESIS_MODULE_NAME}::mint_wl_enabled`,
    arguments: [
      tx.object(MINT_TRACKER_ID),
      paid,
      tx.pure(1),
      tx.object(SUI_CLOCK_ID)
    ]
  });
  
  const txn = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });
  let status = getExecutionStatusType(txn);
  //console.log(txn);
  return status;
}

export async function is_whitelisted(
  tx: TransactionBlock,
  signer: RawSigner,
  account: SuiAddress,
) {

  tx.moveCall({
    target: `${GENESIS_PACKAGE_ID}::${GENESIS_MODULE_NAME}::is_whitelisted`,
    arguments: [
      tx.object(MINT_TRACKER_ID),
      tx.pure(account)
    ]
  });

  const ispx = await signer.provider.devInspectTransactionBlock({transactionBlock: tx, sender: account});
  if(ispx.results?.length == 0) return false;
  let ret = ispx.results?.at(0)?.returnValues;
  if(!ret) return false;
  // console.log(ret[0][0][0]);
  return ret[0][0][0] == 1;
}

/* 
 * Each account that has a whitelist spot can mint 2 nfts in whitelist phase.
 * How many nfts left has the given account?
 */
export async function wl_mint_left_for_account(
  tx: TransactionBlock,
  signer: RawSigner,
  account: SuiAddress,
) {

  tx.moveCall({
    target: `${GENESIS_PACKAGE_ID}::${GENESIS_MODULE_NAME}::get_wl_spot_count`,
    arguments: [
      tx.object(MINT_TRACKER_ID),
      tx.pure(account)
    ]
  });
  
  const ispx = await signer.provider.devInspectTransactionBlock({transactionBlock: tx, sender: account});
  if(ispx.results?.length == 0) return false;
  let ret = ispx.results?.at(0)?.returnValues;
  if(!ret) return false;
  //console.log(ret[0]);
  return ret[0][0][0];
}

export async function get_public_start(
  tx: TransactionBlock,
  signer: RawSigner
): Promise<number> {

  tx.moveCall({
    target: `${GENESIS_PACKAGE_ID}::${GENESIS_MODULE_NAME}::public_start`,
    arguments: [tx.object(MINT_TRACKER_ID)]
  });
  
  const ispx = await signer.provider.devInspectTransactionBlock({transactionBlock: tx, sender: await signer.getAddress()});
  if(ispx.results?.length == 0) return 0;
  let ret = ispx.results?.at(0)?.returnValues;
  if(!ret) return 0;
  let ms = Buffer.from(ret[0][0]);
  let _ms = ms.readBigUInt64LE(0);
  return Number(_ms);
}

export async function get_wl_start(
  tx: TransactionBlock,
  signer: RawSigner
): Promise<number> {

  tx.moveCall({
    target: `${GENESIS_PACKAGE_ID}::${GENESIS_MODULE_NAME}::wl_start`,
    arguments: [tx.object(MINT_TRACKER_ID)]
  });
  
  const ispx = await signer.provider.devInspectTransactionBlock({transactionBlock: tx, sender: await signer.getAddress()});
  if(ispx.results?.length == 0) return 0;
  let ret = ispx.results?.at(0)?.returnValues;
  if(!ret) return 0;
  let ms = Buffer.from(ret[0][0]);
  let _ms = ms.readBigUInt64LE(0);
  return Number(_ms);
}