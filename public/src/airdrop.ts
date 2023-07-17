import {
    create_kiosk_for_recipient,
    get_nfts_id,
    get_signer,
    load_account,
    load_airdrop_list,
    split_array
} from './utils';

import {
    JsonRpcProvider,
    RawSigner,
    SuiAddress,
    TransactionBlock
} from '@mysten/sui.js';

import {
    WALLETS_LIST,
    COLLECTION_TYPE,
    DELAY,
    KIOSK_FROM
} from './config';

const CHUNK_SIZE = 200;

// Here you can pass an index to load_account to specify which account you want to load
// Ex: load_account(3) it will load the 4th account.
// You can obtain all your account by running `sui client addresses`
const signer = get_signer(load_account());
const provider = signer.provider
const recipients_ = load_airdrop_list(WALLETS_LIST);

const select_nfts = (nfts: SuiAddress[], amount: number): [SuiAddress[], SuiAddress[]] => {
    let r: SuiAddress[] = []
    for(let i=0;i<amount; i++){
        r.push(nfts.pop()!);
    }
    return [r, nfts]
}
// const airdrop = async (
//     recipients: {address: string, amount: number}[],
//     provider: JsonRpcProvider,
//     signer: RawSigner
// ) => {
//     const chunks = split_array(recipients, CHUNK_SIZE);

//     // Retrieve all the objects owned by the treasury
//     let nft_id = await get_nfts_id(signer, KIOSK_FROM);
//     let aidrop_amount: number = recipients.map(e => e.amount).reduce((acc, curr) => acc + curr, 0);
//     if(aidrop_amount > nft_id.length){
//         console.log(`[AIRDROP] Not enough NFTs in treasury wallet! [${nft_id.length}/${aidrop_amount}]`);
//         return
//     }

//     for(let i=0; i<=chunks.length; i+=1){
//         const tx = new TransactionBlock()
//         const chunk = chunks[i]
//         for(let recipient of chunk){
//             const [objs, updated] = select_nfts(nft_id, recipient.amount);
//             nft_id = updated;
//             let kiosk = create_kiosk_for_recipient(tx, recipient.address);
//             for(let id of objs){
//                 transfer_from_kiosk_to_kiosk(tx, KIOSK_FROM, kiosk, id);
//             }
//             //tx.transferObjects(objs.map(o => tx.pure(o)), tx.pure(recipient.address))
//         }
//         let txid = await signer.signAndExecuteTransactionBlock({transactionBlock: tx});
//         console.log(`[${i+1}/${chunks.length}] ${txid.digest} | ${txid.effects?.status.status}`);
//         await new Promise(f => setTimeout(f, DELAY));
//     }
// }

// airdrop(recipients_, provider, signer)
//     .then(() => console.log("\n\t+ Airdrop done."));

get_nfts_id(signer, KIOSK_FROM).then(console.log)