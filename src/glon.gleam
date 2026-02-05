import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/string

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
  EnumNode(values: List(String))
  ConstNode(value: String)
  DefaultNode(inner: SchemaNode, default: json.Json)
  CombinerNode(keyword: CombinerKeyword, variants: List(SchemaNode))
}

type CombinerKeyword {
  OneOf
  AnyOf
}

type ObjectField {
  ObjectField(name: String, schema: SchemaNode, required: Bool)
}

// --- Public type ---

/// A combined JSON Schema and decoder for values of type `t`.
///
/// Each `JsonSchema(t)` carries both a schema definition (for generating
/// JSON Schema output) and a decoder (for parsing JSON into Gleam values),
/// keeping the two in sync by construction.
///
/// Build schemas using the primitive constructors (`string`, `integer`, etc.),
/// composites (`array`, `nullable`), and object builders (`field`, `optional`,
/// etc.), then use `to_json`, `to_string`, or `decode` to consume them.
pub opaque type JsonSchema(t) {
  JsonSchema(node: SchemaNode, decoder: decode.Decoder(t))
}

// --- FFI ---

@external(erlang, "glon_ffi", "coerce_nil")
@external(javascript, "./glon_ffi.mjs", "coerce_nil")
fn coerce_nil() -> a

// --- Primitives ---

/// A schema for JSON strings.
///
/// Produces `{"type": "string"}` and decodes JSON strings into `String`.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.string()
/// glon.to_string(schema)
/// // -> "{\"type\":\"string\"}"
///
/// glon.decode(schema, from: "\"hello\"")
/// // -> Ok("hello")
/// ```
pub fn string() -> JsonSchema(String) {
  JsonSchema(node: StringNode, decoder: decode.string)
}

/// A schema for JSON integers.
///
/// Produces `{"type": "integer"}` and decodes JSON integers into `Int`.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.integer()
/// glon.to_string(schema)
/// // -> "{\"type\":\"integer\"}"
///
/// glon.decode(schema, from: "42")
/// // -> Ok(42)
/// ```
pub fn integer() -> JsonSchema(Int) {
  JsonSchema(node: IntegerNode, decoder: decode.int)
}

/// A schema for JSON numbers (floating point).
///
/// Produces `{"type": "number"}` and decodes JSON numbers into `Float`.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.number()
/// glon.to_string(schema)
/// // -> "{\"type\":\"number\"}"
///
/// glon.decode(schema, from: "3.14")
/// // -> Ok(3.14)
/// ```
pub fn number() -> JsonSchema(Float) {
  JsonSchema(node: NumberNode, decoder: decode.float)
}

/// A schema for JSON booleans.
///
/// Produces `{"type": "boolean"}` and decodes JSON booleans into `Bool`.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.boolean()
/// glon.to_string(schema)
/// // -> "{\"type\":\"boolean\"}"
///
/// glon.decode(schema, from: "true")
/// // -> Ok(True)
/// ```
pub fn boolean() -> JsonSchema(Bool) {
  JsonSchema(node: BooleanNode, decoder: decode.bool)
}

// --- Composites ---

/// A schema for JSON arrays where every element matches the given inner schema.
///
/// Produces `{"type": "array", "items": <inner>}` and decodes JSON arrays
/// into `List(t)`.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.array(of: glon.string())
/// glon.to_string(schema)
/// // -> "{\"type\":\"array\",\"items\":{\"type\":\"string\"}}"
///
/// glon.decode(schema, from: "[\"a\",\"b\"]")
/// // -> Ok(["a", "b"])
/// ```
pub fn array(of inner: JsonSchema(t)) -> JsonSchema(List(t)) {
  JsonSchema(
    node: ArrayNode(items: inner.node),
    decoder: decode.list(inner.decoder),
  )
}

/// A schema for values that may be `null`.
///
/// Wraps an inner schema to also accept JSON `null`. Produces a schema with
/// `"type": ["<inner_type>", "null"]` for simple inner types, or an `anyOf`
/// for complex ones. Decodes into `Option(t)`.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.nullable(glon.string())
/// glon.to_string(schema)
/// // -> "{\"type\":[\"string\",\"null\"]}"
///
/// glon.decode(schema, from: "\"hello\"")
/// // -> Ok(Some("hello"))
///
/// glon.decode(schema, from: "null")
/// // -> Ok(None)
/// ```
pub fn nullable(inner: JsonSchema(t)) -> JsonSchema(Option(t)) {
  JsonSchema(
    node: NullableNode(inner: inner.node),
    decoder: decode.optional(inner.decoder),
  )
}

// --- Enum / Const ---

/// A schema that restricts values to a fixed set of strings.
///
/// Produces `{"type": "string", "enum": [...]}` and decodes only strings
/// that appear in the given list. Decoding rejects any value not in the list.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.enum(["red", "green", "blue"])
/// glon.to_string(schema)
/// // -> "{\"type\":\"string\",\"enum\":[\"red\",\"green\",\"blue\"]}"
///
/// glon.decode(schema, from: "\"red\"")
/// // -> Ok("red")
///
/// glon.decode(schema, from: "\"yellow\"")
/// // -> Error(...)
/// ```
pub fn enum(values: List(String)) -> JsonSchema(String) {
  let decoder = enum_decoder(values, fn(s) { s })
  JsonSchema(node: EnumNode(values:), decoder:)
}

/// Like `enum`, but maps each string value to an arbitrary Gleam type.
///
/// Takes a list of `#(json_string, gleam_value)` pairs. The schema output
/// uses the JSON strings, while the decoder maps each to its paired value.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.enum_map([
///   #("red", Red), #("green", Green), #("blue", Blue),
/// ])
/// glon.to_string(schema)
/// // -> "{\"type\":\"string\",\"enum\":[\"red\",\"green\",\"blue\"]}"
///
/// glon.decode(schema, from: "\"red\"")
/// // -> Ok(Red)
/// ```
pub fn enum_map(variants: List(#(String, t))) -> JsonSchema(t) {
  let decoder =
    enum_decoder(list.map(variants, fn(v) { v.0 }), fn(s) {
      let assert Ok(#(_, mapped)) = list.find(variants, fn(v) { v.0 == s })
      mapped
    })
  JsonSchema(
    node: EnumNode(values: list.map(variants, fn(v) { v.0 })),
    decoder:,
  )
}

/// A schema that accepts only a single specific string value.
///
/// Produces `{"type": "string", "const": "<value>"}` and decodes only
/// that exact string.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.constant("active")
/// glon.to_string(schema)
/// // -> "{\"type\":\"string\",\"const\":\"active\"}"
///
/// glon.decode(schema, from: "\"active\"")
/// // -> Ok("active")
///
/// glon.decode(schema, from: "\"inactive\"")
/// // -> Error(...)
/// ```
pub fn constant(value: String) -> JsonSchema(String) {
  let decoder = enum_decoder([value], fn(s) { s })
  JsonSchema(node: ConstNode(value:), decoder:)
}

/// Like `constant`, but maps the matched string to an arbitrary Gleam value.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.constant_map("yes", mapped: True)
/// glon.to_string(schema)
/// // -> "{\"type\":\"string\",\"const\":\"yes\"}"
///
/// glon.decode(schema, from: "\"yes\"")
/// // -> Ok(True)
/// ```
pub fn constant_map(value: String, mapped mapped: t) -> JsonSchema(t) {
  let decoder = enum_decoder([value], fn(_) { mapped })
  JsonSchema(node: ConstNode(value:), decoder:)
}

fn enum_decoder(
  values: List(String),
  mapper: fn(String) -> t,
) -> decode.Decoder(t) {
  let assert [first, ..rest] =
    list.map(values, fn(v) {
      decode.string
      |> decode.then(fn(s) {
        case s == v {
          True -> decode.success(mapper(v))
          False ->
            decode.failure(mapper(v), "one of: " <> string.join(values, ", "))
        }
      })
    })
  decode.one_of(first, rest)
}

// --- Annotation ---

/// Attach a `"description"` annotation to any schema.
///
/// The description appears in the JSON Schema output but does not affect
/// decoding. Can be composed with other annotations and combinators.
///
/// ## Examples
///
/// ```gleam
/// let schema =
///   glon.string()
///   |> glon.describe("A person's full name")
/// glon.to_string(schema)
/// // -> "{\"type\":\"string\",\"description\":\"A person's full name\"}"
/// ```
pub fn describe(
  schema: JsonSchema(t),
  description description: String,
) -> JsonSchema(t) {
  JsonSchema(
    node: DescriptionNode(inner: schema.node, description:),
    decoder: schema.decoder,
  )
}

// --- Combinators ---

/// Transform the decoded type of a schema without changing its JSON Schema output.
///
/// The schema definition stays the same, but the decoder maps decoded values
/// through the given function. Useful for wrapping primitives in custom types
/// or making different schemas produce the same type for use with `one_of`.
///
/// ## Examples
///
/// ```gleam
/// type Email { Email(String) }
///
/// let schema = glon.string() |> glon.map(Email)
/// glon.to_string(schema)
/// // -> "{\"type\":\"string\"}"
///
/// glon.decode(schema, from: "\"a@b.com\"")
/// // -> Ok(Email("a@b.com"))
/// ```
pub fn map(schema: JsonSchema(a), with transform: fn(a) -> b) -> JsonSchema(b) {
  JsonSchema(
    node: schema.node,
    decoder: decode.then(schema.decoder, fn(a) { decode.success(transform(a)) }),
  )
}

/// A schema where the value must match exactly one of the given sub-schemas.
///
/// Produces `{"oneOf": [...]}`. The decoder tries each variant in order and
/// returns the first successful match. All variants must decode to the same
/// Gleam type `t` — use `map` to align types if needed.
///
/// ## Examples
///
/// ```gleam
/// type Value { TextVal(String) NumVal(Int) }
///
/// let schema = glon.one_of([
///   glon.string() |> glon.map(TextVal),
///   glon.integer() |> glon.map(NumVal),
/// ])
/// glon.to_string(schema)
/// // -> "{\"oneOf\":[{\"type\":\"string\"},{\"type\":\"integer\"}]}"
/// ```
pub fn one_of(variants: List(JsonSchema(t))) -> JsonSchema(t) {
  let assert [first, ..rest] = variants
  JsonSchema(
    node: CombinerNode(
      keyword: OneOf,
      variants: list.map(variants, fn(v) { v.node }),
    ),
    decoder: decode.one_of(first.decoder, list.map(rest, fn(v) { v.decoder })),
  )
}

/// A schema where the value must match at least one of the given sub-schemas.
///
/// Produces `{"anyOf": [...]}`. Behaves identically to `one_of` for decoding
/// (first match wins), but generates `anyOf` instead of `oneOf` in the schema.
/// The distinction matters for JSON Schema validation: `oneOf` requires exactly
/// one match, `anyOf` allows multiple.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.any_of([
///   glon.string() |> glon.map(TextVal),
///   glon.integer() |> glon.map(NumVal),
/// ])
/// glon.to_string(schema)
/// // -> "{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"integer\"}]}"
/// ```
pub fn any_of(variants: List(JsonSchema(t))) -> JsonSchema(t) {
  let assert [first, ..rest] = variants
  JsonSchema(
    node: CombinerNode(
      keyword: AnyOf,
      variants: list.map(variants, fn(v) { v.node }),
    ),
    decoder: decode.one_of(first.decoder, list.map(rest, fn(v) { v.decoder })),
  )
}

/// A schema for discriminated unions (tagged unions).
///
/// Produces a `oneOf` schema where each variant is an object with a
/// discriminator field set to a constant tag value. The decoder checks
/// the discriminator field to select the correct variant.
///
/// ## Examples
///
/// ```gleam
/// type Shape { Circle(Float) Square(Float) }
///
/// let schema = glon.tagged_union("type", [
///   #("circle", {
///     use radius <- glon.field("radius", glon.number())
///     glon.success(Circle(radius))
///   }),
///   #("square", {
///     use side <- glon.field("side", glon.number())
///     glon.success(Square(side))
///   }),
/// ])
/// ```
pub fn tagged_union(
  discriminator discriminator: String,
  variants variants: List(#(String, JsonSchema(t))),
) -> JsonSchema(t) {
  // Build schema: add const discriminator field to each variant's object
  let schema_variants =
    list.map(variants, fn(variant) {
      let #(tag, schema) = variant
      let fields = get_object_fields(schema.node)
      ObjectNode(fields: [
        ObjectField(name: discriminator, schema: ConstNode(tag), required: True),
        ..fields
      ])
    })

  // Build decoder: check discriminator field, then run variant's decoder
  let assert [first_decoder, ..rest_decoders] =
    list.map(variants, fn(variant) {
      let #(tag, schema) = variant
      use decoded_tag <- decode.field(discriminator, decode.string)
      case decoded_tag == tag {
        True -> schema.decoder
        False -> decode.failure(coerce_nil(), tag)
      }
    })

  JsonSchema(
    node: CombinerNode(keyword: OneOf, variants: schema_variants),
    decoder: decode.one_of(first_decoder, rest_decoders),
  )
}

// --- Object building ---

/// Finish building an object schema by providing the final value.
///
/// This is used as the last step in a chain of `field`, `optional`, or
/// `field_with_default` calls via `use` syntax. It produces an empty object
/// node that gets merged with the fields collected from the chain.
///
/// ## Examples
///
/// ```gleam
/// let schema = {
///   use name <- glon.field("name", glon.string())
///   use age <- glon.field("age", glon.integer())
///   glon.success(User(name:, age:))
/// }
/// ```
pub fn success(value: t) -> JsonSchema(t) {
  JsonSchema(node: ObjectNode(fields: []), decoder: decode.success(value))
}

/// Declare a required object field.
///
/// The field appears in the schema's `"properties"` and `"required"` array.
/// Decoding fails if the field is missing from the JSON input.
///
/// Used with Gleam's `use` syntax to chain multiple fields together.
///
/// ## Examples
///
/// ```gleam
/// let schema = {
///   use name <- glon.field("name", glon.string())
///   use age <- glon.field("age", glon.integer())
///   glon.success(User(name:, age:))
/// }
/// glon.decode(schema, from: "{\"name\":\"Alice\",\"age\":30}")
/// // -> Ok(User(name: "Alice", age: 30))
/// ```
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

/// Declare an optional object field.
///
/// The field appears in the schema's `"properties"` but not in `"required"`.
/// The continuation receives `Option(a)`: `Some(value)` when the field is
/// present, `None` when absent.
///
/// ## Examples
///
/// ```gleam
/// let schema = {
///   use name <- glon.field("name", glon.string())
///   use email <- glon.optional("email", glon.string())
///   glon.success(User(name:, email:))
/// }
/// glon.decode(schema, from: "{\"name\":\"Alice\"}")
/// // -> Ok(User(name: "Alice", email: None))
/// ```
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

/// Declare an optional object field that may also be `null`.
///
/// Like `optional`, but the schema type is wrapped with `nullable` and the
/// decoder treats both an absent field and a `null` value as `None`.
///
/// ## Examples
///
/// ```gleam
/// let schema = {
///   use name <- glon.field("name", glon.string())
///   use nick <- glon.optional_or_null("nickname", glon.string())
///   glon.success(User(name:, nickname: nick))
/// }
/// // Field absent -> None, field null -> None, field present -> Some(value)
/// ```
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

/// Declare an optional object field with a default value.
///
/// The field appears in the schema's `"properties"` with a `"default"`
/// annotation, but not in `"required"`. When the field is absent from the
/// JSON input, the decoder uses the provided default value. Unlike `optional`,
/// the continuation receives the unwrapped type `a` directly, not `Option(a)`.
///
/// The `encode` parameter converts the default value to `json.Json` for the
/// schema output. For primitives, use `json.int`, `json.string`, `json.float`,
/// or `json.bool`.
///
/// ## Examples
///
/// ```gleam
/// let schema = {
///   use host <- glon.field("host", glon.string())
///   use port <- glon.field_with_default(
///     "port", glon.integer(),
///     default: 8080, encode: json.int,
///   )
///   glon.success(Config(host:, port:))
/// }
/// glon.to_string(schema)
/// // -> "{...\"port\":{\"type\":\"integer\",\"default\":8080}...}"
///
/// glon.decode(schema, from: "{\"host\":\"localhost\"}")
/// // -> Ok(Config(host: "localhost", port: 8080))
///
/// glon.decode(schema, from: "{\"host\":\"localhost\",\"port\":3000}")
/// // -> Ok(Config(host: "localhost", port: 3000))
/// ```
pub fn field_with_default(
  named name: String,
  of schema: JsonSchema(a),
  default default_value: a,
  encode encode: fn(a) -> json.Json,
  next next: fn(a) -> JsonSchema(b),
) -> JsonSchema(b) {
  // Probe continuation for schema structure
  let rest = next(coerce_nil())
  let rest_fields = get_object_fields(rest.node)
  let node =
    ObjectNode(fields: [
      ObjectField(
        name:,
        schema: DefaultNode(inner: schema.node, default: encode(default_value)),
        required: False,
      ),
      ..rest_fields
    ])

  // Build real decoder: absent field -> default_value
  let decoder = {
    use value <- decode.optional_field(name, default_value, schema.decoder)
    let result = next(value)
    result.decoder
  }

  JsonSchema(node:, decoder:)
}

// --- Operations ---

/// Convert a schema to a `json.Json` value.
///
/// Returns the JSON Schema representation as a `json.Json` value that can
/// be further processed or serialized.
pub fn to_json(schema: JsonSchema(t)) -> json.Json {
  node_to_json(schema.node)
}

/// Convert a schema to a JSON string.
///
/// Returns the JSON Schema as a serialized JSON string.
///
/// ## Examples
///
/// ```gleam
/// glon.string() |> glon.to_string
/// // -> "{\"type\":\"string\"}"
/// ```
pub fn to_string(schema: JsonSchema(t)) -> String {
  schema
  |> to_json
  |> json.to_string
}

/// Decode a JSON string using the schema's decoder.
///
/// Parses the given JSON string and decodes it according to the schema.
/// Returns `Ok(value)` on success or `Error(DecodeError)` on failure.
///
/// ## Examples
///
/// ```gleam
/// let schema = glon.integer()
/// glon.decode(schema, from: "42")
/// // -> Ok(42)
///
/// glon.decode(schema, from: "\"not a number\"")
/// // -> Error(...)
/// ```
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

    EnumNode(values:) -> [
      #("type", json.string("string")),
      #("enum", json.preprocessed_array(list.map(values, json.string))),
    ]

    ConstNode(value:) -> [
      #("type", json.string("string")),
      #("const", json.string(value)),
    ]

    DescriptionNode(inner:, description:) ->
      list.append(node_to_pairs(inner), [
        #("description", json.string(description)),
      ])

    DefaultNode(inner:, default:) ->
      list.append(node_to_pairs(inner), [#("default", default)])

    CombinerNode(keyword:, variants:) -> {
      let keyword_str = case keyword {
        OneOf -> "oneOf"
        AnyOf -> "anyOf"
      }
      [
        #(
          keyword_str,
          json.preprocessed_array(list.map(variants, node_to_json)),
        ),
      ]
    }
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
    EnumNode(..) -> Ok("string")
    ConstNode(..) -> Ok("string")
    DescriptionNode(inner:, ..) -> get_type_name(inner)
    DefaultNode(inner:, ..) -> get_type_name(inner)
    NullableNode(..) -> Error(Nil)
    CombinerNode(..) -> Error(Nil)
  }
}
