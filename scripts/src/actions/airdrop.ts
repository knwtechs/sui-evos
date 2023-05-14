import {get_signer, load_account, load_airdrop_list} from '../utils';
import {presale_mint} from '../calls';

let signer = get_signer(load_account());

const WALLETS_LIST = "/Users/filipposofi/Documents/Development/blockchain/sui/KunnowTechnologies/ev0s/scripts/aairdrop/list.txt";
const RECIPIENTS = load_airdrop_list(WALLETS_LIST);
const DELAY = 250

const do_all = async (recipients: {address: string, amount: number}[]) => {
    for(let i=0; i<recipients.length; i++){
        let recipient = recipients[i];
        let t = Date.now()
        try{
            let status = await presale_mint(
                signer,
                recipient.address,
                recipient.amount
            );
            console.log(`\t+ [${((Date.now() - t) / 1000).toFixed(2)}s][${i+1}/${recipients.length}] Airdrop to ${recipient.address} ${recipient.amount} nfts: ${status}`);
            await new Promise(f => setTimeout(f, DELAY));
        }catch(e){}
    }
}

do_all(RECIPIENTS)
    .then(() => console.log("\n\t+ Airdrop done."));