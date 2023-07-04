import {
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
    WALLETS_LIST_TEST,
    COLLECTION_TYPE_TEST,
    DELAY
} from './config';

const CHUNK_SIZE = 200;

// Here you can pass an index to load_account to specify which account you want to load
// Ex: load_account(3) it will load the 4th account.
// You can obtain all your account by running `sui client addresses`
const signer = get_signer(load_account());
const provider = signer.provider
const recipients_ = load_airdrop_list(WALLETS_LIST_TEST);

const get_objects_by_type = async (
    provider: JsonRpcProvider,
    account: SuiAddress,
    type: string,
    pages = 0
) => {
    let result = []
    let eggs = await provider.getOwnedObjects({owner: account});
    let has_next_page = eggs.hasNextPage;
    let current = 1;
    while(has_next_page){
        if(pages > 0 && current >= pages)
            break
        eggs = await provider.getOwnedObjects({owner: account, cursor: eggs.nextCursor});
        result.push(...eggs.data.filter((obj) => obj.data?.type == type));
        has_next_page = eggs.hasNextPage
        
    }
    return result
}
const select_nfts = (nfts: any[], amount: number): [any[], any[]] => {
    let r: any[] = []
    for(let i=0;i<amount; i++){
        r = nfts.pop();
    }
    return [r, nfts]
}
const airdrop_test = async (
    recipients: {address: string, amount: number}[],
    provider: JsonRpcProvider,
    signer: RawSigner
) => {
    const chunks = split_array(recipients, CHUNK_SIZE);

    // Retrieve all the objects owned by the treasury
    let nfts = await get_objects_by_type(provider, await signer.getAddress(), COLLECTION_TYPE_TEST);
    let nft_id: SuiAddress[] = nfts.filter(e => e.data).map(e => e.data?.objectId!);
    let aidrop_amount: number = recipients.map(e => e.amount).reduce((acc, curr) => acc + curr, 0);
    if(aidrop_amount > nft_id.length){
        console.log(`[AIRDROP] Not enough NFTs in treasury wallet! [${nft_id.length}/${aidrop_amount}]`);
        return
    }

    for(let i=0; i<=chunks.length; i+=1){
        const chunk = chunks[i]
        let tx = new TransactionBlock();
        let local = 0;
        for(let recipient of chunk){
            const [objs, updated] = select_nfts(nfts, recipient.amount);
            nfts = updated;
            local += objs.reduce((acc, curr) => acc += curr.amount, 0);
            tx.transferObjects(objs.map(o => tx.pure(o)), tx.pure(recipient.address))
        }
        let txid = await signer.signAndExecuteTransactionBlock({transactionBlock: tx});
        console.log(`[${i+1}/${chunks.length}] ${txid.digest} | ${local} | ${txid.effects?.status.status}`);
        await new Promise(f => setTimeout(f, DELAY));
    }
}

airdrop_test(recipients_, provider, signer)
    .then(() => console.log("\n\t+ Airdrop done."));