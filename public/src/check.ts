import {
    get_signer,
    load_account,
    load_airdrop_list,
} from './utils';

import {
    JsonRpcProvider,
    SuiAddress,
} from '@mysten/sui.js';

import {
    WALLETS_LIST,
    COLLECTION_TYPE
} from './config';

import {
    existsSync
} from 'fs'

const signer = get_signer(load_account(1));
const provider = signer.provider
const recipients_ = load_airdrop_list(WALLETS_LIST);

const get_objects_by_type = async (
    provider: JsonRpcProvider,
    account: SuiAddress,
    type: string,
    pages = 0
) => {
    let result = []
    let eggs = await provider.getOwnedObjects({owner: account, options: {showType: true}});
    result.push(...eggs.data.filter((obj) => obj.data?.type == type));
    let current = 1;
    while(eggs.hasNextPage){
        if(pages > 0 && current >= pages)
            break
        eggs = await provider.getOwnedObjects({owner: account, cursor: eggs.nextCursor, options: {showType: true}});
        result.push(...eggs.data.filter((obj) => obj.data?.type == type));
        
    }
    return result
}

const check = async () => {
    console.log(`Treasury:`)
    console.log(`\t+ Account: ${await signer.getAddress()}`)

    const holdings = await get_objects_by_type(provider, await signer.getAddress(), COLLECTION_TYPE);
    console.log(`\t+ ${COLLECTION_TYPE.split("::")[2]}: ${holdings.length}`);

    const gas = await provider.getBalance({owner: await signer.getAddress(), coinType: '0x2::sui::SUI'});
    console.log(`\t+ Gas: ${(Number(gas.totalBalance)/1_000_000_000).toFixed(4)} [${gas.coinObjectCount} object(s)]`)

    console.log(`\nAirdrop:`)

    const aidrop_amount: number = recipients_.map(e => e.amount).reduce((acc, curr) => acc + curr, 0);
    console.log(`\t+ Amount: ${aidrop_amount}`);

    console.log(`\t+ Wallet list: ${existsSync(WALLETS_LIST) ? 'found' : 'not found'} at ${WALLETS_LIST}`);
}

check()
    .then(() => console.log("\nDone.\n"))