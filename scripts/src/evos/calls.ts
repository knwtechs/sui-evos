import {
    JsonRpcProvider,
    MoveEventField,
    ObjectId,
    RawSigner, 
    SuiAddress, 
    TransactionBlock,
    TransactionDigest,
    getExecutionStatusType
} from "@mysten/sui.js";
import { EVOS_MODULE_NAME, EVOS_PACKAGE_ID, INCUBATOR_ID, EVOS_GENESIS_TYPE, TRANSFER_POLICY, ROYALTY_STRATEGY_BPS, ALLOWLIST } from "./ids";

// export type SuiEventFilter =
// | { Package: ObjectId }
// | { MoveModule: { package: ObjectId; module: string } }
// | { MoveEventType: string }
// | { MoveEventField: MoveEventField }
// | { Transaction: TransactionDigest }
// | {
//     TimeRange: {
//         // left endpoint of time interval, milliseconds since epoch, inclusive
//         start_time: number;
//         // right endpoint of time interval, milliseconds since epoch, exclusive
//         end_time: number;
//     };
//     }
// | { Sender: SuiAddress }
// | { All: SuiEventFilter[] }
// | { Any: SuiEventFilter[] }
// | { And: [SuiEventFilter, SuiEventFilter] }
// | { Or: [SuiEventFilter, SuiEventFilter] };

const SUI_CLOCK_ID = "0x6";
const OB_KIOSK = "0x95a441d389b07437d00dd07e0b6f05f513d7659b13fd7c5d3923c7d9d847199b";

export async function deposit(
    tx: TransactionBlock,
    signer: RawSigner,
    amount: number,
  ) {
  
    let price = 5_000_000;
    price *= amount;
    

    let all_evos = await get_objects_by_type(signer.provider, await signer.getAddress(), EVOS_GENESIS_TYPE, 0);

    let evos_id = all_evos[0].data?.objectId;
    if(!evos_id){
        console.log("EVOS_NOT_FOUND");
        return;
    }
    tx.moveCall({
        target: `${EVOS_PACKAGE_ID}::${EVOS_MODULE_NAME}::deposit`,
        arguments: [
            tx.object(INCUBATOR_ID),
            tx.object(evos_id),
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

export const get_objects_by_type = async (
    provider: JsonRpcProvider,
    account: SuiAddress,
    type: string,
    pages = 1
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

export const transfer = async (
    tx: TransactionBlock,
    source: SuiAddress,
    target: SuiAddress,
    nft_id: SuiAddress
) => {
    tx.moveCall({
        target: `${OB_KIOSK}::ob_kiosk::transfer_signed`,
        arguments: [
            tx.object(source),
            tx.object(target),
            tx.object(nft_id),
            tx.pure(0)
        ]
    });
    return tx
    /*
        source: &mut Kiosk,
        target: &mut Kiosk,
        nft_id: ID,
        price: u64,
    */
}

export const get_txs = async (provider: JsonRpcProvider) => {
    let txs: any[] = [];
    let r = await provider.queryTransactionBlocks({filter: {
        MoveFunction: {
            package: EVOS_PACKAGE_ID,
            module: 'evos',
            function: 'reveal'
        }
    }});
    txs.push(...r.data);
    while(r.hasNextPage){
        r = await provider.queryTransactionBlocks({filter: {
            MoveFunction: {
                package: EVOS_PACKAGE_ID,
                module: 'evos',
                function: 'reveal'
            }
        }, cursor: r.nextCursor});
        txs.push(...r.data);
    }
    return txs
}

export const kiosk_self_transfer = (
    tx: TransactionBlock,
    source: SuiAddress,
    nft_id: SuiAddress,
): TransactionBlock => {
    
    tx.moveCall({
        target: `0xd86415b637a1f710e087d5d05e87137ad2a1b267bdf1ab6ee3aea55d39a7f766::helper::remove_lock`,
        arguments: [
            tx.object(source),
            tx.pure(nft_id),
            tx.object(TRANSFER_POLICY),
            tx.object(ALLOWLIST),
            tx.object(ROYALTY_STRATEGY_BPS)
        ],
        typeArguments: ['0x169664f0f62bec3d59bb621d84df69927b3377a1f32ff16c862d28c158480065::evos::Evos']
    });

    return tx
}