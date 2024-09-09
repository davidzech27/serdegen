import gleam/dict
import gleam/option

pub type Person {
  Person(
    name: String,
    age: Int,
    is_nice: Bool,
    grocery_list: List(#(String, Int)),
    pet: option.Option(Pet),
  )
  Imaginary(Int)
  Wizard(level: Int)
}

pub type Pet {
  Pet(
    name: String,
    enemy: option.Option(Person),
    person_rankings: dict.Dict(Person, Int),
    favorite_numbers: dict.Dict(Int, Float),
    vocabulary_frequency: dict.Dict(String, Float),
  )
}
