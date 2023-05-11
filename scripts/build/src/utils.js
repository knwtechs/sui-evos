"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.load_airdrop_list = exports.load_addresses_from_list = exports.get_signer = exports.get_balance = exports.load_account = exports.generate_account = void 0;
const sui_js_1 = require("@mysten/sui.js");
const rpc_1 = require("./rpc");
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
    const raw = (0, sui_js_1.fromB64)(_t[0]);
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
        connection = (0, rpc_1.get_connection)();
    return new sui_js_1.RawSigner(account, new sui_js_1.JsonRpcProvider(connection));
}
exports.get_signer = get_signer;
function load_addresses_from_list(path) {
    let file = (0, fs_1.readFileSync)(path, 'utf-8');
    return file.split(/\r?\n/).map((line) => {
        return line.trim();
    });
}
exports.load_addresses_from_list = load_addresses_from_list;
function load_airdrop_list(path) {
    let file = (0, fs_1.readFileSync)(path, 'utf-8');
    return file.split(/\r?\n/).map((line) => {
        let d = line.trim().split(" ");
        return {
            address: d[0],
            amount: Number(d[1])
        };
    });
}
exports.load_airdrop_list = load_airdrop_list;
