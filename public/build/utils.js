"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.split_array = exports.get_nfts_id = exports.transfer_from_kiosk_to_kiosk = exports.create_kiosk_for_recipient = exports.load_airdrop_list = exports.load_addresses_from_list = exports.get_signer = exports.load_account = exports.get_balance = exports.generate_account = void 0;
const sui_js_1 = require("@mysten/sui.js");
const fs_1 = require("fs");
const config_1 = require("./config");
const generate_account = () => sui_js_1.Ed25519Keypair.generate();
exports.generate_account = generate_account;
const get_balance = (account, provider) => __awaiter(void 0, void 0, void 0, function* () { return yield provider.getBalance({ owner: account, coinType: '0x2::sui::SUI' }); });
exports.get_balance = get_balance;
const load_account = (index = 0) => {
    let c = (0, fs_1.readFileSync)("/Users/filipposofi/.sui/sui_config/sui.keystore");
    let t = c.toString();
    t = t.replace("[\n", "");
    t = t.replace("\"", "");
    t = t.replace("]", "");
    let _t = t.split(",");
    const raw = (0, sui_js_1.fromB64)(_t[index]);
    if (raw[0] !== 0 || raw.length !== sui_js_1.PRIVATE_KEY_SIZE + 1) {
        throw new Error('invalid key');
    }
    let key = raw.slice(1);
    return sui_js_1.Ed25519Keypair.fromSecretKey(key);
};
exports.load_account = load_account;
const get_signer = (account, connection) => {
    if (!connection)
        connection = new sui_js_1.Connection({ fullnode: config_1.RPC_ENDPOINT });
    return new sui_js_1.RawSigner(account, new sui_js_1.JsonRpcProvider(connection));
};
exports.get_signer = get_signer;
const load_addresses_from_list = (path) => {
    let file = (0, fs_1.readFileSync)(path, 'utf-8');
    return file.split(/\r?\n/).map((line) => {
        return line.trim();
    });
};
exports.load_addresses_from_list = load_addresses_from_list;
const load_airdrop_list = (path) => {
    let file = (0, fs_1.readFileSync)(path, 'utf-8');
    return file.split(/\r?\n/).map((line) => {
        let d = line.trim().split(" ");
        return {
            address: d[0],
            amount: Number(d[1])
        };
    });
};
exports.load_airdrop_list = load_airdrop_list;
const create_kiosk_for_recipient = (tx, recipient) => {
    tx.moveCall({
        target: `${config_1.OB_KIOSK}::ob_kiosk::new_for_address`,
        arguments: [
            tx.pure(recipient),
        ]
    });
    return tx;
};
exports.create_kiosk_for_recipient = create_kiosk_for_recipient;
const transfer_from_kiosk_to_kiosk = (tx, from_kiosk, to_kiosk, nft_id) => {
    tx.moveCall({
        target: `${config_1.OB_KIOSK}::ob_kiosk::transfer_signed`,
        arguments: [
            tx.object(from_kiosk),
            tx.object(to_kiosk),
            tx.object(nft_id),
            tx.pure(0)
        ]
    });
    return tx;
};
exports.transfer_from_kiosk_to_kiosk = transfer_from_kiosk_to_kiosk;
const get_nfts_id = (signer, kiosk) => __awaiter(void 0, void 0, void 0, function* () {
    let result = [];
    let nfts = yield signer.provider.getDynamicFields({ parentId: kiosk });
    result.push(...nfts.data.filter(e => e.objectType == config_1.COLLECTION_TYPE).map(e => e.objectId));
    while (nfts.hasNextPage) {
        result.push(...nfts.data.filter(e => e.objectType == config_1.COLLECTION_TYPE).map(e => e.objectId));
        nfts = yield signer.provider.getDynamicFields({ parentId: kiosk, cursor: nfts.nextCursor });
    }
    return result;
});
exports.get_nfts_id = get_nfts_id;
const split_array = (array, n) => {
    const chunkSize = Math.ceil(array.length / n);
    const result = [];
    for (let i = 0; i < array.length; i += chunkSize) {
        result.push(array.slice(i, i + chunkSize));
    }
    return result;
};
exports.split_array = split_array;
