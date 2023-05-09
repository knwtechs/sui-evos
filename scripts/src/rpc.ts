import { Connection } from "@mysten/sui.js";
export const RPC_MAINNET_URLS = [
    "https://sui-mainnet-rpc.allthatnode.com",
    "https://fullnode.mainnet.sui.io:443"
]

export const get_random_rpc = () => RPC_MAINNET_URLS[Math.floor(Math.random() * RPC_MAINNET_URLS.length)];
export const get_connection = () => new Connection({fullnode: get_random_rpc()});
export const get_connection_with_url = (url: string) => new Connection({fullnode: url});