/* Author: kunnow
 * Company: KNW Technologies FZCO
 * License: MIT
 * Description: TraitsBox management module.
 * Features:
 *      - Create a new TraitSettings object
 *      - Create a new TraitBox object
 *      - Create & Confirm BoxReceipts
 *      - Get a TraitBox by box index
 *      - Get all TraitBox for a given `Stage` name
 */
module knw_evos::traits {

    friend knw_evos::evoscore;

    use std::ascii;
    use std::vector;
    use std::string::{Self, String};

    use sui::tx_context::{TxContext};
    use sui::url::{Self, Url};
    use sui::object::{Self, UID, ID};

    use ob_pseudorandom::pseudorandom;

    struct TraitSettings has key, store{
        id: UID,
        boxes: vector<TraitBox>
    }
    struct TraitBox has store {
        index: u16,
        traits: vector<Trait>,
        stage: String,
        level: u32,
        price: u32
    }
    struct Trait has store, copy, drop {
        name: ascii::String,
        value: ascii::String,
        url: Url,
        weight: u8
    }
    struct BoxReceipt has key, store {
        id: UID,
        nft_id: ID,
        trait: Trait,
        prev_url: Url,
        confirmed: bool
    }

    const ETraitsLengthMismatch: u64 = 0;
    const EBoxNotFound: u64 = 1;
    const EReceiptNotConfirmed: u64 = 2;
    const EZeroBoxes: u64 = 3;

    public(friend) fun new_trait_box(
        index: u16,
        level: u32,
        stage: vector<u8>,
        names: vector<vector<u8>>,
        values: vector<vector<u8>>,
        urls: vector<vector<u8>>,
        weights: vector<u8>,
        price: u32
    ): TraitBox {
        let traits = empty_traits();
        assert!( 
            vector::length(&names) == vector::length(&values) && vector::length(&values) == vector::length(&urls) && vector::length(&urls) == vector::length(&weights),
            ETraitsLengthMismatch
        );
        let i: u64 = 0;
        while(i < vector::length(&names)){
            let name = ascii::string(*vector::borrow<vector<u8>>(&names, i));
            let value = ascii::string(*vector::borrow<vector<u8>>(&values, i));
            let url = url::new_unsafe_from_bytes(*vector::borrow<vector<u8>>(&urls, i));
            let weight = *vector::borrow<u8>(&weights, i);
            vector::push_back(&mut traits, create_trait(name, value, url, weight));
            i = i + 1;
        };
        create_trait_box(index, traits, string::utf8(stage), level, price)
    }
    public(friend) fun create_trait_settings(
        ctx: &mut TxContext
    ): TraitSettings {
        TraitSettings {id: object::new(ctx), boxes: vector::empty<TraitBox>()}
    }
    public(friend) fun create_trait_box(
        index: u16,
        traits: vector<Trait>,
        stage: String,
        level: u32,
        price: u32
    ): TraitBox {
        TraitBox {index, traits, stage, level, price}
    }
    public(friend) fun create_trait(
        name: ascii::String,
        value: ascii::String,
        url: Url,
        weight: u8
    ): Trait {
        Trait {name, value, url, weight}
    }

    public(friend) fun empty_traits(): vector<Trait> {
        vector::empty<Trait>()
    }

    // Trait Settings
    public(friend) fun trait_boxes(settings: &TraitSettings): &vector<TraitBox> {
        &settings.boxes
    }
    public(friend) fun register_box(settings: &mut TraitSettings, box: TraitBox) {
        vector::push_back(&mut settings.boxes, box);
    }
    public(friend) fun new_box_index(settings: &TraitSettings): u16 {
        (vector::length(&settings.boxes) as u16)
    }
    public(friend) fun box_by_index(settings: &TraitSettings, index: u16): &TraitBox {
        assert!((index as u64) < vector::length(&settings.boxes), EBoxNotFound);
        let i: u64 = 0;
        while(i < vector::length(&settings.boxes)){
            if(vector::borrow<TraitBox>(&settings.boxes, i).index == index){
                break
            };
            i = i + 1;
        };
        assert!(i < vector::length(&settings.boxes), EBoxNotFound);
        vector::borrow<TraitBox>(&settings.boxes, i)
    }
    public(friend) fun box_by_stage(
        settings: &TraitSettings,
        stage: &String
    ): vector<u16> {
        assert!(box_count(settings) > 0, EZeroBoxes);
        let r = vector::empty<u16>();
        let i: u16 = 0;
        while((i as u64) < box_count(settings)){
            let s = vector::borrow<TraitBox>(&settings.boxes, (i as u64));
            if(string::index_of(&s.stage, stage) == 0){
                vector::push_back(&mut r, s.index);
            };
            i = i+1;
        };
        assert!(vector::length(&r) > 0, EBoxNotFound);
        r
    }
    public(friend) fun box_count(settings: &TraitSettings): u64 {
        vector::length(&settings.boxes)
    }
    
    // TraitBox
    public(friend) fun traitbox_index(box: &TraitBox): u16 {
        box.index
    }
    public(friend) fun traitbox_traits(box: &TraitBox): &vector<Trait> {
        &box.traits
    }
    public(friend) fun traitbox_stage(box: &TraitBox): String {
        box.stage
    }
    public(friend) fun traitbox_level(box: &TraitBox): u32 {
        box.level
    }
    public(friend) fun traitbox_price(box: &TraitBox): u32 {
        box.price
    }
    public(friend) fun get_random_trait(
        box: &TraitBox,
        ctx: &mut TxContext
    ): &Trait {

        let traits = traitbox_traits(box);
        let tot_weight: u8 = 0;
        let j: u64 = 0;
        while(j < vector::length(traits)){
            tot_weight = tot_weight + vector::borrow(traits, j).weight;
            j = j+1;
        };

        let nonce = vector::empty();
        vector::append(&mut nonce, sui::bcs::to_bytes(&box.index));
        let contract_commitment = pseudorandom::rand_no_counter(nonce, ctx);
        let rng = knw_evos::utils::select((tot_weight as u64), &contract_commitment);
        
        let cumulativeWeight: u8 = 0;
        let i: u64 = 0;
        while (vector::length(traits) > i) {
            let trait = vector::borrow<Trait>(traits, i);
            cumulativeWeight = cumulativeWeight + trait.weight;
            if (rng <= (cumulativeWeight as u64)) {
                return trait
            };
            i = i+1;
        };
        vector::borrow<Trait>(traits, vector::length(traits) - 1)
    }

    // Trait
    public fun trait_name(trait: &Trait): ascii::String {
        trait.name
    }
    public fun trait_value(trait: &Trait): ascii::String {
        trait.value
    }
    public fun trait_url(trait: &Trait): Url {
        trait.url
    }

    // BoxReceipt
    public(friend) fun new_receipt(trait: Trait, nft_id: ID, prev_url: Url, ctx: &mut TxContext): BoxReceipt {
        BoxReceipt {
            id: object::new(ctx),
            nft_id,
            trait,
            confirmed: false,
            prev_url
        }
    }
    public fun is_receipt_confirmed(receipt: &BoxReceipt): bool {
        receipt.confirmed
    }
    public fun receipt_nft(receipt: &BoxReceipt): ID {
        receipt.nft_id
    }
    public(friend) fun receipt_prev_url(receipt: &BoxReceipt): Url {
        receipt.prev_url
    }
    public(friend) fun receipt_trait(receipt: &BoxReceipt): &Trait {
        &receipt.trait
    }
    public(friend) fun confirm_receipt(receipt: &mut BoxReceipt) {
        receipt.confirmed = true
    }
    public(friend) fun burn_receipt(receipt: BoxReceipt) {
        assert!(is_receipt_confirmed(&receipt), EReceiptNotConfirmed);
        let BoxReceipt {id, nft_id: _, trait: _, prev_url: _, confirmed: _} = receipt;
        object::delete(id);
    }
    
}