import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/regex
import gleam/result
import gleam/string

import internal/error
import internal/file

pub type TypeDefinition {
  TypeDefinition(name: String, variants: List(Variant))
}

pub type Variant {
  Variant(name: String, fields: List(#(String, TypeReference)))
}

pub type TypeReference {
  StringReference
  IntReference
  FloatReference
  BoolReference
  OptionReference(TypeReference)
  ListReference(TypeReference)
  TupleReference(List(TypeReference))
  DictReference(TypeReference, TypeReference)
  CustomReference(name: String)
}

pub fn parse_type_file(type_file: file.TypeFile) {
  type_file.contents
  |> regex.scan(
    regex.compile(
      "^pub type ([A-Z][a-zA-Z0-9_]*) {\\s*([^}]+?)\\s*}",
      regex.Options(case_insensitive: False, multi_line: True),
    )
      |> result.lazy_unwrap(fn() { panic }),
    _,
  )
  |> list.map(fn(match) {
    case match.submatches {
      [option.Some(name), option.Some(variants_string)] ->
        parse_variants(variants_string)
        |> result.map(TypeDefinition(name, _))
      _ -> panic
    }
  })
  |> error.collect_multi_error
}

fn parse_variants(variants_string: String) {
  use variant_strings <- result.try(split_variants(variants_string))

  variant_strings
  |> list.map(parse_variant)
  |> error.collect_multi_error
}

fn split_variants(variants_string: String) {
  case do_split_variants(variants_string, [], 0, option.Some(0)) {
    Ok(variant_strings) ->
      Ok(variant_strings |> list.map(string.trim) |> list.reverse)
    Error(error) -> Error(error)
  }
}

fn do_split_variants(
  variants_string: String,
  variant_strings: List(String),
  current_index: Int,
  previous_variant_index: option.Option(Int),
) {
  let current_grapheme = string.slice(variants_string, current_index, length: 1)
  let previous_grapheme =
    string.slice(variants_string, current_index - 1, length: 1)

  case current_grapheme, previous_variant_index {
    "", _ ->
      Ok(case previous_variant_index {
        option.Some(previous_variant_index) -> [
          string.slice(
            variants_string,
            previous_variant_index,
            length: current_index - previous_variant_index,
          ),
          ..variant_strings
        ]
        option.None -> variant_strings
      })
    "(", option.Some(previous_variant_index) ->
      case get_matching_parenthesis_index(variants_string, current_index) {
        Ok(next_matching_parenthesis_index) ->
          do_split_variants(
            variants_string,
            [
              string.slice(
                variants_string,
                previous_variant_index,
                length: next_matching_parenthesis_index
                  + 1
                  - previous_variant_index,
              ),
              ..variant_strings
            ],
            next_matching_parenthesis_index + 1,
            option.None,
          )
        Error(_) ->
          Error(error.ParseError(
            "Unterminating parentheses: " <> variants_string,
          ))
      }
    " ", _ | "\n", _ | "\t", _ ->
      do_split_variants(
        variants_string,
        variant_strings,
        current_index + 1,
        previous_variant_index,
      )
    _, option.Some(previous_variant_index)
      if previous_grapheme == " "
      || previous_grapheme == "\n"
      || previous_grapheme == "\t"
    ->
      do_split_variants(
        variants_string,
        [
          string.slice(
            variants_string,
            previous_variant_index,
            length: current_index - previous_variant_index,
          ),
          ..variant_strings
        ],
        current_index + 1,
        option.Some(current_index),
      )
    _, _ ->
      do_split_variants(
        variants_string,
        variant_strings,
        current_index + 1,
        previous_variant_index |> option.or(option.Some(current_index)),
      )
  }
}

fn parse_variant(variant_string: String) {
  case string.split_once(variant_string, "(") {
    Ok(#(name, fields_string)) ->
      parse_fields(fields_string |> string.drop_right(1) |> string.trim)
      |> result.map(Variant(name |> string.trim_right, _))
    Error(_) -> Ok(Variant(variant_string, fields: []))
  }
}

fn parse_fields(fields_string: String) {
  use field_strings <- result.try(split_fields(fields_string))

  field_strings
  |> list.index_map(parse_field)
  |> error.collect_multi_error
}

fn parse_field(field_string: String, field_index: Int) {
  case string.split_once(field_string, ":") {
    Ok(#(name, type_reference_string)) ->
      parse_type_reference(type_reference_string |> string.trim_left)
      |> result.map(fn(type_reference) {
        #(name |> string.trim_right, type_reference)
      })
    Error(_) ->
      parse_type_reference(field_string)
      |> result.map(fn(type_reference) {
        #(int.to_string(field_index), type_reference)
      })
  }
}

fn parse_type_reference(
  type_reference_string: String,
) -> Result(TypeReference, error.Error) {
  case
    string.split_once(type_reference_string, "(")
    |> result.map(pair.map_second(_, fn(body_string) {
      body_string |> string.drop_right(1) |> string.trim
    }))
  {
    Ok(#(name, body_string)) ->
      case name {
        "Option" | "option.Option" ->
          case split_fields(body_string) {
            Ok([body_string]) ->
              body_string
              |> parse_type_reference
              |> result.map(OptionReference(_))
            Ok(_) ->
              Error(error.ParseError(name <> " takes only 1 type parameter."))
            Error(error) -> Error(error)
          }
        "List" ->
          case split_fields(body_string) {
            Ok([body_string]) ->
              body_string
              |> parse_type_reference
              |> result.map(ListReference(_))
            Ok(_) ->
              Error(error.ParseError(name <> " takes only 1 type parameter."))
            Error(error) -> Error(error)
          }
        "#" ->
          case split_fields(body_string) {
            Ok(body_strings) ->
              body_strings
              |> list.map(parse_type_reference)
              |> error.collect_multi_error
              |> result.map(TupleReference(_))
            Error(error) -> Error(error)
          }
        "Dict" | "dict.Dict" ->
          case split_fields(body_string) {
            Ok([key_body_string, value_body_string]) -> {
              use key_type_reference <- result.try(parse_type_reference(
                key_body_string,
              ))
              use value_type_reference <- result.map(parse_type_reference(
                value_body_string,
              ))
              DictReference(key_type_reference, value_type_reference)
            }
            Ok(_) ->
              Error(error.ParseError(name <> " takes only 2 type parameters."))
            Error(error) -> Error(error)
          }
        _ ->
          Error(error.ParseError(
            "Generics in type definitions are not yet supported."
            <> #(name, body_string) |> string.inspect,
          ))
      }
    Error(_) ->
      case type_reference_string {
        "String" -> Ok(StringReference)
        "Int" -> Ok(IntReference)
        "Float" -> Ok(FloatReference)
        "Bool" -> Ok(BoolReference)
        _ -> Ok(CustomReference(type_reference_string))
      }
  }
}

fn split_fields(fields_string: String) {
  case do_split_fields(fields_string, [], 0, option.Some(0)) {
    Ok(field_strings) ->
      Ok(field_strings |> list.map(string.trim) |> list.reverse)
    Error(error) -> Error(error)
  }
}

fn do_split_fields(
  fields_string: String,
  field_strings: List(String),
  current_index: Int,
  previous_field_index: option.Option(Int),
) {
  let current_grapheme = string.slice(fields_string, current_index, length: 1)

  case current_grapheme, previous_field_index {
    "", _ ->
      Ok(case previous_field_index {
        option.Some(previous_field_index) -> [
          string.slice(
            fields_string,
            previous_field_index,
            length: current_index - previous_field_index,
          ),
          ..field_strings
        ]
        option.None -> field_strings
      })
    "(", option.Some(_) ->
      case get_matching_parenthesis_index(fields_string, current_index) {
        Ok(next_matching_parenthesis_index) ->
          do_split_fields(
            fields_string,
            field_strings,
            next_matching_parenthesis_index + 1,
            previous_field_index,
          )
        Error(_) ->
          Error(error.ParseError("Unterminating parentheses: " <> fields_string))
      }
    ",", option.Some(previous_field_index) ->
      do_split_fields(
        fields_string,
        [
          string.slice(
            fields_string,
            previous_field_index,
            length: current_index - previous_field_index,
          ),
          ..field_strings
        ],
        current_index + 1,
        option.None,
      )
    " ", _ | "\n", _ | "\t", _ ->
      do_split_fields(
        fields_string,
        field_strings,
        current_index + 1,
        previous_field_index,
      )
    _, _ ->
      do_split_fields(
        fields_string,
        field_strings,
        current_index + 1,
        previous_field_index |> option.or(option.Some(current_index)),
      )
  }
}

fn get_matching_parenthesis_index(string: String, after_index: Int) {
  do_get_matching_parenthesis_index(string, after_index, 0)
}

fn do_get_matching_parenthesis_index(
  s: String,
  after_index: Int,
  opened_parentheses: Int,
) {
  case string.slice(s, at_index: after_index, length: 1) {
    "(" -> {
      do_get_matching_parenthesis_index(
        s,
        after_index + 1,
        opened_parentheses + 1,
      )
    }
    ")" if opened_parentheses > 1 -> {
      do_get_matching_parenthesis_index(
        s,
        after_index + 1,
        opened_parentheses - 1,
      )
    }
    ")" if opened_parentheses == 1 -> Ok(after_index)
    "" -> Error(Nil)
    _ -> {
      do_get_matching_parenthesis_index(s, after_index + 1, opened_parentheses)
    }
  }
}
