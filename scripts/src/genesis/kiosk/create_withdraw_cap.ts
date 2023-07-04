import { TransactionBlock } from "@mysten/sui.js";
import { GENESIS_PACKAGE_ID, PUBLISHER_ID } from "../ids";
import { get_signer, load_account } from "../utils";

const ob_request_package_id = "0xe2c7a6843cb13d9549a9d2dc1c266b572ead0b4b9f090e7c3c46de2714102b43";

const create_withdraw_policy_and_cap = async () => {
    const tx = new TransactionBlock();
    const signer = get_signer(load_account());
    const token_type = `${GENESIS_PACKAGE_ID}::evosgenesisegg::EvosGenesisEgg`;
    
    const [ policy, policyCap ] = tx.moveCall({
        target: `${ob_request_package_id}::withdraw_request::init_policy`,
        typeArguments: [token_type],
        arguments: [tx.object(PUBLISHER_ID)],
    });
    tx.transferObjects([policyCap], tx.pure(await signer.getAddress(), "address"));
    
    tx.moveCall({
        target: `0x2::transfer::public_share_object`,
        typeArguments: [`${ob_request_package_id}::request::Policy<${ob_request_package_id}::request::WithNft<${token_type}, ${ob_request_package_id}::withdraw_request::WITHDRAW_REQ>>`],
        arguments: [policy],
    });

    return await signer.signAndExecuteTransactionBlock({transactionBlock: tx});
}

create_withdraw_policy_and_cap()
    .then(console.log)
