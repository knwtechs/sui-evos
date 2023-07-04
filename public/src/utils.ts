import {
    RawSigner, 
    SuiAddress, 
    Ed25519Keypair,
    JsonRpcProvider,
    Connection,
    fromB64,
    PRIVATE_KEY_SIZE,
    Keypair,
    TransactionBlock,
    TransactionBlockInput
} from "@mysten/sui.js";
import { readFileSync} from 'fs';
import { COLLECTION_TYPE, OB_KIOSK, RPC_ENDPOINT } from "./config";

export const generate_account = () =>
    Ed25519Keypair.generate();

export const get_balance = async (account: SuiAddress, provider: JsonRpcProvider) =>
    await provider.getBalance({owner: account, coinType: '0x2::sui::SUI'});

export const load_account = (index = 0): Ed25519Keypair => {
    let c = readFileSync("/Users/filipposofi/.sui/sui_config/sui.keystore");
    let t = c.toString();
    t = t.replace("[\n", "");
    t = t.replace("\"", "");
    t = t.replace("]", "");
    let _t = t.split(",");
    const raw = fromB64(_t[index]);
    if (raw[0] !== 0 || raw.length !== PRIVATE_KEY_SIZE + 1) {
      throw new Error('invalid key');
    }
    let key = raw.slice(1, );
    return Ed25519Keypair.fromSecretKey(key);
}

export const get_signer = (account: Keypair, connection?: Connection) => {    
    if(!connection)
        connection = new Connection({fullnode: RPC_ENDPOINT})
    return new RawSigner(account, new JsonRpcProvider(connection));
}

export const load_addresses_from_list = (path: string): string[] => {
    let file = readFileSync(path, 'utf-8');
    return file.split(/\r?\n/).map((line) => {
        return line.trim()
    });
}

export const load_airdrop_list = (path: string): {
    address: string,
    amount: number
}[] => {
    let file = readFileSync(path, 'utf-8');
    return file.split(/\r?\n/).map((line) => {
        let d = line.trim().split(" ")
        return {
            address: d[0],
            amount: Number(d[1])
        }
    });
}

export const create_kiosk_for_recipient = (tx: TransactionBlock, recipient: SuiAddress) => {
    return tx.moveCall({
        target: `${OB_KIOSK}::ob_kiosk::new_for_address`,
        arguments: [
            tx.pure(recipient),
        ]
    });
}

export const transfer_from_kiosk = (
    tx: TransactionBlock,
    from_kiosk: SuiAddress,
    recipient: SuiAddress,
    nft_id: SuiAddress
): TransactionBlock => {

    let k = tx.moveCall({
        target: `${OB_KIOSK}::ob_kiosk::new_for_address`,
        arguments: [
            tx.pure(recipient),
        ]
    });
    console.log(k);

    // tx.moveCall({
    //     target: `${OB_KIOSK}::ob_kiosk::transfer_signed`,
    //     arguments: [
    //         tx.object(from_kiosk),
    //         ,
    //         tx.object(nft_id),
    //         tx.pure(0)
    //     ]
    // });
    return tx
}

export const get_nfts_id = async (signer: RawSigner, kiosk: SuiAddress): Promise<SuiAddress[]>=> {
    let result: SuiAddress[] = [];
    let nfts = await signer.provider.getDynamicFields({parentId: kiosk});
    result.push(...nfts.data.filter(e => e.objectType == COLLECTION_TYPE).map(e => e.objectId))
    while(nfts.hasNextPage){
        result.push(...nfts.data.filter(e => e.objectType == COLLECTION_TYPE).map(e => e.objectId))
        nfts = await signer.provider.getDynamicFields({parentId: kiosk, cursor: nfts.nextCursor});
    }
    return result;
}

export const split_array = (array: any, n: number) => {
    const chunkSize = Math.ceil(array.length / n);
    const result = [];
    for (let i = 0; i < array.length; i += chunkSize) {
        result.push(array.slice(i, i + chunkSize));
    }
    return result;
}