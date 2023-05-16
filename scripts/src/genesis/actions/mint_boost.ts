import {get_signer, load_account, load_addresses_from_list, load_airdrop_list} from '../utils';
import {presale_mint} from '../calls';

let signer = get_signer(load_account());

const WALLETS_LIST = "/Users/filipposofi/Documents/Development/blockchain/sui/KunnowTechnologies/ev0s/scripts/aboost/list.txt";
const RECIPIENTS = load_addresses_from_list(WALLETS_LIST);

const do_all = async (recipients: string[]) => {
    for(let i=0; i<recipients.length; i++){
        let recipient = recipients[i];
        let t = Date.now()
        let amount = Math.ceil(Number((Math.random() * (10 - 1) + 1)))
        try{
            let status = await presale_mint(
                signer,
                recipient,
                amount
            );
            console.log(`\t+ [${((Date.now() - t) / 1000).toFixed(2)}s][${i+1}/${recipients.length}] Airdrop to ${recipient} ${amount} nfts: ${status}`);
            await new Promise(f => setTimeout(f, (Math.random() * (2500 - 800) + 800)));
        }catch(e){console.log(e)}
    }
}

do_all(RECIPIENTS)
    .then(() => console.log("\n\t+ Airdrop done."));