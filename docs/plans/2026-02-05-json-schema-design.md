# JSON Schema Library for Gleam - Design

## Overview

A Gleam library that provides a single `JsonSchema(t)` type which carries both a JSON Schema definition and a decoder. Built via a composable builder API using Gleam's `use` syntax. Two operations act on the type:

- `to_string` / `to_json` - converts the schema definition into a JSON Schema representation
- `decode` - parses a JSON string into a value of type `t` or returns an error

## Core Type

```gleam
pub opaque type JsonSchema(t) {
  JsonSchema(node: SchemaNode, decoder: Decoder(t))
}
```

Internal schema AST:

```
type SchemaNode {
  StringNode
  IntegerNode
  NumberNode
  BooleanNode
  ArrayNode(items: SchemaNode)
  NullableNode(inner: SchemaNode)
  ObjectNode(fields: List(#(String, SchemaNode, Bool)))
  DescriptionNode(inner: SchemaNode, description: String)
}
```

## Public API

### Primitives

- `string() -> JsonSchema(String)`
- `integer() -> JsonSchema(Int)`
- `number() -> JsonSchema(Float)`
- `boolean() -> JsonSchema(Bool)`

### Composites

- `array(of: JsonSchema(t)) -> JsonSchema(List(t))`
- `nullable(inner: JsonSchema(t)) -> JsonSchema(Option(t))`

### Annotation

- `describe(schema: JsonSchema(t), description: String) -> JsonSchema(t)`

### Object Building

- `field(name, schema, next)` - required field, added to `required` array
- `optional(name, schema, next)` - optional field, absent -> `None`
- `optional_or_null(name, schema, next)` - optional + nullable, absent OR null -> `None`
- `success(value)` - terminates the object chain

### Operations

- `to_string(schema) -> String` - JSON Schema as compact string
- `to_json(schema) -> json.Json` - JSON Schema as json.Json value
- `decode(schema, from: String) -> Result(t, json.JsonError)` - decode JSON value

## Usage Example

```gleam
import json_schema

pub type User {
  User(name: String, age: Int, email: Option(String))
}

let schema = {
  use name <- json_schema.field("name", json_schema.string() |> json_schema.describe("Full name"))
  use age <- json_schema.field("age", json_schema.integer())
  use email <- json_schema.optional("email", json_schema.string())
  json_schema.success(User(name:, age:, email:))
}

// Generate JSON Schema string
json_schema.to_string(schema)
// -> {"type":"object","properties":{"name":{"type":"string","description":"Full name"},"age":{"type":"integer"},"email":{"type":"string"}},"required":["name","age"]}

// Decode a JSON value
json_schema.decode(schema, from: "{\"name\":\"Alice\",\"age\":30}")
// -> Ok(User(name: "Alice", age: 30, email: None))
```

## Implementation: The Continuation Problem

The `use`-based chaining means `field` receives a continuation `next: fn(a) -> JsonSchema(b)`. To build the complete object schema, `field` needs to know what fields exist inside `next`. But it cannot call `next` without a value of type `a`.

Solution: a tiny FFI function `coerce_nil() -> a` that returns `nil`/`undefined` typed as any `a`. Used to probe the continuation for its schema AST at construction time. The dummy value flows into `success(User(nil, nil, ...))` which produces `ObjectNode([])` - the values are never inspected. The real decoder (built separately) uses actual decoded values at decode time.

This is analogous to `unsafe` in Rust - a contained escape hatch enabling a safe public API.

## JSON Schema Output

Draft-agnostic, outputting the common subset:

- Primitives: `{"type": "string"}`, `{"type": "integer"}`, `{"type": "number"}`, `{"type": "boolean"}`
- Arrays: `{"type": "array", "items": {...}}`
- Nullable: `{"type": ["<inner_type>", "null"]}`
- Objects: `{"type": "object", "properties": {...}, "required": [...]}`
- Description: `{"description": "...", ...merged with inner schema}`

## Dependencies

- `gleam_json` >= 3.0
- `gleam_stdlib`

## Error Handling

Reuses `json.JsonError` from `gleam_json` directly. No custom error types.
