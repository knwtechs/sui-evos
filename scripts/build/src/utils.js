"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.get_signer = exports.get_balance = exports.load_account = exports.generate_account = void 0;
const sui_js_1 = require("@mysten/sui.js");
const fs_1 = require("fs");
function generate_account() {
    return sui_js_1.Ed25519Keypair.generate();
}
exports.generate_account = generate_account;
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
exports.load_account = load_account;
async function get_balance(account, provider) {
    return await provider.getBalance({ owner: account, coinType: '0x2::sui::SUI' });
}
exports.get_balance = get_balance;
function get_signer(account, connection) {
    if (!connection)
        connection = new sui_js_1.Connection({ fullnode: "https://fullnode.mainnet.sui.io:443" });
    return new sui_js_1.RawSigner(account, new sui_js_1.JsonRpcProvider(connection));
}
exports.get_signer = get_signer;
