import argv
import filespy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

import internal/codegen
import internal/error
import internal/file

pub fn generate(type_paths: List(String)) {
  use type_files <- result.try(
    type_paths
    |> list.map(file.read_files(_, with_extension: ".gleam"))
    |> error.collect_multi_error
    |> result.map(list.flatten),
  )

  type_files
  |> list.map(codegen.generate_json)
  |> error.collect_multi_error
  |> result.map(list.filter(_, fn(generated_file: file.File) {
    generated_file.contents
    |> string.split("\n")
    |> list.filter(fn(line) { !{ line |> string.trim |> string.is_empty } })
    |> list.length
    > 2
  }))
}

pub fn watch(type_paths: List(String)) {
  case
    generate(type_paths)
    |> result.try(fn(generated_files) {
      generated_files
      |> list.map(file.write_file)
      |> error.collect_multi_error
    })
  {
    Ok(generated_files) ->
      io.println(
        int.to_string(list.length(generated_files))
        <> " JSON modules generated.",
      )
    Error(error) -> io.println_error(error.format_error(error))
  }

  filespy.new()
  |> filespy.add_dirs(
    type_paths
    |> list.map(fn(type_path) {
      file.get_absolute_path(type_path) |> result.unwrap(or: type_path)
    }),
  )
  |> filespy.set_handler(fn(type_path, _) {
    let type_path =
      file.get_relative_path(type_path) |> result.unwrap(or: type_path)

    case
      generate([type_path])
      |> result.try(fn(generated_files) {
        generated_files
        |> list.map(file.write_file)
        |> error.collect_multi_error
      })
    {
      Ok(generated_nils) ->
        case generated_nils {
          [_] -> io.println(type_path <> " JSON module updated.")
          _ -> Nil
        }
      Error(error) -> io.println_error(error.format_error(error))
    }
  })
  |> filespy.start()
  |> result.lazy_unwrap(fn() { panic as "Filesystem watcher failed to start." })

  process.sleep_forever()
}

pub fn main() {
  case argv.load().arguments {
    [] ->
      io.println_error(
        error.format_error(error.UsageError(
          "Pass in type file/directory paths as arguments. Use the --watch/-w option to update generated modules in real time, or --dry-run to print generated modules to stdout.",
        )),
      )
    ["--watch", ..type_paths] | ["-w", ..type_paths] -> watch(type_paths)
    ["--dry-run", ..type_paths] ->
      case generate(type_paths) {
        Ok(generated_files) -> {
          generated_files
          |> list.map(fn(generated_file) {
            io.println(generated_file.path)
            io.println("")
            io.println(generated_file.contents)
            io.println("")
          })

          Nil
        }
        Error(error) -> io.println_error(error.format_error(error))
      }
    type_paths ->
      case
        generate(type_paths)
        |> result.try(fn(generated_files) {
          generated_files
          |> list.map(file.write_file)
          |> error.collect_multi_error
        })
      {
        Ok(generated_files) ->
          io.println(
            int.to_string(list.length(generated_files))
            <> " JSON modules generated.",
          )
        Error(error) -> io.println_error(error.format_error(error))
      }
  }
}
