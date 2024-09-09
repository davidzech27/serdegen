import gleam/list
import gleam/result
import gleam/string
import simplifile

import internal/error

pub type File {
  File(path: String, contents: String)
}

pub fn get_absolute_path(path: String) {
  case path |> string.slice(0, length: 1) {
    "." ->
      case simplifile.current_directory() {
        Ok(cwd) -> Ok(cwd <> path |> string.drop_left(1))
        Error(file_error) -> Error(error.FileError(file_error))
      }
    _ -> Ok(path)
  }
}

pub fn get_relative_path(path: String) {
  case simplifile.current_directory() {
    Ok(cwd) -> Ok(path |> string.replace(cwd, "."))
    Error(file_error) -> Error(error.FileError(file_error))
  }
}

pub fn read_file(path: String) {
  case simplifile.read(path) {
    Ok(contents) -> Ok(File(path, contents))
    Error(file_error) -> Error(error.FileError(file_error))
  }
}

pub fn read_files(path: String, with_extension extension: String) {
  case simplifile.is_file(path), simplifile.is_directory(path) {
    Ok(True), Ok(False) ->
      case string.ends_with(path, extension) {
        True -> read_file(path) |> result.map(fn(file) { [file] })
        False ->
          Error(error.UsageError(path <> " is not a " <> extension <> " file."))
      }
    Ok(False), Ok(True) ->
      case
        read_files_recursive(path)
        |> list.filter(string.ends_with(_, extension))
      {
        [] ->
          Error(error.UsageError(
            path <> " contains no " <> extension <> " files.",
          ))
        files ->
          files
          |> list.map(read_file)
          |> error.collect_multi_error
      }
    Ok(True), Ok(True) ->
      Error(error.UsageError(path <> " is both a file and a directory."))
    Ok(False), Ok(False) ->
      Error(error.UsageError(path <> " is not a file or directory."))
    Error(file_error), _ | _, Error(file_error) ->
      Error(error.FileError(file_error))
  }
}

fn read_files_recursive(directory: String) {
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
      |> list.map(read_files_recursive)
      |> list.concat,
  )
}

pub fn write_file(file: File) {
  case simplifile.write(file.path, file.contents) {
    Ok(_) -> Ok(Nil)
    Error(file_error) -> Error(error.FileError(file_error))
  }
}
