import gleam/list
import gleam/result

import internal/cli
import internal/file
import internal/parse

pub fn main() {
  use arguments <- cli.run()

  use type_files <- result.try(file.get_type_files(arguments.type_path))

  type_files |> list.map(parse.parse_type_file)

  todo
}
