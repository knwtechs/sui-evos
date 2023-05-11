"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.get_connection_with_url = exports.get_connection = exports.get_random_rpc = exports.RPC_MAINNET_URLS = void 0;
const sui_js_1 = require("@mysten/sui.js");
exports.RPC_MAINNET_URLS = [
    "https://sui-mainnet-rpc.allthatnode.com/",
    "https://fullnode.mainnet.sui.io:443"
];
const get_random_rpc = () => exports.RPC_MAINNET_URLS[Math.floor(Math.random() * exports.RPC_MAINNET_URLS.length)];
exports.get_random_rpc = get_random_rpc;
const get_connection = () => new sui_js_1.Connection({ fullnode: (0, exports.get_random_rpc)() });
exports.get_connection = get_connection;
const get_connection_with_url = (url) => new sui_js_1.Connection({ fullnode: url });
exports.get_connection_with_url = get_connection_with_url;
