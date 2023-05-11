import {get_signer, load_account, load_addresses_from_list} from '../utils';
import {wl_user} from '../calls';

let signer = get_signer(load_account());
const WALLETS_LIST = "/Users/filipposofi/Documents/Development/blockchain/sui/KunnowTechnologies/ev0s/scripts/awhitelist/list.txt";
const ACCOUNTS = load_addresses_from_list(WALLETS_LIST);
const DELAY = 1000

const do_all = async (accounts: string[]) => {
    for(let i=0; i<accounts.length;i++){
        let account = accounts[i]
        try{
            let status = await wl_user(
                signer,
                account
            );
            console.log(`\n\t [${i+1}/${accounts.length}] WL registered for ${account}: ${status}`)
            await new Promise(f => setTimeout(f, DELAY));
        }catch(e){}
    }
}
console.log(`\n\t+ There are ${ACCOUNTS.length} WL to register...\n`)
do_all(ACCOUNTS)
    .then(() => console.log("\n\t+ WL distributed."));