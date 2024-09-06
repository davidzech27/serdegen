import gleam/list
import gleam/result
import gleam/string
import simplifile

pub type Error {
  UsageError(message: String)
  FileError(file_error: simplifile.FileError)
  ParseError(message: String)
  MultiError(errors: List(Error))
}

pub fn format_error(error: Error) {
  case error {
    UsageError(message) -> "Usage error: " <> message
    FileError(file_error) ->
      "File error: " <> simplifile.describe_error(file_error)
    ParseError(message) -> "Parse error: " <> message
    MultiError(errors) -> errors |> list.map(format_error) |> string.join("\n")
  }
}

pub fn collect_multi_error(results) {
  case result.partition(results) {
    #(values, []) -> Ok(values |> list.reverse)
    #(_, errors) -> Error(MultiError(errors))
  }
}
