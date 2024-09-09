import gleam/list
import gleam/result
import gleam/string

import internal/codegen/json
import internal/codegen/parse
import internal/error
import internal/file

pub fn generate_json(type_file: file.File) {
  use type_definitions <- result.try(parse.parse_type_file(type_file))

  use type_module <- result.try(
    type_file.path
    |> string.replace(".gleam", "")
    |> string.split("/src/")
    |> list.flat_map(string.split(_, "\\src\\"))
    |> list.flat_map(string.split(_, "/test/"))
    |> list.flat_map(string.split(_, "\\test\\"))
    |> list.last
    |> result.map_error(fn(_) {
      error.UsageError("Type files must belong to src or test directories.")
    }),
  )

  let generated_path =
    type_file.path |> string.replace(".gleam", "") <> "_json.gleam"

  use generated_contents <- result.try(json.generate(
    type_definitions,
    type_module,
  ))

  Ok(file.File(generated_path, generated_contents))
}
