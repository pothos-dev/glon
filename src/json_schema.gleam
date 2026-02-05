import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}

// --- Internal types ---

type SchemaNode {
  StringNode
  IntegerNode
  NumberNode
  BooleanNode
  ArrayNode(items: SchemaNode)
  NullableNode(inner: SchemaNode)
  ObjectNode(fields: List(ObjectField))
  DescriptionNode(inner: SchemaNode, description: String)
}

type ObjectField {
  ObjectField(name: String, schema: SchemaNode, required: Bool)
}

// --- Public type ---

pub opaque type JsonSchema(t) {
  JsonSchema(node: SchemaNode, decoder: decode.Decoder(t))
}

// --- FFI ---

@external(erlang, "json_schema_ffi", "coerce_nil")
@external(javascript, "./json_schema_ffi.mjs", "coerce_nil")
fn coerce_nil() -> a

// --- Primitives ---

pub fn string() -> JsonSchema(String) {
  JsonSchema(node: StringNode, decoder: decode.string)
}

pub fn integer() -> JsonSchema(Int) {
  JsonSchema(node: IntegerNode, decoder: decode.int)
}

pub fn number() -> JsonSchema(Float) {
  JsonSchema(node: NumberNode, decoder: decode.float)
}

pub fn boolean() -> JsonSchema(Bool) {
  JsonSchema(node: BooleanNode, decoder: decode.bool)
}

// --- Composites ---

pub fn array(of inner: JsonSchema(t)) -> JsonSchema(List(t)) {
  JsonSchema(
    node: ArrayNode(items: inner.node),
    decoder: decode.list(inner.decoder),
  )
}

pub fn nullable(inner: JsonSchema(t)) -> JsonSchema(Option(t)) {
  JsonSchema(
    node: NullableNode(inner: inner.node),
    decoder: decode.optional(inner.decoder),
  )
}

// --- Annotation ---

pub fn describe(
  schema: JsonSchema(t),
  description description: String,
) -> JsonSchema(t) {
  JsonSchema(
    node: DescriptionNode(inner: schema.node, description:),
    decoder: schema.decoder,
  )
}

// --- Object building ---

pub fn success(value: t) -> JsonSchema(t) {
  JsonSchema(node: ObjectNode(fields: []), decoder: decode.success(value))
}

pub fn field(
  named name: String,
  of schema: JsonSchema(a),
  next next: fn(a) -> JsonSchema(b),
) -> JsonSchema(b) {
  // Probe continuation for schema structure
  let rest = next(coerce_nil())
  let rest_fields = get_object_fields(rest.node)
  let node =
    ObjectNode(fields: [
      ObjectField(name:, schema: schema.node, required: True),
      ..rest_fields
    ])

  // Build real decoder
  let decoder = {
    use value <- decode.field(name, schema.decoder)
    let result = next(value)
    result.decoder
  }

  JsonSchema(node:, decoder:)
}

pub fn optional(
  named name: String,
  of schema: JsonSchema(a),
  next next: fn(Option(a)) -> JsonSchema(b),
) -> JsonSchema(b) {
  // Probe continuation for schema structure
  let rest = next(coerce_nil())
  let rest_fields = get_object_fields(rest.node)
  let node =
    ObjectNode(fields: [
      ObjectField(name:, schema: schema.node, required: False),
      ..rest_fields
    ])

  // Build decoder: absent field -> None, present -> Some(value)
  let decoder = {
    use value <- decode.optional_field(
      name,
      option.None,
      decode.optional(schema.decoder),
    )
    let result = next(value)
    result.decoder
  }

  JsonSchema(node:, decoder:)
}

pub fn optional_or_null(
  named name: String,
  of schema: JsonSchema(a),
  next next: fn(Option(a)) -> JsonSchema(b),
) -> JsonSchema(b) {
  // Probe continuation for schema structure
  let rest = next(coerce_nil())
  let rest_fields = get_object_fields(rest.node)
  let node =
    ObjectNode(fields: [
      ObjectField(
        name:,
        schema: NullableNode(inner: schema.node),
        required: False,
      ),
      ..rest_fields
    ])

  // Build decoder: absent OR null -> None, present -> Some(value)
  let decoder = {
    use value <- decode.optional_field(
      name,
      option.None,
      decode.optional(schema.decoder),
    )
    let result = next(value)
    result.decoder
  }

  JsonSchema(node:, decoder:)
}

// --- Operations ---

pub fn to_json(schema: JsonSchema(t)) -> json.Json {
  node_to_json(schema.node)
}

pub fn to_string(schema: JsonSchema(t)) -> String {
  schema
  |> to_json
  |> json.to_string
}

pub fn decode(
  schema: JsonSchema(t),
  from json_string: String,
) -> Result(t, json.DecodeError) {
  json.parse(from: json_string, using: schema.decoder)
}

// --- Internal helpers ---

fn get_object_fields(node: SchemaNode) -> List(ObjectField) {
  case node {
    ObjectNode(fields:) -> fields
    _ -> []
  }
}

/// Convert a schema node to a list of JSON key-value pairs.
/// This allows DescriptionNode and NullableNode to compose by
/// appending/modifying pairs rather than re-parsing JSON.
fn node_to_pairs(node: SchemaNode) -> List(#(String, json.Json)) {
  case node {
    StringNode -> [#("type", json.string("string"))]

    IntegerNode -> [#("type", json.string("integer"))]

    NumberNode -> [#("type", json.string("number"))]

    BooleanNode -> [#("type", json.string("boolean"))]

    ArrayNode(items:) -> [
      #("type", json.string("array")),
      #("items", node_to_json(items)),
    ]

    NullableNode(inner:) ->
      case get_type_name(inner) {
        Ok(type_name) -> {
          // Simple inner type: replace "type" with array ["<type>", "null"]
          let null_type =
            json.preprocessed_array([
              json.string(type_name),
              json.string("null"),
            ])
          let inner_pairs = node_to_pairs(inner)
          inner_pairs
          |> list.filter(fn(pair) { pair.0 != "type" })
          |> list.prepend(#("type", null_type))
        }
        Error(Nil) -> [
          #(
            "anyOf",
            json.preprocessed_array([
              node_to_json(inner),
              json.object([#("type", json.string("null"))]),
            ]),
          ),
        ]
      }

    ObjectNode(fields:) -> {
      let properties =
        list.map(fields, fn(f) { #(f.name, node_to_json(f.schema)) })
      let required =
        fields
        |> list.filter(fn(f) { f.required })
        |> list.map(fn(f) { json.string(f.name) })
      case required {
        [] -> [
          #("type", json.string("object")),
          #("properties", json.object(properties)),
        ]
        _ -> [
          #("type", json.string("object")),
          #("properties", json.object(properties)),
          #("required", json.preprocessed_array(required)),
        ]
      }
    }

    DescriptionNode(inner:, description:) ->
      list.append(node_to_pairs(inner), [
        #("description", json.string(description)),
      ])
  }
}

fn node_to_json(node: SchemaNode) -> json.Json {
  node
  |> node_to_pairs
  |> json.object
}

fn get_type_name(node: SchemaNode) -> Result(String, Nil) {
  case node {
    StringNode -> Ok("string")
    IntegerNode -> Ok("integer")
    NumberNode -> Ok("number")
    BooleanNode -> Ok("boolean")
    ArrayNode(..) -> Ok("array")
    ObjectNode(..) -> Ok("object")
    DescriptionNode(inner:, ..) -> get_type_name(inner)
    NullableNode(..) -> Error(Nil)
  }
}
