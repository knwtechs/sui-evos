"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.wl_mint_left_for_account = exports.is_whitelisted = exports.whitelist_mint = exports.public_mint = void 0;
const sui_js_1 = require("@mysten/sui.js");
const ids_1 = require("./ids");
const utils_1 = require("./utils");
const SUI_CLOCK_ID = "0x6";
const MAX_MINT_PER_WL = 2;
const MAX_BATCH_SIZE_PUBLIC = 5;
async function public_mint(tx, signer, amount) {
    if (amount > MAX_BATCH_SIZE_PUBLIC) {
        console.log(`You cannot buy more than ${MAX_MINT_PER_WL}`);
        return;
    }
    let price = 5000000;
    price *= amount;
    let signer_address = await signer.getAddress();
    let admin_balance = await (0, utils_1.get_balance)(signer_address, signer.provider);
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
    let recipient = signer.getAddress();
    let coin_id = filtered_coins[0].coinObjectId;
    const coin = tx.object(coin_id);
    const paid = tx.splitCoins(coin, [tx.pure(price)]);
    tx.transferObjects([coin], tx.pure(recipient));
    tx.moveCall({
        target: `${ids_1.GENESIS_PACKAGE_ID}::${ids_1.GENESIS_MODULE_NAME}::public_mint`,
        arguments: [
            tx.object(ids_1.MINT_TRACKER_ID),
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
    if (status == 'success') {
        console.log("SUCCESS");
    }
    return [txn, status];
}
exports.public_mint = public_mint;
async function whitelist_mint(tx, signer, amount) {
    if (amount > MAX_MINT_PER_WL) {
        console.log(`You cannot buy more than ${MAX_MINT_PER_WL}`);
        return;
    }
    let price = 5000000;
    price *= amount;
    let signer_address = await signer.getAddress();
    let admin_balance = await (0, utils_1.get_balance)(signer_address, signer.provider);
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
    let recipient = signer.getAddress();
    let coin_id = filtered_coins[0].coinObjectId;
    const coin = tx.object(coin_id);
    const paid = tx.splitCoins(coin, [tx.pure(price)]);
    tx.transferObjects([coin], tx.pure(recipient));
    tx.moveCall({
        target: `${ids_1.GENESIS_PACKAGE_ID}::${ids_1.GENESIS_MODULE_NAME}::mint_wl_enabled`,
        arguments: [
            tx.object(ids_1.MINT_TRACKER_ID),
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
    return txn;
}
exports.whitelist_mint = whitelist_mint;
async function is_whitelisted(tx, signer, account) {
    tx.moveCall({
        target: `${ids_1.GENESIS_PACKAGE_ID}::${ids_1.GENESIS_MODULE_NAME}::is_whitelisted`,
        arguments: [
            tx.object(ids_1.MINT_TRACKER_ID),
            tx.pure(account)
        ]
    });
    const txn = await signer.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
            showEffects: true,
            showObjectChanges: true,
            showBalanceChanges: true,
            showEvents: true
        },
    });
    let status = (0, sui_js_1.getExecutionStatusType)(txn);
    if (status == 'success') {
        console.log("SUCCESS");
    }
    return txn;
}
exports.is_whitelisted = is_whitelisted;
/*
 * Each account that has a whitelist spot can mint 2 nfts in whitelist phase.
 * How many nfts left has the given account?
 */
async function wl_mint_left_for_account(tx, signer, account) {
    tx.moveCall({
        target: `${ids_1.GENESIS_PACKAGE_ID}::${ids_1.GENESIS_MODULE_NAME}::get_position`,
        arguments: [
            tx.object(ids_1.MINT_TRACKER_ID),
            tx.pure(account)
        ]
    });
    const txn = await signer.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
            showEffects: true,
            showObjectChanges: true,
            showBalanceChanges: true
        },
    });
    let status = (0, sui_js_1.getExecutionStatusType)(txn);
    console.log(txn);
    if (status == 'success') {
        console.log("SUCCESS");
    }
    return txn;
}
exports.wl_mint_left_for_account = wl_mint_left_for_account;
