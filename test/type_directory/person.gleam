import gleam/option

pub type Person {
  Person(
    name: String,
    age: Int,
    is_nice: Bool,
    grocery_list: List(#(String, Int)),
    pet: option.Option(Pet),
  )
  Imaginary
  Wizard(level: Int)
}

pub type Pet {
  Pet(name: String, enemy: Person)
}
