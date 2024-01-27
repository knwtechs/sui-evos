import {TransactionBlock} from "@mysten/sui.js";
import {get_signer, load_account} from '../../../genesis/utils';
import {add_new_traitbox} from '../../calls';
import { TRAITS } from "../../traits";
import _ from "lodash";

let account = load_account();
let signer = get_signer(account);
const encoder = new TextEncoder();

// ========= CREATE BOX Baby #1 ========= //
{
  const txblock = new TransactionBlock();
  const stage = encoder.encode("Baby"); // Box for stage
  const level = 1; // Box for level in stage
  const price = 300 // Box price in gems
  const name = "Background" // Box attribute name

  const traits = TRAITS.backgrounds.Baby

  if(_.sum(traits.map(t => t.weight)) != 100){
    console.log("Invalid trait weights, sum must be equal to 100.")
    process.exit(0)
  }

  const names: Uint8Array[] = []
  const values: Uint8Array[] = []
  const urls: Uint8Array[] = []
  const _weights: number[] = []

  for(let trait of traits){
    names.push(encoder.encode(name))
    values.push(encoder.encode(trait.value))
    urls.push(encoder.encode(trait.url))
    _weights.push(trait.weight);
  }

  add_new_traitbox(
    txblock,
    level,
    stage,
    names,
    values,
    urls,
    Uint8Array.from(_weights),
    price,
    signer
  ).then((status) => console.log(`\n\t+ [Box Created] Baby #1: ${status}`));
}

// ========= CREATE BOX Baby #2 ========= //
{
  const txblock = new TransactionBlock();
  const stage = encoder.encode("Baby"); // Box for stage
  const level = 3; // Box for level in stage
  const price = 310 // Box price in gems
  const name = "Head" // Box attribute name

  const traits = TRAITS.heads.Baby

  if(_.sum(traits.map(t => t.weight)) != 100){
    console.log("Invalid trait weights, sum must be equal to 100.")
    process.exit(0)
  }

  const names: Uint8Array[] = []
  const values: Uint8Array[] = []
  const urls: Uint8Array[] = []
  const _weights: number[] = []

  for(let trait of traits){
    names.push(encoder.encode(name))
    values.push(encoder.encode(trait.value))
    urls.push(encoder.encode(trait.url))
    _weights.push(trait.weight);
  }

  add_new_traitbox(
    txblock,
    level,
    stage,
    names,
    values,
    urls,
    Uint8Array.from(_weights),
    price,
    signer
  ).then((status) => console.log(`\n\t+ [Box Created] Baby #2: ${status}`));
}

// ========= CREATE BOX Baby #3 ========= //
{
  const txblock = new TransactionBlock();
  const stage = encoder.encode("Baby"); // Box for stage
  const level = 5; // Box for level in stage
  const price = 480 // Box price in gems
  const name = "Clothes" // Box attribute name

  const traits = TRAITS.clothes.Baby

  if(_.sum(traits.map(t => t.weight)) != 100){
    console.log("Invalid trait weights, sum must be equal to 100.")
    process.exit(0)
  }

  const names: Uint8Array[] = []
  const values: Uint8Array[] = []
  const urls: Uint8Array[] = []
  const _weights: number[] = []

  for(let trait of traits){
    names.push(encoder.encode(name))
    values.push(encoder.encode(trait.value))
    urls.push(encoder.encode(trait.url))
    _weights.push(trait.weight);
  }

  add_new_traitbox(
    txblock,
    level,
    stage,
    names,
    values,
    urls,
    Uint8Array.from(_weights),
    price,
    signer
  ).then((status) => console.log(`\n\t+ [Box Created] Baby #3: ${status}`));
}

// ========= CREATE BOX Juvenile #1 ========= //
{
  const txblock = new TransactionBlock();
  const stage = encoder.encode("Juvenile"); // Box for stage
  const level = 5; // Box for level in stage
  const price = 480 // Box price in gems
  const name = "Weapon" // Box attribute name

  const traits = TRAITS.weapons.Juvenile

  if(_.sum(traits.map(t => t.weight)) != 100){
    console.log("Invalid trait weights, sum must be equal to 100.")
    process.exit(0)
  }

  const names: Uint8Array[] = []
  const values: Uint8Array[] = []
  const urls: Uint8Array[] = []
  const _weights: number[] = []

  for(let trait of traits){
    names.push(encoder.encode(name))
    values.push(encoder.encode(trait.value))
    urls.push(encoder.encode(trait.url))
    _weights.push(trait.weight);
  }

  add_new_traitbox(
    txblock,
    level,
    stage,
    names,
    values,
    urls,
    Uint8Array.from(_weights),
    price,
    signer
  ).then((status) => console.log(`\n\t+ [Box Created] Juvenile #1: ${status}`));
}