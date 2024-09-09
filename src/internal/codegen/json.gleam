import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string

import internal/codegen/parse

pub fn generate(
  type_definitions: List(parse.TypeDefinition),
  type_module: String,
) {
  let type_module_ending =
    type_module
    |> string.split("/")
    |> list.last
    |> result.lazy_unwrap(fn() {
      panic as "Split string must have a last element."
    })

  let referenced_custom_type_name_set =
    type_definitions
    |> list.flat_map(fn(type_definition) {
      type_definition.variants
      |> list.flat_map(fn(variant) {
        variant.fields
        |> list.flat_map(fn(field) {
          referenced_custom_type_names(field.type_reference)
        })
      })
    })
    |> set.from_list

  let root_type_definitions =
    type_definitions
    |> list.filter(fn(type_definition) {
      !set.contains(referenced_custom_type_name_set, type_definition.name)
    })

  let function_definitions =
    type_definitions
    |> list.flat_map(fn(type_definition) {
      let root = case root_type_definitions {
        [root_type_definition] if root_type_definition == type_definition ->
          True
        _ -> False
      }

      [
        format_function_definition(
          format_function_name(type_definition.name, Serialize, root: root),
          option.Some(
            type_definition.name |> string.lowercase
            <> ": "
            <> type_module_ending
            <> "."
            <> type_definition.name,
          ),
          format_lines(
            [
              format_function_name(type_definition.name, ToJson, root: root)
                <> "("
                <> type_definition.name |> string.lowercase
                <> ")",
              "|> json.to_string",
            ],
            indent: False,
          ),
          public: True,
        ),
        format_function_definition(
          format_function_name(type_definition.name, ToJson, root: root),
          option.Some(
            type_definition.name |> string.lowercase
            <> ": "
            <> type_module_ending
            <> "."
            <> type_definition.name,
          ),
          format_lines(
            [
              format_type_definition_to_json(
                type_definition,
                type_definition.name |> string.lowercase,
                type_module_ending,
              ),
            ],
            indent: False,
          ),
          public: False,
        ),
        format_function_definition(
          format_function_name(type_definition.name, Deserialize, root: root),
          option.Some(
            type_definition.name |> string.lowercase <> "_string: String",
          ),
          "json.decode("
            <> type_definition.name |> string.lowercase
            <> "_string, "
            <> format_function_name(
            type_definition.name,
            FromDynamic,
            root: root,
          )
            <> ")",
          public: True,
        ),
        format_function_definition(
          format_function_name(type_definition.name, FromDynamic, root: root),
          option.Some(
            type_definition.name |> string.lowercase
            <> "_dynamic: "
            <> "dynamic.Dynamic",
          ),
          format_type_definition_from_dynamic(
            type_definition,
            type_definition.name |> string.lowercase <> "_dynamic",
            type_module_ending,
          ),
          public: False,
        ),
      ]
    })

  let function_definitions = {
    case
      list.any(function_definitions, string.contains(
        _,
        json_decode_error_to_dynamic_decode_error_function_name,
      ))
    {
      True ->
        function_definitions
        |> list.append([json_decode_error_to_dynamic_decode_error_function])
      False -> function_definitions
    }
  }

  let header = "// GENERATED CODE"

  let imports =
    [
      "dict", "dynamic", "float", "int", "json", "list", "option", "result",
      "string",
    ]
    |> list.filter_map(fn(module) {
      case
        function_definitions
        |> string.concat
        |> string.contains(module <> ".")
      {
        True -> Ok("import gleam/" <> module)
        False -> Error(Nil)
      }
    })
    |> string.join("\n")

  let type_import = "import " <> type_module

  Ok(string.join([header, imports, type_import, ..function_definitions], "\n\n"))
}

fn referenced_custom_type_names(type_reference: parse.TypeReference) {
  case type_reference {
    parse.StringReference -> []
    parse.IntReference -> []
    parse.FloatReference -> []
    parse.BoolReference -> []
    parse.OptionReference(inner_type_reference) ->
      referenced_custom_type_names(inner_type_reference)
    parse.ListReference(inner_type_reference) ->
      referenced_custom_type_names(inner_type_reference)
    parse.TupleReference(inner_type_references) ->
      inner_type_references |> list.flat_map(referenced_custom_type_names)
    parse.DictReference(key_type_reference, value_type_reference) ->
      list.append(
        referenced_custom_type_names(key_type_reference),
        referenced_custom_type_names(value_type_reference),
      )
    parse.CustomReference(name) -> [name]
  }
}

fn format_type_definition_to_json(
  type_definition: parse.TypeDefinition,
  variable_name: String,
  type_module_ending: String,
) {
  let unnamed_fields =
    list.any(type_definition.variants, fn(variant) {
      list.any(variant.fields, fn(field) { field.name |> option.is_none })
    })

  case type_definition.variants {
    [variant] if !unnamed_fields ->
      format_variant_to_json(variant, option.Some(variable_name))
    variants ->
      format_lines(
        [
          "case " <> variable_name <> " {",
          format_lines(
            variants
              |> list.map(fn(variant) {
                format_lines(
                  [
                    type_module_ending
                      <> "."
                      <> variant.name
                      <> case list.length(variant.fields) {
                      0 -> ""
                      _ ->
                        "("
                        <> variant.fields
                        |> list.index_map(fn(field, index) {
                          format_field_variable_name(
                            option.None,
                            field.name,
                            index,
                          )
                        })
                        |> string.join(", ")
                        <> ")"
                    }
                      <> " ->",
                    format_lines(
                      [
                        "json.object([",
                        format_lines(
                          [
                            "#(\"variant\", json.string(\""
                              <> variant.name
                              <> "\")),",
                            "#(\"value\",",
                            format_lines(
                              [format_variant_to_json(variant, option.None)],
                              indent: True,
                            ),
                            "),",
                          ],
                          indent: True,
                        ),
                        "])",
                      ],
                      indent: True,
                    ),
                  ],
                  indent: False,
                )
              }),
            indent: True,
          ),
          "}",
        ],
        indent: False,
      )
  }
}

fn format_variant_to_json(
  variant: parse.Variant,
  variable_name: option.Option(String),
) {
  case variant.fields {
    [] -> "json.null()"
    fields ->
      format_lines(
        [
          "json.object([",
          format_lines(
            fields
              |> list.index_map(fn(field, index) {
                "#(\""
                <> format_field_name(field.name, index)
                <> "\", "
                <> format_type_reference_to_json(
                  field.type_reference,
                  format_field_variable_name(variable_name, field.name, index),
                )
                <> "),"
              }),
            indent: True,
          ),
          "])",
        ],
        indent: False,
      )
  }
}

fn format_type_reference_to_json(
  type_reference: parse.TypeReference,
  variable_name: String,
) {
  case type_reference {
    parse.StringReference -> "json.string(" <> variable_name <> ")"
    parse.IntReference -> "json.int(" <> variable_name <> ")"
    parse.FloatReference -> "json.float(" <> variable_name <> ")"
    parse.BoolReference -> "json.bool(" <> variable_name <> ")"
    parse.OptionReference(inner_type_reference) ->
      "json.nullable("
      <> variable_name
      <> ", "
      <> format_lines(
        [
          "fn(" <> format_parameter_name(variable_name) <> ") {",
          format_lines(
            [
              format_type_reference_to_json(
                inner_type_reference,
                format_parameter_name(variable_name),
              ),
            ],
            indent: True,
          ),
          "}",
        ],
        indent: False,
      )
      <> ")"
    parse.ListReference(inner_type_reference) ->
      "json.array("
      <> variable_name
      <> ", "
      <> format_lines(
        [
          "fn(element) {",
          format_lines(
            [format_type_reference_to_json(inner_type_reference, "element")],
            indent: True,
          ),
          "},",
        ],
        indent: False,
      )
      <> ")"
    parse.TupleReference(inner_type_references) ->
      format_lines(
        [
          "json.preprocessed_array([",
          format_lines(
            inner_type_references
              |> list.index_map(fn(inner_type_reference, index) {
                format_type_reference_to_json(
                  inner_type_reference,
                  variable_name <> "." <> int.to_string(index),
                )
                <> ","
              }),
            indent: True,
          ),
          "])",
        ],
        indent: False,
      )
    parse.DictReference(key_type_reference, value_type_reference) ->
      format_lines(
        [
          "json.object(",
          format_lines(
            [
              variable_name <> " |> dict.to_list |> list.map(fn(entry) {",
              "#("
                <> case key_type_reference {
                parse.StringReference -> "entry.0"
                _ ->
                  format_type_reference_to_json(key_type_reference, "entry.0")
                  <> " |> json.to_string"
              }
                <> ", "
                <> format_type_reference_to_json(
                value_type_reference,
                "entry.1",
              )
                <> ")",
              "})",
            ],
            indent: True,
          ),
          ")",
        ],
        indent: False,
      )
    parse.CustomReference(name) ->
      format_function_name(name, ToJson, root: False)
      <> "("
      <> variable_name
      <> ")"
  }
}

fn format_type_definition_from_dynamic(
  type_definition: parse.TypeDefinition,
  variable_name: String,
  type_module_ending: String,
) {
  case type_definition.variants {
    [variant] ->
      format_variant_from_dynamic(variant, variable_name, type_module_ending)
    variants ->
      format_lines(
        [
          "dynamic.decode2(",
          format_lines(
            [
              "fn(variant, value) {",
              format_lines(
                [
                  "case variant {",
                  format_lines(
                    [
                      format_lines(
                        variants
                          |> list.map(fn(variant) {
                            format_lines(
                              [
                                "\"" <> variant.name <> "\" ->",
                                format_lines(
                                  [
                                    "Ok("
                                    <> format_variant_from_dynamic(
                                      variant,
                                      "value",
                                      type_module_ending,
                                    )
                                    <> ")",
                                  ],
                                  indent: True,
                                ),
                              ],
                              indent: False,
                            )
                          }),
                        indent: False,
                      ),
                      format_lines(
                        [
                          "_ ->",
                          format_lines(
                            [
                              "Error([",
                              format_lines(
                                [
                                  "dynamic.DecodeError(",
                                  format_lines(
                                    [
                                      "expected: \""
                                        <> variants
                                      |> list.map(fn(variant) { variant.name })
                                      |> string.join(" | ")
                                        <> "\",",
                                      "found: variant,",
                                      "path: [\"variant\"],",
                                    ],
                                    indent: True,
                                  ),
                                  "),",
                                ],
                                indent: True,
                              ),
                              "])",
                            ],
                            indent: True,
                          ),
                        ],
                        indent: False,
                      ),
                    ],
                    indent: True,
                  ),
                  "}",
                ],
                indent: True,
              ),
              "},",
              "dynamic.field(\"variant\", dynamic.string),",
              "dynamic.field(\"value\", dynamic.dynamic),",
            ],
            indent: True,
          ),
          ")(" <> variable_name <> ")",
          "|> result.flatten",
          "|> result.flatten",
        ],
        indent: False,
      )
  }
}

fn format_variant_from_dynamic(
  variant: parse.Variant,
  variable_name: String,
  type_module_ending: String,
) {
  case list.length(variant.fields) {
    0 -> "Ok(" <> type_module_ending <> "." <> variant.name <> ")"
    _ ->
      format_lines(
        [
          "dynamic.decode" <> int.to_string(list.length(variant.fields)) <> "(",
          format_lines(
            [
              type_module_ending <> "." <> variant.name <> ",",
              format_lines(
                variant.fields
                  |> list.index_map(fn(field, index) {
                    "dynamic.field(\""
                    <> format_field_name(field.name, index)
                    <> "\", "
                    <> format_type_reference_from_dynamic(field.type_reference)
                    <> "),"
                  }),
                indent: False,
              ),
            ],
            indent: True,
          ),
          ")(" <> variable_name <> ")",
        ],
        indent: False,
      )
  }
}

fn format_type_reference_from_dynamic(type_reference: parse.TypeReference) {
  case type_reference {
    parse.StringReference -> "dynamic.string"
    parse.IntReference -> "dynamic.int"
    parse.FloatReference -> "dynamic.float"
    parse.BoolReference -> "dynamic.bool"
    parse.OptionReference(inner_type_reference) ->
      "dynamic.optional("
      <> format_type_reference_from_dynamic(inner_type_reference)
      <> ")"
    parse.ListReference(inner_type_reference) ->
      "dynamic.list("
      <> format_type_reference_from_dynamic(inner_type_reference)
      <> ")"
    parse.TupleReference(inner_type_references) ->
      "dynamic.tuple"
      <> int.to_string(list.length(inner_type_references))
      <> "("
      <> inner_type_references
      |> list.map(format_type_reference_from_dynamic)
      |> string.join(", ")
      <> ")"
    parse.DictReference(key_type_reference, value_type_reference) ->
      case key_type_reference {
        parse.StringReference ->
          "dynamic.dict(dynamic.string, "
          <> format_type_reference_from_dynamic(value_type_reference)
          <> ")"
        _ ->
          format_lines(
            [
              "dynamic.dict(",
              format_lines(
                [
                  "fn(key) {",
                  format_lines(
                    [
                      "dynamic.string(key)",
                      "|> result.try(fn(key) {",
                      format_lines(
                        [
                          case key_type_reference {
                            parse.CustomReference(name) ->
                              format_function_name(
                                name,
                                Deserialize,
                                root: False,
                              )
                              <> "(key)"
                            _ ->
                              "json.decode(key, "
                              <> format_type_reference_from_dynamic(
                                key_type_reference,
                              )
                              <> ")"
                          },
                          "|> result.map_error("
                            <> json_decode_error_to_dynamic_decode_error_function_name
                            <> ")",
                        ],
                        indent: True,
                      ),
                      "})",
                    ],
                    indent: True,
                  ),
                  "},",
                  format_type_reference_from_dynamic(value_type_reference)
                    <> ",",
                ],
                indent: True,
              ),
              ")",
            ],
            indent: False,
          )
      }
    parse.CustomReference(name) ->
      format_function_name(name, FromDynamic, root: False)
  }
}

const json_decode_error_to_dynamic_decode_error_function_name = "json_decode_error_to_dynamic_decode_error"

const json_decode_error_to_dynamic_decode_error_function = "fn "
  <> json_decode_error_to_dynamic_decode_error_function_name
  <> "(decode_error) {
  case decode_error {
    json.UnexpectedFormat(decode_errors) -> decode_errors
    json.UnexpectedEndOfInput -> [
      dynamic.DecodeError(
        expected: \"Valid JSON\",
        found: \"End of input\",
        path: [],
      ),
    ]
    json.UnexpectedByte(unexpected_byte) -> [
      dynamic.DecodeError(
        expected: \"Valid JSON character\",
        found: unexpected_byte,
        path: [],
      ),
    ]
    json.UnexpectedSequence(unexpected_sequence) -> [
      dynamic.DecodeError(
        expected: \"Valid JSON sequence\",
        found: unexpected_sequence,
        path: [],
      ),
    ]
  }
}"

fn format_field_name(field_name: option.Option(String), field_index: Int) {
  field_name |> option.unwrap(int.to_string(field_index))
}

fn format_field_variable_name(
  parent_variable_name: option.Option(String),
  field_name: option.Option(String),
  field_index: Int,
) {
  case parent_variable_name {
    option.Some(parent_field_name) ->
      parent_field_name <> "." <> format_field_name(field_name, field_index)
    option.None ->
      field_name |> option.unwrap("field" <> int.to_string(field_index))
  }
}

fn format_parameter_name(variable_name: String) {
  variable_name
  |> string.split(".")
  |> list.last
  |> result.unwrap(or: variable_name)
}

type FunctionType {
  Serialize
  Deserialize
  ToJson
  FromDynamic
}

fn format_function_name(
  type_name: String,
  function_type: FunctionType,
  root root: Bool,
) {
  case function_type, root {
    Serialize, True -> "serialize"
    Deserialize, True -> "deserialize"
    Serialize, False -> "serialize_" <> type_name |> string.lowercase
    Deserialize, False -> "deserialize_" <> type_name |> string.lowercase
    ToJson, True -> "to_json"
    FromDynamic, True -> "from_dynamic"
    ToJson, False -> type_name |> string.lowercase <> "_to_json"
    FromDynamic, False -> type_name |> string.lowercase <> "_from_dynamic"
  }
}

fn format_function_definition(
  name: String,
  parameters: option.Option(String),
  body: String,
  public public: Bool,
) {
  format_lines(
    [
      case public {
        True -> "pub "
        False -> ""
      }
        <> "fn "
        <> name
        <> "("
        <> parameters |> option.unwrap(or: "")
        <> ") {",
      format_lines([body], indent: True),
      "}",
    ],
    indent: False,
  )
}

fn format_lines(lines: List(String), indent indent: Bool) {
  lines
  |> string.join("\n")
  |> string.split("\n")
  |> list.map(fn(line) {
    case indent {
      True -> "  "
      False -> ""
    }
    <> line
  })
  |> string.join("\n")
}
