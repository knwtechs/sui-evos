import {
    JsonRpcProvider,
    RawSigner, 
    SuiAddress, 
    TransactionBlock,
    getExecutionStatusType
} from "@mysten/sui.js";
import { EVOS_MODULE_NAME, EVOS_PACKAGE_ID, INCUBATOR_ID, EVOS_GENESIS_TYPE } from "./ids";

const SUI_CLOCK_ID = "0x6";

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