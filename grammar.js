module.exports = grammar({
  name: "jai",

  extras: ($) => [/\s/, $.comment],

  // @todo
  // fix these conflicts later - maybe I can refactor the grammar to not have conflicts
  conflicts: ($) => [
    [$.struct_body, $.enum_body],
    [$.assignment_expression, $.variable],
    [$.proc_call_expr, $.enum_value_expr],
    [$.proc_call_expr, $.enum_value_expr, $._expression, $.struct_literal_expr],
    [$.proc_call_expr, $._expression],
    [$.if_statement, $.parenthesized_expression],
    [$._statement, $.if_statement],
    [$.parameter, $._expression],
    [$.assignment_expression, $._expression],
    [$.proc_call_expr, $.enum_value_expr, $.struct_literal_expr],
    [$.enum_value_expr, $.struct_literal_expr],
    [$.case_statement, $._expression],
    [$.argument_list, $._expression],
    [
      $.proc_call_expr,
      $._expression,
      $.dereference,
      $.enum_value_expr,
      $.struct_literal_expr,
    ],
  ],

  word: ($) => $.identifier,
  rules: {
    source_file: ($) => repeat($._definition),

    _definition: ($) =>
      choice(
        $.import_directive,
        $.proc_definition,
        $.struct_definition,
        $.enum_definition,
        $.constant,
        $.variable,
        $.scope_module,
        $.scope_file,
        $.scope_export,
      ),
    scope_module: ($) => seq("#scope_module", optional(";")),
    scope_file: ($) => seq("#scope_file", optional(";")),
    scope_export: ($) => seq("#scope_export", optional(";")),

    struct_definition: ($) =>
      seq(
        field("name", $.identifier),
        "::",
        "struct",
        field("body", $.struct_body),
        optional(";"),
      ),
    struct_body: ($) => seq("{", optional(repeat($.struct_field)), "}"),
    struct_field: ($) =>
      seq(
        field("name", $.identifier),
        ":",
        field("type", $._type),
        optional(seq("=", field("default_value", $._expression))),
        optional(","),
        ";",
      ),

    enum_definition: ($) =>
      seq(
        field("name", $.identifier),
        "::",
        choice("enum", "enum_flags"),
        optional($.directive),
        field("body", $.enum_body),
        optional(";"),
      ),
    enum_body: ($) => seq("{", repeat($.enum_values), "}"),
    enum_values: ($) =>
      seq(
        field("name", $.identifier),
        optional(seq("::", field("value", $._expression))),
        ";",
      ),

    proc_definition: ($) =>
      seq(
        field("name", $.identifier),
        "::",
        $.parameter_list,
        optional($.proc_return_expr),
        optional(repeat($.directive)),
        $.block,
      ),
    parameter_list: ($) =>
      seq("(", optional(seq($.parameter, repeat(seq(",", $.parameter)))), ")"),

    proc_return_expr: ($) =>
      seq(
        "->",
        optional("("),
        optional(
          seq(
            $.proc_return_type_expr,
            repeat(seq(",", $.proc_return_type_expr)),
          ),
        ),
        optional(")"),
      ),

    proc_return_type_expr: ($) =>
      choice(
        field("type", $._type),
        seq(
          field("name", $.identifier),
          ":",
          field("type", $._type),
          optional(seq("=", field("default_value", $._expression))),
        ),
      ),

    block: ($) => seq("{", repeat($._statement), "}"),

    _statement: ($) =>
      choice(
        $.return_statement,
        $.if_statement,
        $.if_case,
        $.for_statement,
        $.while_statement,
        $.case_statement,
        $.break_statement,
        $.continue_statement,
        seq($.directive, ";"),
        $.constant,
        $.variable,
        $.expr_stmt,
        $.defer_statement,
        $.using_statement,
        $.insert_directive,
        $.assert_directive,
      ),
    case_statement: ($) =>
      seq(
        "case",
        optional(field("directive", $.directive)),
        optional($._expression),
        ";",
      ),
    break_statement: ($) => seq("break", optional(seq(":", $.identifier)), ";"),
    continue_statement: ($) => seq("continue", ";"),

    while_statement: ($) =>
      seq(
        "while",
        optional(seq($.identifier, ":")),
        field("condition", $._expression),
        choice(field("body", $.block), field("body", $._statement)),
      ),
    for_statement: ($) =>
      prec.right(
        seq(
          "for",
          optional(seq($.identifier, ":")),
          $._expression,
          choice(field("body", $.block), field("body", $._statement)),
        ),
      ),

    if_case: ($) =>
      seq(
        choice("if", "#if"),
        field("condition", $._expression),
        "==",
        $.block,
      ),

    if_statement: ($) =>
      prec.right(
        seq(
          choice("if", "#if"),
          optional("("),
          field("condition", $._expression),
          optional(")"),
          optional("then"),
          choice(
            field("then_branch", $.block),
            field("then_branch", $._statement),
          ),
          optional(
            seq(
              "else",
              field(
                "else_branch",
                choice($.block, $.if_statement, $._statement),
              ),
            ),
          ),
        ),
      ),
    ifx_expr: ($) =>
      prec.right(
        1,
        seq(
          field("keyword", "ifx"),
          optional("("),
          field("condition", $._expression),
          optional(")"),
          optional(field("keyword", "then")),
          choice(field("then_branch", $._expression)),
          optional(seq("else", field("else_branch", choice($._expression)))),
        ),
      ),
    using_statement: ($) => seq("using", $._statement),

    return_statement: ($) =>
      seq(
        "return",
        optional(
          choice(
            $._expression,
            seq($._expression, repeat(seq(",", $._expression))),
            seq($.named_return_expr, repeat(seq(",", $.named_return_expr))),
          ),
        ),
        ";",
      ),
    named_return_expr: ($) =>
      seq(field("name", $.identifier), "=", $._expression),

    expr_stmt: ($) => seq(choice($._expression, $.assignment_expression), ";"),
    assignment_expression: ($) =>
      seq(
        field(
          "left",
          choice(
            seq($.identifier, optional(seq(":", $._type))),
            $.member_access_expr,
            $.dereference,
          ),
        ),
        optional(
          seq(
            field("operator", choice("=", "+=", "-=", "*=", "/=", "%=")),
            field("right", $._expression),
          ),
        ),
      ),
    defer_statement: ($) => seq("defer", choice($.expr_stmt, $.block)),

    proc_call_expr: ($) =>
      seq(
        optional(repeat(seq(field("object", $.identifier), "."))),
        field("function", $.identifier),
        field("arguments", $.argument_list),
      ),
    argument_list: ($) =>
      seq(
        "(",
        choice(
          optional(
            seq(
              $._expression,
              repeat(choice(seq(",", $._expression), seq("..", $.identifier))),
            ),
          ),
          seq("..", $.identifier),
        ),
        ")",
      ),

    _type: ($) =>
      prec(
        10,
        choice(
          // Basic types
          "bool",
          "string",
          "int",
          "float",
          "float64",
          "float32",
          "s64",
          "s32",
          "s16",
          "s8",
          "u64",
          "u32",
          "u16",
          "u8",
          "void",
          "Any",
          "Type",
          "Context",
          // User-defined types
          $.identifier,
          // Array types
          seq("[", choice(optional($._expression), ".."), "]", $._type),
          // Pointer types
          seq("*", $._type),
        ),
      ),

    constant: ($) =>
      choice(
        seq($.identifier, "::", $._expression, ";"),
        seq($.identifier, ":", $._type, ":", $._expression, ";"),
        seq($.identifier, "::", $.code_directive),
      ),
    code_directive: ($) => seq(field("name", "#code"), $.block),
    insert_directive: ($) => seq("#insert", $.identifier, ";"),
    assert_directive: ($) =>
      seq("#assert", field("arguments", $.argument_list), ";"),
    variable: ($) =>
      choice(
        seq($.identifier, ":=", $._expression, ";"),
        seq($.identifier, ":", $._type, "=", $._expression, ";"),
      ),
    parameter: ($) =>
      choice(
        seq(
          optional($.using),
          optional("$"),
          field("name", $.identifier),
          ":",
          optional("$"),
          field("type", $._type),
          optional(seq("=", $._expression)),
        ),
        seq(field("name", $.identifier), ":", "..", field("type", $._type)),
      ),

    import_directive: ($) =>
      seq(
        optional(seq(field("name", $.identifier), "::")),
        choice("#import", "#load"),
        '"',
        field("path", $.string_content),
        '"',
        optional(seq("(", ")")),
        optional(seq("(", $.identifier, "=", $._expression, ")")),
        ";",
      ),
    comment: ($) =>
      token(
        choice(seq("//", /.*/), seq("/*", /[^*]*\*+([^/*][^*]*\*+)*/, "/")),
      ),

    _expression: ($) =>
      choice(
        $.identifier,
        $.number,
        $.float,
        $.string,
        $.boolean,
        $.null,
        $.proc_call_expr,
        $.binary_expression,
        $.unary_expression,
        $.parenthesized_expression,
        $.struct_literal_expr,
        $.enum_value_expr,
        $.member_access_expr,
        $.range_expr,
        $.undefined,
        $.dereference,
        $.auto_cast_expr,
        $.array_access,
        $.ifx_expr,
      ),
    array_access: ($) => seq($.identifier, "[", $._expression, "]"),
    auto_cast_expr: ($) => seq("xx", $._expression),
    dereference: ($) => seq($.identifier, ".", "*"),
    undefined: ($) => "---",
    range_expr: ($) => prec.right(2, seq($._expression, "..", $._expression)),
    member_access_expr: ($) =>
      prec(
        6,
        seq(
          field("object", $._expression),
          ".",
          field("property", $.identifier),
        ),
      ),
    enum_value_expr: ($) =>
      choice(
        seq($.identifier, ".", $.identifier),
        seq(".", field("name", $.identifier)),
      ),
    struct_literal_expr: ($) =>
      seq(
        optional(seq($.identifier, repeat(seq(".", $.identifier)))),
        ".",
        "{",
        optional(
          choice(
            $.struct_initialize_with_field,
            seq($.struct_initialize_without_field),
          ),
        ),
        "}",
        // @todo - this get picked up by variable so it has conflict
        // maybe I need to construct this grammer differently so they don't have conflict
        // ";",
      ),
    struct_initialize_without_field: ($) =>
      seq($._expression, repeat(seq(",", $._expression))),
    struct_initialize_with_field: ($) =>
      seq(
        $.identifier,
        "=",
        $._expression,
        repeat(seq(",", seq($.identifier, "=", $._expression))),
        optional(","),
      ),

    binary_expression: ($) =>
      prec.left(
        1,
        seq(
          field("left", $._expression),
          field(
            "operator",
            choice(
              "+",
              "-",
              "*",
              "/",
              "%",
              "==",
              "!=",
              "<",
              "<=",
              ">",
              ">=",
              "&&",
              "||",
              "&",
              "|",
              "^",
              "<<",
              ">>",
            ),
          ),
          field("right", $._expression),
        ),
      ),

    unary_expression: ($) =>
      prec.right(
        3,
        seq(
          field("operator", choice("-", "!", "~", "*", "&")),
          field("argument", $._expression),
        ),
      ),

    parenthesized_expression: ($) => seq("(", $._expression, ")"),

    directive: ($) => seq("#", $.identifier),
    using: ($) => "using",
    string_content: ($) => token(/([^"\\]|\\.)*/),
    identifier: ($) => /[a-zA-Z_]\w*/,
    number: ($) => /[\d_]+/,
    float: ($) => /\d+\.\d+/,
    string: ($) => seq('"', optional($.string_content), '"'),
    boolean: ($) => choice("true", "false"),
    null: ($) => "null",
  },
});
