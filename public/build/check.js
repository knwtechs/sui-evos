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
const utils_1 = require("./utils");
const config_1 = require("./config");
const fs_1 = require("fs");
const signer = (0, utils_1.get_signer)((0, utils_1.load_account)(1));
const provider = signer.provider;
const recipients_ = (0, utils_1.load_airdrop_list)(config_1.WALLETS_LIST);
const get_objects_by_type = (provider, account, type, pages = 0) => __awaiter(void 0, void 0, void 0, function* () {
    let result = [];
    let eggs = yield provider.getOwnedObjects({ owner: account, options: { showType: true } });
    result.push(...eggs.data.filter((obj) => { var _a; return ((_a = obj.data) === null || _a === void 0 ? void 0 : _a.type) == type; }));
    let current = 1;
    while (eggs.hasNextPage) {
        if (pages > 0 && current >= pages)
            break;
        eggs = yield provider.getOwnedObjects({ owner: account, cursor: eggs.nextCursor, options: { showType: true } });
        result.push(...eggs.data.filter((obj) => { var _a; return ((_a = obj.data) === null || _a === void 0 ? void 0 : _a.type) == type; }));
    }
    return result;
});
const check = () => __awaiter(void 0, void 0, void 0, function* () {
    console.log(`Treasury:`);
    console.log(`\t+ Account: ${yield signer.getAddress()}`);
    const holdings = yield get_objects_by_type(provider, yield signer.getAddress(), config_1.COLLECTION_TYPE);
    console.log(`\t+ ${config_1.COLLECTION_TYPE.split("::")[2]}: ${holdings.length}`);
    const gas = yield provider.getBalance({ owner: yield signer.getAddress(), coinType: '0x2::sui::SUI' });
    console.log(`\t+ Gas: ${(Number(gas.totalBalance) / 1000000000).toFixed(4)} [${gas.coinObjectCount} object(s)]`);
    console.log(`\nAirdrop:`);
    const aidrop_amount = recipients_.map(e => e.amount).reduce((acc, curr) => acc + curr, 0);
    console.log(`\t+ Amount: ${aidrop_amount}`);
    console.log(`\t+ Wallet list: ${(0, fs_1.existsSync)(config_1.WALLETS_LIST) ? 'found' : 'not found'} at ${config_1.WALLETS_LIST}`);
});
check()
    .then(() => console.log("\nDone.\n"));
