import gleam/option.{type Option, None, Some}
import gleeunit
import json_schema as js

pub fn main() -> Nil {
  gleeunit.main()
}

// --- Primitive schema output ---

pub fn string_schema_test() {
  let schema = js.string()
  assert js.to_string(schema) == "{\"type\":\"string\"}"
}

pub fn integer_schema_test() {
  let schema = js.integer()
  assert js.to_string(schema) == "{\"type\":\"integer\"}"
}

pub fn number_schema_test() {
  let schema = js.number()
  assert js.to_string(schema) == "{\"type\":\"number\"}"
}

pub fn boolean_schema_test() {
  let schema = js.boolean()
  assert js.to_string(schema) == "{\"type\":\"boolean\"}"
}

// --- Composite schema output ---

pub fn array_schema_test() {
  let schema = js.array(of: js.string())
  assert js.to_string(schema)
    == "{\"type\":\"array\",\"items\":{\"type\":\"string\"}}"
}

pub fn nullable_schema_test() {
  let schema = js.nullable(js.string())
  assert js.to_string(schema) == "{\"type\":[\"string\",\"null\"]}"
}

pub fn nullable_array_schema_test() {
  let schema = js.nullable(js.array(of: js.integer()))
  assert js.to_string(schema)
    == "{\"type\":[\"array\",\"null\"],\"items\":{\"type\":\"integer\"}}"
}

// --- Describe annotation ---

pub fn describe_string_test() {
  let schema =
    js.string()
    |> js.describe("A name")
  assert js.to_string(schema)
    == "{\"type\":\"string\",\"description\":\"A name\"}"
}

pub fn describe_nullable_test() {
  let schema =
    js.string()
    |> js.describe("A name")
    |> js.nullable
  assert js.to_string(schema)
    == "{\"type\":[\"string\",\"null\"],\"description\":\"A name\"}"
}

// --- Object schema output ---

pub type User {
  User(name: String, age: Int)
}

pub fn object_schema_test() {
  let schema = {
    use name <- js.field("name", js.string())
    use age <- js.field("age", js.integer())
    js.success(User(name:, age:))
  }
  assert js.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"age\":{\"type\":\"integer\"}},\"required\":[\"name\",\"age\"]}"
}

pub type UserWithEmail {
  UserWithEmail(name: String, email: Option(String))
}

pub fn optional_field_schema_test() {
  let schema = {
    use name <- js.field("name", js.string())
    use email <- js.optional("email", js.string())
    js.success(UserWithEmail(name:, email:))
  }
  assert js.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"email\":{\"type\":\"string\"}},\"required\":[\"name\"]}"
}

pub type UserWithNickname {
  UserWithNickname(name: String, nickname: Option(String))
}

pub fn optional_or_null_field_schema_test() {
  let schema = {
    use name <- js.field("name", js.string())
    use nickname <- js.optional_or_null("nickname", js.string())
    js.success(UserWithNickname(name:, nickname:))
  }
  assert js.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"nickname\":{\"type\":[\"string\",\"null\"]}},\"required\":[\"name\"]}"
}

pub fn object_with_describe_test() {
  let schema = {
    use name <- js.field("name", js.string() |> js.describe("Full name"))
    use age <- js.field("age", js.integer())
    js.success(User(name:, age:))
  }
  assert js.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\",\"description\":\"Full name\"},\"age\":{\"type\":\"integer\"}},\"required\":[\"name\",\"age\"]}"
}

// --- Decode tests ---

pub fn decode_string_test() {
  let schema = js.string()
  assert js.decode(schema, from: "\"hello\"") == Ok("hello")
}

pub fn decode_integer_test() {
  let schema = js.integer()
  assert js.decode(schema, from: "42") == Ok(42)
}

pub fn decode_number_test() {
  let schema = js.number()
  assert js.decode(schema, from: "3.14") == Ok(3.14)
}

pub fn decode_boolean_test() {
  let schema = js.boolean()
  assert js.decode(schema, from: "true") == Ok(True)
}

pub fn decode_array_test() {
  let schema = js.array(of: js.integer())
  assert js.decode(schema, from: "[1,2,3]") == Ok([1, 2, 3])
}

pub fn decode_nullable_some_test() {
  let schema = js.nullable(js.string())
  assert js.decode(schema, from: "\"hello\"") == Ok(Some("hello"))
}

pub fn decode_nullable_none_test() {
  let schema = js.nullable(js.string())
  assert js.decode(schema, from: "null") == Ok(None)
}

pub fn decode_object_test() {
  let schema = {
    use name <- js.field("name", js.string())
    use age <- js.field("age", js.integer())
    js.success(User(name:, age:))
  }
  assert js.decode(
      schema,
      from: "{\"name\":\"Alice\",\"age\":30}",
    )
    == Ok(User(name: "Alice", age: 30))
}

pub fn decode_optional_present_test() {
  let schema = {
    use name <- js.field("name", js.string())
    use email <- js.optional("email", js.string())
    js.success(UserWithEmail(name:, email:))
  }
  assert js.decode(
      schema,
      from: "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}",
    )
    == Ok(UserWithEmail(name: "Alice", email: Some("alice@example.com")))
}

pub fn decode_optional_absent_test() {
  let schema = {
    use name <- js.field("name", js.string())
    use email <- js.optional("email", js.string())
    js.success(UserWithEmail(name:, email:))
  }
  assert js.decode(schema, from: "{\"name\":\"Alice\"}")
    == Ok(UserWithEmail(name: "Alice", email: None))
}

pub fn decode_optional_or_null_present_test() {
  let schema = {
    use name <- js.field("name", js.string())
    use nickname <- js.optional_or_null("nickname", js.string())
    js.success(UserWithNickname(name:, nickname:))
  }
  assert js.decode(
      schema,
      from: "{\"name\":\"Alice\",\"nickname\":\"Ali\"}",
    )
    == Ok(UserWithNickname(name: "Alice", nickname: Some("Ali")))
}

pub fn decode_optional_or_null_null_test() {
  let schema = {
    use name <- js.field("name", js.string())
    use nickname <- js.optional_or_null("nickname", js.string())
    js.success(UserWithNickname(name:, nickname:))
  }
  assert js.decode(
      schema,
      from: "{\"name\":\"Alice\",\"nickname\":null}",
    )
    == Ok(UserWithNickname(name: "Alice", nickname: None))
}

pub fn decode_optional_or_null_absent_test() {
  let schema = {
    use name <- js.field("name", js.string())
    use nickname <- js.optional_or_null("nickname", js.string())
    js.success(UserWithNickname(name:, nickname:))
  }
  assert js.decode(schema, from: "{\"name\":\"Alice\"}")
    == Ok(UserWithNickname(name: "Alice", nickname: None))
}

// --- Error cases ---

pub fn decode_invalid_json_test() {
  let schema = js.string()
  let result = js.decode(schema, from: "{invalid")
  assert result
    |> is_error
}

pub fn decode_wrong_type_test() {
  let schema = js.string()
  let result = js.decode(schema, from: "42")
  assert result
    |> is_error
}

fn is_error(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> False
    Error(_) -> True
  }
}

// --- Complex integration test ---

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
  use street <- js.field("street", js.string() |> js.describe("Street address"))
  use city <- js.field("city", js.string())
  use zip <- js.optional("zip", js.string() |> js.describe("ZIP or postal code"))
  js.success(Address(street:, city:, zip:))
}

fn tag_schema() {
  use key <- js.field("key", js.string())
  use value <- js.field("value", js.string())
  js.success(Tag(key:, value:))
}

fn company_schema() {
  use name <- js.field("name", js.string() |> js.describe("Legal company name"))
  use founded_year <- js.field("founded_year", js.integer() |> js.describe("Year the company was founded"))
  use public <- js.field("public", js.boolean() |> js.describe("Whether publicly traded"))
  use rating <- js.optional_or_null("rating", js.number() |> js.describe("Rating from 0.0 to 5.0"))
  use address <- js.field("address", address_schema())
  use tags <- js.field("tags", js.array(of: tag_schema()) |> js.describe("Categorization tags"))
  use website <- js.optional("website", js.string())
  use phone <- js.optional_or_null("phone", js.string())
  js.success(Company(name:, founded_year:, public:, rating:, address:, tags:, website:, phone:))
}

pub fn complex_schema_output_test() {
  let schema = company_schema()
  let expected =
    "{\"type\":\"object\",\"properties\":"
    <> "{\"name\":{\"type\":\"string\",\"description\":\"Legal company name\"}"
    <> ",\"founded_year\":{\"type\":\"integer\",\"description\":\"Year the company was founded\"}"
    <> ",\"public\":{\"type\":\"boolean\",\"description\":\"Whether publicly traded\"}"
    <> ",\"rating\":{\"type\":[\"number\",\"null\"],\"description\":\"Rating from 0.0 to 5.0\"}"
    <> ",\"address\":{\"type\":\"object\",\"properties\":"
    <> "{\"street\":{\"type\":\"string\",\"description\":\"Street address\"}"
    <> ",\"city\":{\"type\":\"string\"}"
    <> ",\"zip\":{\"type\":\"string\",\"description\":\"ZIP or postal code\"}}"
    <> ",\"required\":[\"street\",\"city\"]}"
    <> ",\"tags\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"properties\":"
    <> "{\"key\":{\"type\":\"string\"},\"value\":{\"type\":\"string\"}}"
    <> ",\"required\":[\"key\",\"value\"]}"
    <> ",\"description\":\"Categorization tags\"}"
    <> ",\"website\":{\"type\":\"string\"}"
    <> ",\"phone\":{\"type\":[\"string\",\"null\"]}}"
    <> ",\"required\":[\"name\",\"founded_year\",\"public\",\"address\",\"tags\"]}"
  assert js.to_string(schema) == expected
}

pub fn complex_decode_full_test() {
  let schema = company_schema()
  let input =
    "{\"name\":\"Acme Corp\",\"founded_year\":1995,\"public\":true,\"rating\":4.5,"
    <> "\"address\":{\"street\":\"123 Main St\",\"city\":\"Springfield\",\"zip\":\"62704\"},"
    <> "\"tags\":[{\"key\":\"industry\",\"value\":\"tech\"},{\"key\":\"size\",\"value\":\"large\"}],"
    <> "\"website\":\"https://acme.example.com\",\"phone\":\"+1-555-0100\"}"
  assert js.decode(schema, from: input)
    == Ok(Company(
      name: "Acme Corp",
      founded_year: 1995,
      public: True,
      rating: Some(4.5),
      address: Address(
        street: "123 Main St",
        city: "Springfield",
        zip: Some("62704"),
      ),
      tags: [Tag(key: "industry", value: "tech"), Tag(key: "size", value: "large")],
      website: Some("https://acme.example.com"),
      phone: Some("+1-555-0100"),
    ))
}

pub fn complex_decode_minimal_test() {
  let schema = company_schema()
  let input =
    "{\"name\":\"Tiny LLC\",\"founded_year\":2020,\"public\":false,"
    <> "\"address\":{\"street\":\"1 Elm St\",\"city\":\"Shelbyville\"},"
    <> "\"tags\":[]}"
  assert js.decode(schema, from: input)
    == Ok(Company(
      name: "Tiny LLC",
      founded_year: 2020,
      public: False,
      rating: None,
      address: Address(street: "1 Elm St", city: "Shelbyville", zip: None),
      tags: [],
      website: None,
      phone: None,
    ))
}

pub fn complex_decode_nulls_test() {
  let schema = company_schema()
  let input =
    "{\"name\":\"Null Inc\",\"founded_year\":2010,\"public\":true,"
    <> "\"rating\":null,"
    <> "\"address\":{\"street\":\"0 Zero Rd\",\"city\":\"Nowhere\"},"
    <> "\"tags\":[{\"key\":\"status\",\"value\":\"active\"}],"
    <> "\"phone\":null}"
  assert js.decode(schema, from: input)
    == Ok(Company(
      name: "Null Inc",
      founded_year: 2010,
      public: True,
      rating: None,
      address: Address(street: "0 Zero Rd", city: "Nowhere", zip: None),
      tags: [Tag(key: "status", value: "active")],
      website: None,
      phone: None,
    ))
}
