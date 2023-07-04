// remove_auth_transfer
import {Connection, SuiAddress, TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from '../../../genesis/utils';
import {get_txs, kiosk_self_transfer} from '../../calls';
import {KioskFullClient} from '@originbyte/js-sdk';

const DELAY = 300;
const account = load_account(0);
const signer = get_signer(account, new Connection({fullnode: "https://mainnet.artifact.systems:443/sui/6ft5nn4g4o"}));
const kiosk_client = KioskFullClient.fromRpcUrl("https://sui-mainnet-rpc.allthatnode.com:443/3KDd6cUIo3MuI3cgquZ7slRYYCFc8UKF", {
    packageObjectId:
      "0x95a441d389b07437d00dd07e0b6f05f513d7659b13fd7c5d3923c7d9d847199b",
});

get_txs(signer.provider).then(async (txs) => {

    console.log(`\n====\t${txs.length} txs to scan\t====\n`)

    let senders: {
        address: SuiAddress,
        kiosks: {
            kioskId: SuiAddress,
            nft: SuiAddress
        }[],
    }[] = []

    // foreach `evos::evolve` tx
    for(let i = 0; i < txs.length; i++){
        const tx = txs[i]
        process.stdout.write(`\r[PREPARE][${i}/${txs.length}] Fetching block`)

        // Get Tx Info
        let txinfo = await signer.provider.getTransactionBlock({digest: tx.digest, options: {
            showInput: true,
            showEffects: true,
            showObjectChanges: true
        }});
        await new Promise(f => setTimeout(f, DELAY));

        if(txinfo.effects?.status.error)
            continue;
        
        // Sender's Kiosks
        let tx_sender = txinfo.transaction?.data.sender!;
        // if(!(tx_sender == "0x2081998526d3d1fa46e022f9fbf788c2869f61f3f3da0677d3b630ac7b76a056"))
        //     continue
        let kiosks = await kiosk_client.getAllNftKioskAssociations(tx_sender)
        await new Promise(f => setTimeout(f, DELAY));
        senders.push({
            address: txinfo.transaction?.data.sender!,
            kiosks
        });
        process.stdout.write(`\r[PREPARE][${i}/${txs.length}] Found ${kiosks.length} nfts. `)
        await new Promise(f => setTimeout(f, DELAY));
    }

    let tot = senders.reduce((prev, curr) => prev + curr.kiosks.length, 0)
    console.log(`\n[EXECUTION] ${tot} total Ev0s to self-transfer.\n`)

    // Here we have all the kiosks and senders, time to send
    for(let s of senders){
        let txid;
        for(let kiosk of s.kiosks){
            try{
                const tx = new TransactionBlock()
                tx.setGasBudget(150_000_000)
                kiosk_self_transfer(tx, kiosk.kioskId, kiosk.nft)
                txid = await signer.signAndExecuteTransactionBlock({transactionBlock: tx, options: {showEffects: true}});
                
                // if(!txid.confirmedLocalExecution){
                //     console.log(txid)
                //     continue
                // }
                
                console.log(`\t+ [${txid.digest}] ${txid.effects?.status ? txid.effects?.status.status : txid.effects?.status.error}`)
            }catch(err){console.log(err);}
        }
    }    
})