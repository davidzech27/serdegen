import gleam/list
import gleam/result
import gleam/string
import simplifile

import internal/error

pub type TypeFile {
  TypeFile(path: String, contents: String)
}

pub fn get_type_files(type_path: String) {
  case simplifile.is_file(type_path), simplifile.is_directory(type_path) {
    Ok(True), Ok(False) ->
      case string.ends_with(type_path, ".gleam") {
        True ->
          case simplifile.read(type_path) {
            Ok(type_contents) -> Ok([TypeFile(type_path, type_contents)])
            Error(file_error) -> Error(error.FileError(file_error))
          }
        False -> Error(error.UsageError(type_path <> "is not a Gleam file."))
      }
    Ok(False), Ok(True) ->
      case
        get_files_in_directory(type_path)
        |> list.filter(string.ends_with(_, ".gleam"))
      {
        [] ->
          Error(error.UsageError(
            "No Gleam files found in directory " <> type_path,
          ))
        files ->
          files
          |> list.map(fn(type_path) {
            case simplifile.read(type_path) {
              Ok(type_contents) -> Ok(TypeFile(type_path, type_contents))
              Error(error) -> Error(error.FileError(error))
            }
          })
          |> error.collect_multi_error
      }
    Ok(False), Ok(False) ->
      Error(error.UsageError(type_path <> " is not a file or directory."))
    Error(file_error), _ | _, Error(file_error) ->
      Error(error.FileError(file_error))
    Ok(True), Ok(True) -> panic
  }
}

fn get_files_in_directory(directory: String) {
  let entries =
    simplifile.read_directory(directory)
    |> result.unwrap(or: [])
    |> list.map(string.append(directory <> "/", _))

  list.append(
    entries
      |> list.filter(fn(entry) {
        simplifile.is_file(entry) |> result.unwrap(or: False)
      }),
    entries
      |> list.filter(fn(entry) {
        simplifile.is_directory(entry) |> result.unwrap(or: False)
      })
      |> list.map(get_files_in_directory)
      |> list.concat,
  )
}
