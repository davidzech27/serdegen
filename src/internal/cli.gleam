import argv
import gleam/io
import gleam/result

import internal/error

pub type Arguments {
  Arguments(type_path: String)
}

pub fn run(function: fn(Arguments) -> Result(String, error.Error)) {
  case parse_arguments() |> result.try(function(_)) {
    Ok(message) -> io.println(message)
    Error(error) -> io.println_error(error.format_error(error))
  }
}

fn parse_arguments() {
  case argv.load().arguments {
    [type_path] -> Ok(Arguments(type_path))
    _ ->
      Error(error.UsageError(
        "Pass in the type file/directory path as the first argument.",
      ))
  }
}
