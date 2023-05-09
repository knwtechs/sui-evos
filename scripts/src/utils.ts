import {
    RawSigner, 
    SuiAddress, 
    Ed25519Keypair,
    JsonRpcProvider,
    Connection,
    fromB64,
    PRIVATE_KEY_SIZE,
    Keypair
} from "@mysten/sui.js";
import { get_connection } from "./rpc";
import { readFileSync} from 'fs';

export function generate_account(){
    return Ed25519Keypair.generate();
}

export function load_account(): Ed25519Keypair {
    let c = readFileSync("/Users/filipposofi/.sui/sui_config/sui.keystore");
    let t = c.toString();
    t = t.replace("[\n", "");
    t = t.replace("\"", "");
    t = t.replace("]", "");
    let _t = t.split(",");
    const raw = fromB64(_t[1]);
    if (raw[0] !== 0 || raw.length !== PRIVATE_KEY_SIZE + 1) {
      throw new Error('invalid key');
    }
    let key = raw.slice(1, );
    return Ed25519Keypair.fromSecretKey(key);
}

export async function get_balance(account: SuiAddress, provider: JsonRpcProvider) {
    return await provider.getBalance({owner: account, coinType: '0x2::sui::SUI'});
}

export function get_signer(account: Keypair, connection?: Connection) {    
    if(!connection)
        connection = get_connection();
    return new RawSigner(account, new JsonRpcProvider(connection));
}