"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.mint = void 0;
const sui_js_1 = require("@mysten/sui.js");
const fs_1 = require("fs");
const GENESIS_PACKAGE_ID = "0xf468ec8e144c6314b62264f5dd4e68bb368e3ad2e8ffc05e9d837e8dd8d86df9";
const GENESIS_MODULE_NAME = "evosgenesisegg";
const MINT_TRACKER_ID = "0x1d35fddf26d979625b08da731ce20cadb91d0225c3a898dff46379bad9055666";
const SUI_CLOCK_ID = "0x6";
function generate_account() {
    return sui_js_1.Ed25519Keypair.generate();
}
async function mint(tx, signer, tracker_id, recipient, amount) {
    let price = 5000000;
    price *= amount;
    let signer_address = await signer.getAddress();
    let admin_balance = await get_balance(signer_address, signer.provider);
    console.log(admin_balance);
    console.log(signer_address);
    let coins = await signer.provider.getCoins({
        owner: await signer.getAddress(),
        coinType: '0x2::sui::SUI',
    });
    let filtered_coins = coins.data.filter((v) => Number(v.balance) > price);
    if (!(filtered_coins.length > 0)) {
        console.log("INSUFFICIENT BALANCE");
        return;
    }
    let coin_id = filtered_coins[0].coinObjectId;
    // console.log(_coin);
    const coin = tx.object(coin_id);
    const paid = tx.splitCoins(coin, [tx.pure(price)]);
    tx.transferObjects([coin], tx.pure(recipient));
    tx.moveCall({
        target: `${GENESIS_PACKAGE_ID}::${GENESIS_MODULE_NAME}::public_mint`,
        arguments: [
            tx.object(tracker_id),
            paid,
            tx.pure(1),
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
    let status = (0, sui_js_1.getExecutionStatusType)(txn);
    console.log(txn);
    if (status == 'success') {
        console.log("SUCCESS");
    }
    else {
    }
    return txn;
}
exports.mint = mint;
function load_account() {
    let c = (0, fs_1.readFileSync)("/Users/filipposofi/.sui/sui_config/sui.keystore");
    let t = c.toString();
    t = t.replace("[\n", "");
    t = t.replace("\"", "");
    t = t.replace("]", "");
    let _t = t.split(",");
    const raw = (0, sui_js_1.fromB64)(_t[1]);
    if (raw[0] !== 0 || raw.length !== sui_js_1.PRIVATE_KEY_SIZE + 1) {
        throw new Error('invalid key');
    }
    let key = raw.slice(1);
    return sui_js_1.Ed25519Keypair.fromSecretKey(key);
}
async function get_balance(account, provider) {
    return await provider.getBalance({ owner: account, coinType: '0x2::sui::SUI' });
}
let account = load_account();
let connection = new sui_js_1.Connection({ fullnode: "https://fullnode.mainnet.sui.io:443" });
let signer = new sui_js_1.RawSigner(account, new sui_js_1.JsonRpcProvider(connection));
const txblock = new sui_js_1.TransactionBlock();
mint(txblock, signer, MINT_TRACKER_ID, account.getPublicKey().toSuiAddress(), 1).then(console.log);
