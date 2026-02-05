import gleam/json
import gleam/option.{type Option, None, Some}
import gleeunit
import glon

pub fn main() -> Nil {
  gleeunit.main()
}

// --- Primitive schema output ---

pub fn string_schema_test() {
  let schema = glon.string()
  assert glon.to_string(schema) == "{\"type\":\"string\"}"
}

pub fn integer_schema_test() {
  let schema = glon.integer()
  assert glon.to_string(schema) == "{\"type\":\"integer\"}"
}

pub fn number_schema_test() {
  let schema = glon.number()
  assert glon.to_string(schema) == "{\"type\":\"number\"}"
}

pub fn boolean_schema_test() {
  let schema = glon.boolean()
  assert glon.to_string(schema) == "{\"type\":\"boolean\"}"
}

// --- Composite schema output ---

pub fn array_schema_test() {
  let schema = glon.array(of: glon.string())
  assert glon.to_string(schema)
    == "{\"type\":\"array\",\"items\":{\"type\":\"string\"}}"
}

pub fn nullable_schema_test() {
  let schema = glon.nullable(glon.string())
  assert glon.to_string(schema) == "{\"type\":[\"string\",\"null\"]}"
}

pub fn nullable_array_schema_test() {
  let schema = glon.nullable(glon.array(of: glon.integer()))
  assert glon.to_string(schema)
    == "{\"type\":[\"array\",\"null\"],\"items\":{\"type\":\"integer\"}}"
}

// --- Describe annotation ---

pub fn describe_string_test() {
  let schema =
    glon.string()
    |> glon.describe("A name")
  assert glon.to_string(schema)
    == "{\"type\":\"string\",\"description\":\"A name\"}"
}

pub fn describe_nullable_test() {
  let schema =
    glon.string()
    |> glon.describe("A name")
    |> glon.nullable
  assert glon.to_string(schema)
    == "{\"type\":[\"string\",\"null\"],\"description\":\"A name\"}"
}

// --- Object schema output ---

pub type User {
  User(name: String, age: Int)
}

pub fn object_schema_test() {
  let schema = {
    use name <- glon.field("name", glon.string())
    use age <- glon.field("age", glon.integer())
    glon.success(User(name:, age:))
  }
  assert glon.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"age\":{\"type\":\"integer\"}},\"required\":[\"name\",\"age\"]}"
}

pub type UserWithEmail {
  UserWithEmail(name: String, email: Option(String))
}

pub fn optional_field_schema_test() {
  let schema = {
    use name <- glon.field("name", glon.string())
    use email <- glon.optional("email", glon.string())
    glon.success(UserWithEmail(name:, email:))
  }
  assert glon.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"email\":{\"type\":\"string\"}},\"required\":[\"name\"]}"
}

pub type UserWithNickname {
  UserWithNickname(name: String, nickname: Option(String))
}

pub fn optional_or_null_field_schema_test() {
  let schema = {
    use name <- glon.field("name", glon.string())
    use nickname <- glon.optional_or_null("nickname", glon.string())
    glon.success(UserWithNickname(name:, nickname:))
  }
  assert glon.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"nickname\":{\"type\":[\"string\",\"null\"]}},\"required\":[\"name\"]}"
}

pub fn object_with_describe_test() {
  let schema = {
    use name <- glon.field("name", glon.string() |> glon.describe("Full name"))
    use age <- glon.field("age", glon.integer())
    glon.success(User(name:, age:))
  }
  assert glon.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\",\"description\":\"Full name\"},\"age\":{\"type\":\"integer\"}},\"required\":[\"name\",\"age\"]}"
}

// --- Decode tests ---

pub fn decode_string_test() {
  let schema = glon.string()
  assert glon.decode(schema, from: "\"hello\"") == Ok("hello")
}

pub fn decode_integer_test() {
  let schema = glon.integer()
  assert glon.decode(schema, from: "42") == Ok(42)
}

pub fn decode_number_test() {
  let schema = glon.number()
  assert glon.decode(schema, from: "3.14") == Ok(3.14)
}

pub fn decode_boolean_test() {
  let schema = glon.boolean()
  assert glon.decode(schema, from: "true") == Ok(True)
}

pub fn decode_array_test() {
  let schema = glon.array(of: glon.integer())
  assert glon.decode(schema, from: "[1,2,3]") == Ok([1, 2, 3])
}

pub fn decode_nullable_some_test() {
  let schema = glon.nullable(glon.string())
  assert glon.decode(schema, from: "\"hello\"") == Ok(Some("hello"))
}

pub fn decode_nullable_none_test() {
  let schema = glon.nullable(glon.string())
  assert glon.decode(schema, from: "null") == Ok(None)
}

pub fn decode_object_test() {
  let schema = {
    use name <- glon.field("name", glon.string())
    use age <- glon.field("age", glon.integer())
    glon.success(User(name:, age:))
  }
  assert glon.decode(schema, from: "{\"name\":\"Alice\",\"age\":30}")
    == Ok(User(name: "Alice", age: 30))
}

pub fn decode_optional_present_test() {
  let schema = {
    use name <- glon.field("name", glon.string())
    use email <- glon.optional("email", glon.string())
    glon.success(UserWithEmail(name:, email:))
  }
  assert glon.decode(
      schema,
      from: "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}",
    )
    == Ok(UserWithEmail(name: "Alice", email: Some("alice@example.com")))
}

pub fn decode_optional_absent_test() {
  let schema = {
    use name <- glon.field("name", glon.string())
    use email <- glon.optional("email", glon.string())
    glon.success(UserWithEmail(name:, email:))
  }
  assert glon.decode(schema, from: "{\"name\":\"Alice\"}")
    == Ok(UserWithEmail(name: "Alice", email: None))
}

pub fn decode_optional_or_null_present_test() {
  let schema = {
    use name <- glon.field("name", glon.string())
    use nickname <- glon.optional_or_null("nickname", glon.string())
    glon.success(UserWithNickname(name:, nickname:))
  }
  assert glon.decode(schema, from: "{\"name\":\"Alice\",\"nickname\":\"Ali\"}")
    == Ok(UserWithNickname(name: "Alice", nickname: Some("Ali")))
}

pub fn decode_optional_or_null_null_test() {
  let schema = {
    use name <- glon.field("name", glon.string())
    use nickname <- glon.optional_or_null("nickname", glon.string())
    glon.success(UserWithNickname(name:, nickname:))
  }
  assert glon.decode(schema, from: "{\"name\":\"Alice\",\"nickname\":null}")
    == Ok(UserWithNickname(name: "Alice", nickname: None))
}

pub fn decode_optional_or_null_absent_test() {
  let schema = {
    use name <- glon.field("name", glon.string())
    use nickname <- glon.optional_or_null("nickname", glon.string())
    glon.success(UserWithNickname(name:, nickname:))
  }
  assert glon.decode(schema, from: "{\"name\":\"Alice\"}")
    == Ok(UserWithNickname(name: "Alice", nickname: None))
}

// --- Default value tests ---

pub type Config {
  Config(host: String, port: Int, verbose: Bool)
}

pub fn field_with_default_schema_test() {
  let schema = {
    use host <- glon.field("host", glon.string())
    use port <- glon.field_with_default(
      "port",
      glon.integer(),
      default: 8080,
      encode: json.int,
    )
    use verbose <- glon.field_with_default(
      "verbose",
      glon.boolean(),
      default: False,
      encode: json.bool,
    )
    glon.success(Config(host:, port:, verbose:))
  }
  assert glon.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"host\":{\"type\":\"string\"},\"port\":{\"type\":\"integer\",\"default\":8080},\"verbose\":{\"type\":\"boolean\",\"default\":false}},\"required\":[\"host\"]}"
}

pub fn decode_field_with_default_absent_test() {
  let schema = {
    use host <- glon.field("host", glon.string())
    use port <- glon.field_with_default(
      "port",
      glon.integer(),
      default: 8080,
      encode: json.int,
    )
    glon.success(#(host, port))
  }
  assert glon.decode(schema, from: "{\"host\":\"localhost\"}")
    == Ok(#("localhost", 8080))
}

pub fn decode_field_with_default_present_test() {
  let schema = {
    use host <- glon.field("host", glon.string())
    use port <- glon.field_with_default(
      "port",
      glon.integer(),
      default: 8080,
      encode: json.int,
    )
    glon.success(#(host, port))
  }
  assert glon.decode(schema, from: "{\"host\":\"localhost\",\"port\":3000}")
    == Ok(#("localhost", 3000))
}

pub fn field_with_default_string_test() {
  let schema = {
    use name <- glon.field_with_default(
      "name",
      glon.string(),
      default: "anon",
      encode: json.string,
    )
    glon.success(name)
  }
  assert glon.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\",\"default\":\"anon\"}}}"
  assert glon.decode(schema, from: "{}") == Ok("anon")
  assert glon.decode(schema, from: "{\"name\":\"Alice\"}") == Ok("Alice")
}

pub fn field_with_default_with_describe_test() {
  let schema = {
    use port <- glon.field_with_default(
      "port",
      glon.integer() |> glon.describe("Port number"),
      default: 8080,
      encode: json.int,
    )
    glon.success(port)
  }
  assert glon.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"port\":{\"type\":\"integer\",\"description\":\"Port number\",\"default\":8080}}}"
}

// --- Error cases ---

pub fn decode_invalid_json_test() {
  let schema = glon.string()
  let result = glon.decode(schema, from: "{invalid")
  assert result
    |> is_error
}

pub fn decode_wrong_type_test() {
  let schema = glon.string()
  let result = glon.decode(schema, from: "42")
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
  use street <- glon.field(
    "street",
    glon.string() |> glon.describe("Street address"),
  )
  use city <- glon.field("city", glon.string())
  use zip <- glon.optional(
    "zip",
    glon.string() |> glon.describe("ZIP or postal code"),
  )
  glon.success(Address(street:, city:, zip:))
}

fn tag_schema() {
  use key <- glon.field("key", glon.string())
  use value <- glon.field("value", glon.string())
  glon.success(Tag(key:, value:))
}

fn company_schema() {
  use name <- glon.field(
    "name",
    glon.string() |> glon.describe("Legal company name"),
  )
  use founded_year <- glon.field(
    "founded_year",
    glon.integer() |> glon.describe("Year the company was founded"),
  )
  use public <- glon.field(
    "public",
    glon.boolean() |> glon.describe("Whether publicly traded"),
  )
  use rating <- glon.optional_or_null(
    "rating",
    glon.number() |> glon.describe("Rating from 0.0 to 5.0"),
  )
  use address <- glon.field("address", address_schema())
  use tags <- glon.field(
    "tags",
    glon.array(of: tag_schema()) |> glon.describe("Categorization tags"),
  )
  use website <- glon.optional("website", glon.string())
  use phone <- glon.optional_or_null("phone", glon.string())
  glon.success(Company(
    name:,
    founded_year:,
    public:,
    rating:,
    address:,
    tags:,
    website:,
    phone:,
  ))
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
  assert glon.to_string(schema) == expected
}

pub fn complex_decode_full_test() {
  let schema = company_schema()
  let input =
    "{\"name\":\"Acme Corp\",\"founded_year\":1995,\"public\":true,\"rating\":4.5,"
    <> "\"address\":{\"street\":\"123 Main St\",\"city\":\"Springfield\",\"zip\":\"62704\"},"
    <> "\"tags\":[{\"key\":\"industry\",\"value\":\"tech\"},{\"key\":\"size\",\"value\":\"large\"}],"
    <> "\"website\":\"https://acme.example.com\",\"phone\":\"+1-555-0100\"}"
  assert glon.decode(schema, from: input)
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
      tags: [
        Tag(key: "industry", value: "tech"),
        Tag(key: "size", value: "large"),
      ],
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
  assert glon.decode(schema, from: input)
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

// --- Enum schema output ---

pub fn enum_schema_test() {
  let schema = glon.enum(["red", "green", "blue"])
  assert glon.to_string(schema)
    == "{\"type\":\"string\",\"enum\":[\"red\",\"green\",\"blue\"]}"
}

pub type Color {
  Red
  Green
  Blue
}

pub fn enum_map_schema_test() {
  let schema =
    glon.enum_map([#("red", Red), #("green", Green), #("blue", Blue)])
  assert glon.to_string(schema)
    == "{\"type\":\"string\",\"enum\":[\"red\",\"green\",\"blue\"]}"
}

pub fn const_schema_test() {
  let schema = glon.constant("active")
  assert glon.to_string(schema) == "{\"type\":\"string\",\"const\":\"active\"}"
}

pub fn const_map_schema_test() {
  let schema = glon.constant_map("active", True)
  assert glon.to_string(schema) == "{\"type\":\"string\",\"const\":\"active\"}"
}

pub fn enum_with_describe_test() {
  let schema =
    glon.enum(["low", "medium", "high"])
    |> glon.describe("Priority level")
  assert glon.to_string(schema)
    == "{\"type\":\"string\",\"enum\":[\"low\",\"medium\",\"high\"],\"description\":\"Priority level\"}"
}

pub fn nullable_enum_test() {
  let schema = glon.nullable(glon.enum(["a", "b"]))
  assert glon.to_string(schema)
    == "{\"type\":[\"string\",\"null\"],\"enum\":[\"a\",\"b\"]}"
}

// --- Enum decode ---

pub fn decode_enum_valid_test() {
  let schema = glon.enum(["red", "green", "blue"])
  assert glon.decode(schema, from: "\"red\"") == Ok("red")
  assert glon.decode(schema, from: "\"blue\"") == Ok("blue")
}

pub fn decode_enum_invalid_test() {
  let schema = glon.enum(["red", "green", "blue"])
  assert glon.decode(schema, from: "\"yellow\"") |> is_error
}

pub fn decode_enum_map_test() {
  let schema =
    glon.enum_map([#("red", Red), #("green", Green), #("blue", Blue)])
  assert glon.decode(schema, from: "\"red\"") == Ok(Red)
  assert glon.decode(schema, from: "\"green\"") == Ok(Green)
  assert glon.decode(schema, from: "\"blue\"") == Ok(Blue)
}

pub fn decode_enum_map_invalid_test() {
  let schema =
    glon.enum_map([#("red", Red), #("green", Green), #("blue", Blue)])
  assert glon.decode(schema, from: "\"yellow\"") |> is_error
}

pub fn decode_const_test() {
  let schema = glon.constant("active")
  assert glon.decode(schema, from: "\"active\"") == Ok("active")
}

pub fn decode_const_invalid_test() {
  let schema = glon.constant("active")
  assert glon.decode(schema, from: "\"inactive\"") |> is_error
}

pub fn decode_const_map_test() {
  let schema = glon.constant_map("yes", True)
  assert glon.decode(schema, from: "\"yes\"") == Ok(True)
}

// --- Enum in object ---

pub type Task {
  Task(title: String, priority: String)
}

pub fn enum_in_object_test() {
  let schema = {
    use title <- glon.field("title", glon.string())
    use priority <- glon.field("priority", glon.enum(["low", "medium", "high"]))
    glon.success(Task(title:, priority:))
  }
  assert glon.to_string(schema)
    == "{\"type\":\"object\",\"properties\":{\"title\":{\"type\":\"string\"},\"priority\":{\"type\":\"string\",\"enum\":[\"low\",\"medium\",\"high\"]}},\"required\":[\"title\",\"priority\"]}"
  assert glon.decode(
      schema,
      from: "{\"title\":\"Do stuff\",\"priority\":\"high\"}",
    )
    == Ok(Task(title: "Do stuff", priority: "high"))
}

// --- Map tests ---

pub type Email {
  Email(String)
}

pub fn map_schema_test() {
  let schema = glon.string() |> glon.map(Email)
  assert glon.to_string(schema) == "{\"type\":\"string\"}"
}

pub fn decode_map_test() {
  let schema = glon.string() |> glon.map(Email)
  assert glon.decode(schema, from: "\"a@b.com\"") == Ok(Email("a@b.com"))
}

// --- oneOf tests ---

pub type Value {
  TextVal(String)
  NumVal(Int)
  BoolVal(Bool)
}

pub fn one_of_schema_test() {
  let schema =
    glon.one_of([
      glon.string() |> glon.map(TextVal),
      glon.integer() |> glon.map(NumVal),
    ])
  assert glon.to_string(schema)
    == "{\"oneOf\":[{\"type\":\"string\"},{\"type\":\"integer\"}]}"
}

pub fn decode_one_of_first_test() {
  let schema =
    glon.one_of([
      glon.string() |> glon.map(TextVal),
      glon.integer() |> glon.map(NumVal),
    ])
  assert glon.decode(schema, from: "\"hello\"") == Ok(TextVal("hello"))
}

pub fn decode_one_of_second_test() {
  let schema =
    glon.one_of([
      glon.string() |> glon.map(TextVal),
      glon.integer() |> glon.map(NumVal),
    ])
  assert glon.decode(schema, from: "42") == Ok(NumVal(42))
}

pub fn decode_one_of_invalid_test() {
  let schema =
    glon.one_of([
      glon.string() |> glon.map(TextVal),
      glon.integer() |> glon.map(NumVal),
    ])
  assert glon.decode(schema, from: "true") |> is_error
}

// --- anyOf tests ---

pub fn any_of_schema_test() {
  let schema =
    glon.any_of([
      glon.string() |> glon.map(TextVal),
      glon.integer() |> glon.map(NumVal),
    ])
  assert glon.to_string(schema)
    == "{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"integer\"}]}"
}

pub fn decode_any_of_test() {
  let schema =
    glon.any_of([
      glon.string() |> glon.map(TextVal),
      glon.integer() |> glon.map(NumVal),
    ])
  assert glon.decode(schema, from: "\"hi\"") == Ok(TextVal("hi"))
  assert glon.decode(schema, from: "7") == Ok(NumVal(7))
}

// --- tagged_union tests ---

pub type Shape {
  Circle(radius: Float)
  Square(side: Float)
}

pub fn tagged_union_schema_test() {
  let schema =
    glon.tagged_union("type", [
      #("circle", {
        use radius <- glon.field("radius", glon.number())
        glon.success(Circle(radius))
      }),
      #("square", {
        use side <- glon.field("side", glon.number())
        glon.success(Square(side))
      }),
    ])
  assert glon.to_string(schema)
    == "{\"oneOf\":[{\"type\":\"object\",\"properties\":{\"type\":{\"type\":\"string\",\"const\":\"circle\"},\"radius\":{\"type\":\"number\"}},\"required\":[\"type\",\"radius\"]},{\"type\":\"object\",\"properties\":{\"type\":{\"type\":\"string\",\"const\":\"square\"},\"side\":{\"type\":\"number\"}},\"required\":[\"type\",\"side\"]}]}"
}

pub fn decode_tagged_union_first_test() {
  let schema =
    glon.tagged_union("type", [
      #("circle", {
        use radius <- glon.field("radius", glon.number())
        glon.success(Circle(radius))
      }),
      #("square", {
        use side <- glon.field("side", glon.number())
        glon.success(Square(side))
      }),
    ])
  assert glon.decode(schema, from: "{\"type\":\"circle\",\"radius\":5.0}")
    == Ok(Circle(5.0))
}

pub fn decode_tagged_union_second_test() {
  let schema =
    glon.tagged_union("type", [
      #("circle", {
        use radius <- glon.field("radius", glon.number())
        glon.success(Circle(radius))
      }),
      #("square", {
        use side <- glon.field("side", glon.number())
        glon.success(Square(side))
      }),
    ])
  assert glon.decode(schema, from: "{\"type\":\"square\",\"side\":3.0}")
    == Ok(Square(3.0))
}

pub fn decode_tagged_union_invalid_tag_test() {
  let schema =
    glon.tagged_union("type", [
      #("circle", {
        use radius <- glon.field("radius", glon.number())
        glon.success(Circle(radius))
      }),
      #("square", {
        use side <- glon.field("side", glon.number())
        glon.success(Square(side))
      }),
    ])
  assert glon.decode(schema, from: "{\"type\":\"triangle\",\"side\":3.0}")
    |> is_error
}

pub fn tagged_union_with_describe_test() {
  let schema =
    glon.tagged_union("kind", [
      #("text", {
        use content <- glon.field("content", glon.string())
        glon.success(TextVal(content))
      }),
      #("num", {
        use value <- glon.field("value", glon.integer())
        glon.success(NumVal(value))
      }),
    ])
    |> glon.describe("A tagged value")
  assert glon.to_string(schema)
    == "{\"oneOf\":[{\"type\":\"object\",\"properties\":{\"kind\":{\"type\":\"string\",\"const\":\"text\"},\"content\":{\"type\":\"string\"}},\"required\":[\"kind\",\"content\"]},{\"type\":\"object\",\"properties\":{\"kind\":{\"type\":\"string\",\"const\":\"num\"},\"value\":{\"type\":\"integer\"}},\"required\":[\"kind\",\"value\"]}],\"description\":\"A tagged value\"}"
}

pub fn complex_decode_nulls_test() {
  let schema = company_schema()
  let input =
    "{\"name\":\"Null Inc\",\"founded_year\":2010,\"public\":true,"
    <> "\"rating\":null,"
    <> "\"address\":{\"street\":\"0 Zero Rd\",\"city\":\"Nowhere\"},"
    <> "\"tags\":[{\"key\":\"status\",\"value\":\"active\"}],"
    <> "\"phone\":null}"
  assert glon.decode(schema, from: input)
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
