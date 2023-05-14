import {get_signer, load_account, load_addresses_from_list, load_airdrop_list} from '../utils';
import {presale_mint, is_whitelisted} from '../calls';
import { TransactionBlock } from '@mysten/sui.js';

let signer = get_signer(load_account());

const WALLETS_LIST = "/Users/filipposofi/Documents/Development/blockchain/sui/KunnowTechnologies/ev0s/scripts/awhitelist/list.txt";
const RECIPIENTS = load_addresses_from_list(WALLETS_LIST);

const do_all = async (recipients: string[]) => {
    let i=0;
    while(i<recipients.length){
        let recipient = recipients[i];
        try{
            let is_wl = await is_whitelisted(new TransactionBlock(), signer, recipient);
            console.log(`\t+ [${i+1}] ${recipient}: ${is_wl ? String(is_wl).toLocaleLowerCase() : String(is_wl).toLocaleUpperCase()}`);
            await new Promise(f => setTimeout(f, 200));
        }catch(e){console.log(`\t+ [${i+1}] [INVALID_ADDRESS] ${recipient}`)}
        i++
    }
}

console.log("[\n[WL-CHECK]\n")
do_all(RECIPIENTS)
    .then(() => console.log("\n\t+ Airdrop done."));