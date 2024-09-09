// GENERATED CODE

import gleam/dict
import gleam/dynamic
import gleam/json
import gleam/list
import gleam/result

import test_files/entities

pub fn serialize_person(person: entities.Person) {
  person_to_json(person)
  |> json.to_string
}

fn person_to_json(person: entities.Person) {
  case person {
    entities.Person(name, age, is_nice, grocery_list, pet) ->
      json.object([
        #("variant", json.string("Person")),
        #("value",
          json.object([
            #("name", json.string(name)),
            #("age", json.int(age)),
            #("is_nice", json.bool(is_nice)),
            #("grocery_list", json.array(grocery_list, fn(element) {
              json.preprocessed_array([
                json.string(element.0),
                json.int(element.1),
              ])
            },)),
            #("pet", json.nullable(pet, fn(pet) {
              pet_to_json(pet)
            })),
          ])
        ),
      ])
    entities.Imaginary(field0) ->
      json.object([
        #("variant", json.string("Imaginary")),
        #("value",
          json.object([
            #("0", json.int(field0)),
          ])
        ),
      ])
    entities.Wizard(level) ->
      json.object([
        #("variant", json.string("Wizard")),
        #("value",
          json.object([
            #("level", json.int(level)),
          ])
        ),
      ])
  }
}

pub fn deserialize_person(person_string: String) {
  json.decode(person_string, person_from_dynamic)
}

fn person_from_dynamic(person_dynamic: dynamic.Dynamic) {
  dynamic.decode2(
    fn(variant, value) {
      case variant {
        "Person" ->
          Ok(dynamic.decode5(
            entities.Person,
            dynamic.field("name", dynamic.string),
            dynamic.field("age", dynamic.int),
            dynamic.field("is_nice", dynamic.bool),
            dynamic.field("grocery_list", dynamic.list(dynamic.tuple2(dynamic.string, dynamic.int))),
            dynamic.field("pet", dynamic.optional(pet_from_dynamic)),
          )(value))
        "Imaginary" ->
          Ok(dynamic.decode1(
            entities.Imaginary,
            dynamic.field("0", dynamic.int),
          )(value))
        "Wizard" ->
          Ok(dynamic.decode1(
            entities.Wizard,
            dynamic.field("level", dynamic.int),
          )(value))
        _ ->
          Error([
            dynamic.DecodeError(
              expected: "Person | Imaginary | Wizard",
              found: variant,
              path: ["variant"],
            ),
          ])
      }
    },
    dynamic.field("variant", dynamic.string),
    dynamic.field("value", dynamic.dynamic),
  )(person_dynamic)
  |> result.flatten
  |> result.flatten
}

pub fn serialize_pet(pet: entities.Pet) {
  pet_to_json(pet)
  |> json.to_string
}

fn pet_to_json(pet: entities.Pet) {
  json.object([
    #("name", json.string(pet.name)),
    #("enemy", json.nullable(pet.enemy, fn(enemy) {
      person_to_json(enemy)
    })),
    #("person_rankings", json.object(
      pet.person_rankings |> dict.to_list |> list.map(fn(entry) {
      #(person_to_json(entry.0) |> json.to_string, json.int(entry.1))
      })
    )),
    #("favorite_numbers", json.object(
      pet.favorite_numbers |> dict.to_list |> list.map(fn(entry) {
      #(json.int(entry.0) |> json.to_string, json.float(entry.1))
      })
    )),
    #("vocabulary_frequency", json.object(
      pet.vocabulary_frequency |> dict.to_list |> list.map(fn(entry) {
      #(entry.0, json.float(entry.1))
      })
    )),
  ])
}

pub fn deserialize_pet(pet_string: String) {
  json.decode(pet_string, pet_from_dynamic)
}

fn pet_from_dynamic(pet_dynamic: dynamic.Dynamic) {
  dynamic.decode5(
    entities.Pet,
    dynamic.field("name", dynamic.string),
    dynamic.field("enemy", dynamic.optional(person_from_dynamic)),
    dynamic.field("person_rankings", dynamic.dict(
      fn(key) {
        dynamic.string(key)
        |> result.try(fn(key) {
          deserialize_person(key)
          |> result.map_error(json_decode_error_to_dynamic_decode_error)
        })
      },
      dynamic.int,
    )),
    dynamic.field("favorite_numbers", dynamic.dict(
      fn(key) {
        dynamic.string(key)
        |> result.try(fn(key) {
          json.decode(key, dynamic.int)
          |> result.map_error(json_decode_error_to_dynamic_decode_error)
        })
      },
      dynamic.float,
    )),
    dynamic.field("vocabulary_frequency", dynamic.dict(dynamic.string, dynamic.float)),
  )(pet_dynamic)
}

fn json_decode_error_to_dynamic_decode_error(decode_error) {
  case decode_error {
    json.UnexpectedFormat(decode_errors) -> decode_errors
    json.UnexpectedEndOfInput -> [
      dynamic.DecodeError(
        expected: "Valid JSON",
        found: "End of input",
        path: [],
      ),
    ]
    json.UnexpectedByte(unexpected_byte) -> [
      dynamic.DecodeError(
        expected: "Valid JSON character",
        found: unexpected_byte,
        path: [],
      ),
    ]
    json.UnexpectedSequence(unexpected_sequence) -> [
      dynamic.DecodeError(
        expected: "Valid JSON sequence",
        found: unexpected_sequence,
        path: [],
      ),
    ]
  }
}