import gleam/list
import gleeunit
import gleeunit/should

import internal/file
import internal/parse

pub fn main() {
  gleeunit.main()
}

pub fn parse_test() {
  let type_files = file.get_type_files("./test/type_directory") |> should.be_ok

  type_files
  |> list.map(parse.parse_type_file)
  |> list.map(should.be_ok)
  |> list.flatten
  |> should.equal([
    parse.TypeDefinition("Rock", [
      parse.Variant("Rock", [
        #("size", parse.FloatReference),
        #("name", parse.StringReference),
      ]),
    ]),
    parse.TypeDefinition("Person", [
      parse.Variant("Person", [
        #("name", parse.StringReference),
        #("age", parse.IntReference),
        #("is_nice", parse.BoolReference),
        #(
          "grocery_list",
          parse.ListReference(
            parse.TupleReference([parse.StringReference, parse.IntReference]),
          ),
        ),
        #("pet", parse.OptionReference(parse.CustomReference("Pet"))),
      ]),
      parse.Variant("Imaginary", []),
      parse.Variant("Wizard", [#("level", parse.IntReference)]),
    ]),
    parse.TypeDefinition("Pet", [
      parse.Variant("Pet", [
        #("name", parse.StringReference),
        #("enemy", parse.CustomReference("Person")),
      ]),
    ]),
  ])
}
