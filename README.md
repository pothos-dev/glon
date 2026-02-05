# glon

A Gleam library for JSON Schema generation and decoding. Define a schema once, then use it to both generate a JSON Schema string and decode JSON values into typed Gleam data.

[![Package Version](https://img.shields.io/hexpm/v/glon)](https://hex.pm/packages/glon)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glon/)

```sh
gleam add glon@1
```

## How it works

`JsonSchema(t)` is an opaque type that pairs a JSON Schema definition with a decoder. When you build a schema using the builder API, you get a value that can:

- **Generate** a JSON Schema string via `to_string`
- **Decode** a JSON value into a typed Gleam result via `decode`

The schema and decoder are always in sync -- if you say a field is a string, the decoder knows to decode a string.

## Quick start

```gleam
import glon

pub type User {
  User(name: String, age: Int)
}

fn user_schema() {
  use name <- glon.field("name", glon.string())
  use age <- glon.field("age", glon.integer())
  glon.success(User(name:, age:))
}

pub fn main() {
  let schema = user_schema()

  // Generate JSON Schema
  glon.to_string(schema)
  // -> {"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"}},"required":["name","age"]}

  // Decode JSON values
  glon.decode(schema, from: "{\"name\":\"Alice\",\"age\":30}")
  // -> Ok(User(name: "Alice", age: 30))
}
```

## Full example

A more realistic schema with nested objects, arrays, optional fields, nullable fields, and descriptions:

```gleam
import gleam/option.{type Option}
import glon

pub type Address {
  Address(street: String, city: String, zip: Option(String))
}

pub type Tag {
  Tag(key: String, value: String)
}

pub type Company {
  Company(
    name: String,
    founded_year: Int,
    public: Bool,
    rating: Option(Float),
    address: Address,
    tags: List(Tag),
    website: Option(String),
    phone: Option(String),
  )
}

fn address_schema() {
  use street <- glon.field("street", glon.string() |> glon.describe("Street address"))
  use city <- glon.field("city", glon.string())
  use zip <- glon.optional("zip", glon.string() |> glon.describe("ZIP or postal code"))
  glon.success(Address(street:, city:, zip:))
}

fn tag_schema() {
  use key <- glon.field("key", glon.string())
  use value <- glon.field("value", glon.string())
  glon.success(Tag(key:, value:))
}

fn company_schema() {
  use name <- glon.field("name", glon.string() |> glon.describe("Legal company name"))
  use founded_year <- glon.field("founded_year", glon.integer() |> glon.describe("Year the company was founded"))
  use public <- glon.field("public", glon.boolean() |> glon.describe("Whether publicly traded"))
  use rating <- glon.optional_or_null("rating", glon.number() |> glon.describe("Rating from 0.0 to 5.0"))
  use address <- glon.field("address", address_schema())
  use tags <- glon.field("tags", glon.array(of: tag_schema()) |> glon.describe("Categorization tags"))
  use website <- glon.optional("website", glon.string())
  use phone <- glon.optional_or_null("phone", glon.string())
  glon.success(Company(name:, founded_year:, public:, rating:, address:, tags:, website:, phone:))
}
```

`glon.to_string(company_schema())` produces:

```json
{
  "type": "object",
  "properties": {
    "name": { "type": "string", "description": "Legal company name" },
    "founded_year": { "type": "integer", "description": "Year the company was founded" },
    "public": { "type": "boolean", "description": "Whether publicly traded" },
    "rating": { "type": ["number", "null"], "description": "Rating from 0.0 to 5.0" },
    "address": {
      "type": "object",
      "properties": {
        "street": { "type": "string", "description": "Street address" },
        "city": { "type": "string" },
        "zip": { "type": "string", "description": "ZIP or postal code" }
      },
      "required": ["street", "city"]
    },
    "tags": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "key": { "type": "string" },
          "value": { "type": "string" }
        },
        "required": ["key", "value"]
      },
      "description": "Categorization tags"
    },
    "website": { "type": "string" },
    "phone": { "type": ["string", "null"] }
  },
  "required": ["name", "founded_year", "public", "address", "tags"]
}
```

The same schema decodes JSON into typed Gleam values:

```gleam
// All fields present
glon.decode(company_schema(), from: "{\"name\":\"Acme Corp\",\"founded_year\":1995,\"public\":true,\"rating\":4.5,\"address\":{\"street\":\"123 Main St\",\"city\":\"Springfield\",\"zip\":\"62704\"},\"tags\":[{\"key\":\"industry\",\"value\":\"tech\"}],\"website\":\"https://acme.example.com\",\"phone\":\"+1-555-0100\"}")
// -> Ok(Company(name: "Acme Corp", founded_year: 1995, public: True, rating: Some(4.5), ...))

// Only required fields
glon.decode(company_schema(), from: "{\"name\":\"Tiny LLC\",\"founded_year\":2020,\"public\":false,\"address\":{\"street\":\"1 Elm St\",\"city\":\"Shelbyville\"},\"tags\":[]}")
// -> Ok(Company(name: "Tiny LLC", ..., rating: None, website: None, phone: None))

// Explicit nulls
glon.decode(company_schema(), from: "{\"name\":\"Null Inc\",\"founded_year\":2010,\"public\":true,\"rating\":null,\"address\":{\"street\":\"0 Zero Rd\",\"city\":\"Nowhere\"},\"tags\":[],\"phone\":null}")
// -> Ok(Company(name: "Null Inc", ..., rating: None, phone: None))
```

## API reference

### Primitives

| Function | Type | JSON Schema |
|---|---|---|
| `glon.string()` | `JsonSchema(String)` | `{"type": "string"}` |
| `glon.integer()` | `JsonSchema(Int)` | `{"type": "integer"}` |
| `glon.number()` | `JsonSchema(Float)` | `{"type": "number"}` |
| `glon.boolean()` | `JsonSchema(Bool)` | `{"type": "boolean"}` |

### Composites

| Function | Type | JSON Schema |
|---|---|---|
| `glon.array(of: schema)` | `JsonSchema(List(t))` | `{"type": "array", "items": ...}` |
| `glon.nullable(schema)` | `JsonSchema(Option(t))` | `{"type": ["<t>", "null"]}` |

### Object fields

| Function | Required? | Nullable? | Gleam type |
|---|---|---|---|
| `glon.field` | yes | no | `t` |
| `glon.optional` | no | no | `Option(t)` |
| `glon.optional_or_null` | no | yes | `Option(t)` |
| `glon.field_with_default` | no | no | `t` (uses default when absent) |

All four are used with Gleam's `use` syntax to chain fields:

```gleam
use value <- glon.field("name", glon.string())
use value <- glon.optional("name", glon.string())
use value <- glon.optional_or_null("name", glon.string())
use value <- glon.field_with_default("port", glon.integer(), default: 8080, encode: json.int)
```

### Enum / Const

| Function | Type | JSON Schema |
|---|---|---|
| `glon.enum(["a", "b"])` | `JsonSchema(String)` | `{"type": "string", "enum": ["a", "b"]}` |
| `glon.enum_map([#("a", A), #("b", B)])` | `JsonSchema(t)` | `{"type": "string", "enum": ["a", "b"]}` |
| `glon.constant("a")` | `JsonSchema(String)` | `{"type": "string", "const": "a"}` |
| `glon.constant_map("a", A)` | `JsonSchema(t)` | `{"type": "string", "const": "a"}` |

The `_map` variants decode to a custom Gleam type instead of `String`:

```gleam
type Color { Red Green Blue }

// Decodes to String
glon.enum(["red", "green", "blue"])

// Decodes to Color
glon.enum_map([#("red", Red), #("green", Green), #("blue", Blue)])
```

### Combinators

| Function | JSON Schema | Description |
|---|---|---|
| `glon.map(schema, transform)` | *(unchanged)* | Transform decoded type without changing schema |
| `glon.one_of([a, b, ...])` | `{"oneOf": [...]}` | Value must match exactly one sub-schema |
| `glon.any_of([a, b, ...])` | `{"anyOf": [...]}` | Value must match at least one sub-schema |
| `glon.tagged_union("type", [...])` | `{"oneOf": [...]}` with discriminator | Discriminated union with tag field |

Use `map` to align types for `one_of` / `any_of`:

```gleam
type Value { TextVal(String) NumVal(Int) }

let schema = glon.one_of([
  glon.string() |> glon.map(TextVal),
  glon.integer() |> glon.map(NumVal),
])
```

Use `tagged_union` for discriminated unions:

```gleam
type Shape { Circle(Float) Square(Float) }

let schema = glon.tagged_union("type", [
  #("circle", {
    use radius <- glon.field("radius", glon.number())
    glon.success(Circle(radius))
  }),
  #("square", {
    use side <- glon.field("side", glon.number())
    glon.success(Square(side))
  }),
])
```

### String validation

All string constraints are enforced during decode.

| Function | JSON Schema | Decode behavior |
|---|---|---|
| `glon.min_length(schema, n)` | `{"minLength": n}` | Rejects strings shorter than `n` |
| `glon.max_length(schema, n)` | `{"maxLength": n}` | Rejects strings longer than `n` |
| `glon.pattern(schema, regex)` | `{"pattern": "..."}` | Rejects strings not matching the regex |

```gleam
glon.string()
|> glon.min_length(1)
|> glon.max_length(100)
|> glon.pattern("^[a-zA-Z]+$")
```

### Number validation

All number constraints are enforced during decode. Constraint values are `Float`, and work on both `integer()` and `number()` schemas.

| Function | JSON Schema | Decode behavior |
|---|---|---|
| `glon.minimum(schema, n)` | `{"minimum": n}` | Rejects values < `n` |
| `glon.maximum(schema, n)` | `{"maximum": n}` | Rejects values > `n` |
| `glon.exclusive_minimum(schema, n)` | `{"exclusiveMinimum": n}` | Rejects values <= `n` |
| `glon.exclusive_maximum(schema, n)` | `{"exclusiveMaximum": n}` | Rejects values >= `n` |
| `glon.multiple_of(schema, n)` | `{"multipleOf": n}` | Rejects values not a multiple of `n` |

```gleam
glon.integer()
|> glon.minimum(0.0)
|> glon.maximum(100.0)

glon.number()
|> glon.exclusive_minimum(0.0)
|> glon.multiple_of(0.5)
```

### Annotations

```gleam
glon.string() |> glon.describe("A human-readable description")
```

### Operations

```gleam
glon.to_string(schema)                    // -> String (JSON Schema)
glon.to_json(schema)                      // -> json.Json (for embedding in larger structures)
glon.decode(schema, from: json_string)    // -> Result(t, json.DecodeError)
```

## JSON Schema coverage

| Feature | Status | Notes |
|---|---|---|
| **Types** | | |
| `string` | ✅ Supported | |
| `integer` | ✅ Supported | |
| `number` | ✅ Supported | |
| `boolean` | ✅ Supported | |
| `array` | ✅ Supported | |
| `object` | ✅ Supported | Nested objects, required/optional fields |
| `null` / nullable | ✅ Supported | Via `nullable`, `optional_or_null` |
| `enum` | ✅ Supported | String values via `enum`, `enum_map` |
| `const` | ✅ Supported | String values via `constant`, `constant_map` |
| **Composition** | | |
| `oneOf` | ✅ Supported | Via `one_of`, `tagged_union` |
| `anyOf` | ✅ Supported | Via `any_of` |
| `allOf` | 🚫 Out of scope | Incompatible with Gleam's type system |
| `not` | 🔲 Not yet | Negation |
| `$ref` / `$defs` | 🔲 Not yet | Reusable schema definitions |
| **Object keywords** | | |
| `properties` | ✅ Supported | |
| `required` | ✅ Supported | |
| `additionalProperties` | 🔲 Not yet | |
| `patternProperties` | 🔲 Not yet | |
| `propertyNames` | 🔲 Not yet | |
| `minProperties` / `maxProperties` | 🔲 Not yet | |
| `dependentRequired` / `dependentSchemas` | 🔲 Not yet | |
| **Array keywords** | | |
| `items` | ✅ Supported | |
| `prefixItems` | 🔲 Not yet | Tuple validation |
| `minItems` / `maxItems` | 🔲 Not yet | |
| `uniqueItems` | 🔲 Not yet | |
| `contains` | 🔲 Not yet | |
| **String validation** | | |
| `minLength` / `maxLength` | ✅ Supported | Via `min_length`, `max_length` |
| `pattern` | ✅ Supported | Via `pattern` |
| `format` | 🚫 Out of scope | Validating formats is out of scope |
| **Number validation** | | |
| `minimum` / `maximum` | ✅ Supported | Via `minimum`, `maximum` |
| `exclusiveMinimum` / `exclusiveMaximum` | ✅ Supported | Via `exclusive_minimum`, `exclusive_maximum` |
| `multipleOf` | ✅ Supported | Via `multiple_of` |
| **Annotations** | | |
| `description` | ✅ Supported | Via `describe` |
| `title` | 🔲 Not yet | |
| `default` | ✅ Supported | Via `field_with_default` |
| `examples` | 🔲 Not yet | |
| `deprecated` | 🔲 Not yet | |
| `readOnly` / `writeOnly` | 🔲 Not yet | |
| **Conditional** | | |
| `if` / `then` / `else` | 🔲 Not yet | |
| **Meta** | | |
| `$schema` | 🔲 Not yet | Draft identifier |
| `$id` | 🔲 Not yet | |
| `$comment` | 🔲 Not yet | |

## Compatibility

- Requires `gleam_json` >= 3.0
- Works on both Erlang and JavaScript targets
