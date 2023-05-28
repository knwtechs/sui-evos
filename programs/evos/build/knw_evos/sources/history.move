/* 
 * Author: kunnow
 * Company: KNW Technologies FZCO
 * License: MIT
 * Description: History for evoscore dynamics.
 * Features:
 *      - Create a new EvosHistory object
 *      - Push & Pop a State from the History
 *      - Push & Pop an open box from the History
 *      - Check if a box has already been opened for an NFT
 *      - Get all the opened boxes for an NFT
 */
module knw_evos::history {
    
    friend knw_evos::evoscore;

    use std::ascii;
    use std::vector;

    use sui::object::{Self, UID, ID};
    use sui::url::{Url};
    use sui::tx_context::{TxContext};
    use sui::vec_map;
    
    use knw_evos::traits::{Self, BoxReceipt};

    struct EvosHistory has key, store {
        id: UID,
        nft_id: ID,
        urls: vector<Url>,
        keys: vector<ascii::String>,
        values: vector<ascii::String>,
        pending_receipts: vector<BoxReceipt>,
        opened_boxes: vector<u16>,
        last_devolution_for_id: vec_map::VecMap<ID, u64>
    }

    const EWrongNFT: u64 = 0;
    const EReceiptNotConfirmed: u64 = 1;
    const ENonePending: u64 = 2;
    const EBoxNotFound: u64 = 3;

    public(friend) fun create_history(nft_id: ID, ctx: &mut TxContext): EvosHistory {
        EvosHistory{
            id: object::new(ctx),
            nft_id,
            urls: vector::empty<Url>(),
            keys: vector::empty<ascii::String>(),
            values: vector::empty<ascii::String>(),
            pending_receipts: vector::empty<BoxReceipt>(),
            opened_boxes: vector::empty<u16>(),
            last_devolution_for_id: vec_map::empty<ID, u64>()
        }
    }
    public(friend) fun last_devolution_check_for_id(history: &EvosHistory, nft_id: ID): u64 {
        if(vec_map::contains(&history.last_devolution_for_id, &nft_id)){
            *vec_map::get(&history.last_devolution_for_id, &nft_id)
        }else{
            0
        }
    }
    public(friend) fun register_devolution_check_for_id(history: &mut EvosHistory, nft_id: ID, value: u64) {
        if(vec_map::contains(&history.last_devolution_for_id, &nft_id)){
            *vec_map::get_mut(&mut history.last_devolution_for_id, &nft_id) = value;
        }else{
            vec_map::insert(&mut history.last_devolution_for_id, nft_id, value);
        };
    }
    public(friend) fun push_state(
        history: &mut EvosHistory,
        nft_id: ID,
        url: Url,
        key: ascii::String,
        value: ascii::String
    ){
        assert!(nft_id == history.nft_id, EWrongNFT);
        vector::push_back(&mut history.urls, url);
        vector::push_back(&mut history.keys, key);
        vector::push_back(&mut history.values, value);
    }
    public(friend) fun pop_state(
        history: &mut EvosHistory,
        nft_id: ID
    ): (Url, ascii::String, ascii::String) /* (url, key, value) */{
        assert!(nft_id == history.nft_id, EWrongNFT);
        (vector::pop_back(&mut history.urls), vector::pop_back(&mut history.keys), vector::pop_back(&mut history.values))
    }

    public(friend) fun register_box_opening(
        history: &mut EvosHistory,
        nft_id: ID,
        box_index: u16
    ) {
        assert!(nft_id == history.nft_id, EWrongNFT);
        vector::push_back<u16>(&mut history.opened_boxes, box_index);
    }
    public(friend) fun box_already_open(
        history: &EvosHistory,
        nft_id: ID,
        box_index: u16
    ): bool {
        assert!(nft_id == history.nft_id, EWrongNFT);
        let i: u64 = 0;
        while(i < vector::length(&history.opened_boxes)){
            if(*vector::borrow<u16>(&history.opened_boxes, i) == box_index){
                return true
            };
            i = i+1;
        };
        return false
    }
    public(friend) fun remove_box_from_opened(
        history: &mut EvosHistory,
        nft_id: ID,
        box_index: u16
    ) {
        assert!(nft_id == history.nft_id, EWrongNFT);
        let i: u64 = 0;
        while(i < vector::length(&history.opened_boxes)){
            if(*vector::borrow<u16>(&history.opened_boxes, i) == box_index){
                break
            };
            i = i+1;
        };
        assert!(i < vector::length(&history.opened_boxes), EBoxNotFound);
        vector::remove(&mut history.opened_boxes, i);
    }
    public(friend) fun opened_boxes(history: &EvosHistory): vector<u16> {
        history.opened_boxes
    }

    public(friend) fun push_pending(
        history: &mut EvosHistory,
        receipt: BoxReceipt,
        _ctx: &mut TxContext
    ) {
        assert!(traits::is_receipt_confirmed(&receipt), EReceiptNotConfirmed);
        vector::push_back(&mut history.pending_receipts, receipt);
    }
    public(friend) fun pop_pending(
        history: &mut EvosHistory,
        ctx: &mut TxContext
    ): BoxReceipt {
        assert!(has_pending(history, ctx), ENonePending);
        vector::pop_back(&mut history.pending_receipts)
    }
    public fun has_pending(
        history: &EvosHistory,
        _ctx: &mut TxContext
    ): bool {
        vector::length(&history.pending_receipts) > 0
    }

}