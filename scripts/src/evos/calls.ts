import {
    JsonRpcProvider,
    RawSigner, 
    SuiAddress, 
    TransactionBlock,
    getExecutionStatusType
} from "@mysten/sui.js";

import {
    EVOS_MODULE_NAME,
    EVOS_PACKAGE_ID,
    INCUBATOR_ID,
    EVOS_GENESIS_TYPE,
    TRANSFER_POLICY,
    ROYALTY_STRATEGY_BPS,
    ALLOWLIST,
    GAME_ID,
    BORROW_POLICY_ID,
    THREAD_CAP_ID 
} from "./ids";

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

// EVOS CORE CALLS

export const on_undelegated_evos = async (
    tx: TransactionBlock,
    nft_id: SuiAddress,
    kiosk: SuiAddress,
    signer: RawSigner,
) => {

    tx.moveCall({
        target: `${EVOS_PACKAGE_ID}::${EVOS_MODULE_NAME}::on_undelegated_evos`,
        arguments: [
            tx.object(GAME_ID),
            tx.object(nft_id),
            tx.object(kiosk),
            tx.object(BORROW_POLICY_ID),
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

export const on_delegated_evos = async (
    tx: TransactionBlock,
    nft_id: SuiAddress,
    kiosk: SuiAddress,
    signer: RawSigner,
) => {

    tx.moveCall({
        target: `${EVOS_PACKAGE_ID}::${EVOS_MODULE_NAME}::on_undelegated_evos`,
        arguments: [
            tx.object(GAME_ID),
            tx.object(nft_id),
            tx.object(kiosk),
            tx.object(BORROW_POLICY_ID),
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

export const delegate = async (
    tx: TransactionBlock,
    kiosk: SuiAddress,
    nft_id: SuiAddress,
    signer: RawSigner,
) => {

    tx.moveCall({
        target: `${EVOS_PACKAGE_ID}::${EVOS_MODULE_NAME}::delegate`,
        arguments: [
            tx.object(GAME_ID),
            tx.object(kiosk),
            tx.object(nft_id),
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

export const cancel_delegation = async (
    tx: TransactionBlock,
    kiosk: SuiAddress,
    nft_id: SuiAddress,
    signer: RawSigner,
) => {

    tx.moveCall({
        target: `${EVOS_PACKAGE_ID}::${EVOS_MODULE_NAME}::cancel_delegation`,
        arguments: [
            tx.object(GAME_ID),
            tx.object(kiosk),
            tx.object(nft_id),
            tx.object(BORROW_POLICY_ID),
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

export const to_next_stage = async (
    tx: TransactionBlock,
    kiosk: SuiAddress,
    nft_id: SuiAddress,
    url: Uint8Array,
    signer: RawSigner,
) => {

    tx.moveCall({
        target: `${EVOS_PACKAGE_ID}::${EVOS_MODULE_NAME}::to_next_stage`,
        arguments: [
            tx.object(GAME_ID),
            tx.object(kiosk),
            tx.object(nft_id),
            tx.pure(url),
            tx.object(BORROW_POLICY_ID),
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

export const open_box = async (
    tx: TransactionBlock,
    box_index: number,
    nft_id: SuiAddress,
    kiosk: SuiAddress,
    signer: RawSigner,
) => {

    tx.moveCall({
        target: `${EVOS_PACKAGE_ID}::${EVOS_MODULE_NAME}::open_box`,
        arguments: [
            tx.object(GAME_ID),
            tx.pure(box_index),
            tx.object(nft_id),
            tx.object(kiosk),
            tx.object(BORROW_POLICY_ID),
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

export const confirm_box_receipt = async (
    tx: TransactionBlock,
    trait_url: Uint8Array,
    nft_id: SuiAddress,
    kiosk: SuiAddress,
    signer: RawSigner,
) => {

    tx.moveCall({
        target: `${EVOS_PACKAGE_ID}::${EVOS_MODULE_NAME}::confirm_box_receipt`,
        arguments: [
            tx.object(THREAD_CAP_ID),
            tx.object(GAME_ID),
            tx.object(nft_id),
            tx.object(kiosk),
            tx.object(BORROW_POLICY_ID),
            tx.pure(trait_url)
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

export const find_eligible_trait_box = async (
    tx: TransactionBlock,
    history: SuiAddress,
    nft_id: SuiAddress,
    settings: SuiAddress,
    signer: RawSigner,
) => {
    tx.moveCall({
        target: `${EVOS_PACKAGE_ID}::${EVOS_MODULE_NAME}::confirm_box_receipt`,
        arguments: [
            tx.object(history),
            tx.object(nft_id),
            tx.object(settings),
        ]
    });
    
    const txn = await signer.signAndExecuteTransactionBlock({
      transactionBlock: tx,
      options: {
        showEffects: true,
        showObjectChanges: true,
      },
    });

    // here we need to get the return value of the call
    
    let status = getExecutionStatusType(txn);
    if(status == 'success'){
      console.log("SUCCESS");
    }
    return status;
}

