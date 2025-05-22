module.exports = grammar({
    name: "jai",

    extras: $ => [
        /\s/,
        $.comment,
    ],

    conflicts: $ => [
        [$._expression, $.function_call],
        [$.for_statement],
        [$.binary_expression, $.range_expression],
        [$.unary_expression, $.range_expression],
    ],

    word: $ => $.identifier,

    rules: {
        source_file: $ => repeat($._definition),

        comment: $ => token(choice(
            seq('//', /.*/),
            seq(
                '/*',
                /[^*]*\*+([^/*][^*]*\*+)*/,
                '/'
            )
        )),

        _definition: $ => choice(
            $.function_definition,
            $.struct_definition,
            $.enum_definition,
            $.variable_definition,
            $.comment,
            $.directive,
            $.import_directive
        ),

        directive: $ => seq(
            '#',
            $.identifier
        ),

        import_directive: $ => seq(
            choice('#import', '#load'),
            '"',
            field("path", $.string_content),
            '"',
            optional(';')
        ),

        string_content: $ => /[^"]*/,

        function_definition: $ => seq(
            field("name", $.identifier),
            '::',
            $.parameter_list,
            optional(field("return_type", seq('->', $._type))),
            field("body", $.block)
        ),

        struct_definition: $ => seq(
            field("name", $.identifier),
            '::',
            'struct',
            field("body", $.struct_body)
        ),

        struct_body: $ => seq(
            '{',
            repeat($.struct_field),
            '}'
        ),

        struct_field: $ => seq(
            field("name", $.identifier),
            ':',
            field("type", $._type),
            optional(seq('=', field("default_value", $._expression))),
            ';'
        ),

        enum_definition: $ => seq(
            field("name", $.identifier),
            '::',
            'enum',
            optional(field("type", $.identifier)),
            field("body", $.enum_body)
        ),

        enum_body: $ => seq(
            '{',
            repeat($.enum_value),
            '}'
        ),

        enum_value: $ => seq(
            field("name", $.identifier),
            optional(seq('=', field("value", $._expression))),
            optional(';')
        ),

        variable_definition: $ => seq(
            field("name", $.identifier),
            choice(
                seq(
                    ':',
                    choice(
                        seq(
                            field("type", $._type),
                            '=',
                            field("value", $._expression),
                        ),
                        seq(
                            '=',
                            field("value", $._expression),
                        ),
                        field("type", $._type),
                    )
                ),
                seq(
                    '::',
                    field("value", $._expression),
                )
            ),
            optional(';')
        ),

        parameter_list: $ => seq(
            '(',
            optional(seq(
                $.parameter,
                repeat(seq(',', $.parameter))
            )),
            ')'
        ),

        parameter: $ => seq(
            field("name", $.identifier),
            ':',
            field("type", $._type)
        ),

        _type: $ => choice(
            // Basic types
            'bool',
            'string',
            'int',
            'float',
            'float64',
            'float32',
            's64',
            's32',
            's16',
            's8',
            'u64',
            'u32',
            'u16',
            'u8',
            'void',
            // User-defined types
            $.identifier,
            // Type with member
            $.member_type,
            // Array types
            seq('[', optional($._expression), ']', $._type),
            // Pointer types
            seq('*', $._type)
        ),
        
        member_type: $ => seq(
            $.identifier,
            '.',
            $.identifier
        ),

        block: $ => seq(
            '{',
            repeat($._statement),
            '}'
        ),

        _statement: $ => choice(
            $.return_statement,
            $.if_statement,
            $.for_statement,
            $.while_statement,
            $._definition,
            $.expression_statement
        ),

        return_statement: $ => seq(
            'return',
            optional($._expression),
            ';'
        ),

        if_statement: $ => seq(
            'if',
            field("condition", $._expression),
            field("then_branch", $.block),
            optional(seq('else', field("else_branch", choice($.block, $.if_statement))))
        ),

        for_statement: $ => prec.right(seq(
            'for',
            choice(
                // Traditional for loop
                seq(
                    field("initializer", optional($._expression)),
                    optional(seq(field("condition", $._expression))),
                    optional(seq(field("update", $._expression)))
                ),
                // For-in loop (for i: 0..5)
                seq(
                    field("iterator", $.identifier),
                    ':',
                    field("range", $._expression)
                ),
                // For-with-condition
                field("condition", $._expression)
            ),
            field("body", $.block)
        )),

        while_statement: $ => seq(
            'while',
            field("condition", $._expression),
            field("body", $.block)
        ),

        expression_statement: $ => seq(
            choice(
                $._expression,
                $.assignment_expression
            ),
            ';'
        ),

        _expression: $ => choice(
            $.identifier,
            $.number,
            $.float,
            $.string,
            $.boolean,
            $.null,
            $.function_call,
            $.binary_expression,
            $.unary_expression,
            $.parenthesized_expression,
            $.member_access,
            $.range_expression
        ),
        
        assignment_expression: $ => seq(
            field("left", choice(
                $.identifier,
                $.member_access
            )),
            field("operator", choice(
                '=',
                '+=',
                '-=',
                '*=',
                '/=',
                '%='
            )),
            field("right", $._expression)
        ),

        function_call: $ => prec(5, seq(
            field("function", $.identifier),
            field("arguments", $.argument_list)
        )),

        argument_list: $ => seq(
            '(',
            optional(seq(
                $._expression,
                repeat(seq(',', $._expression))
            )),
            ')'
        ),

        binary_expression: $ => prec.left(1, seq(
            field("left", $._expression),
            field("operator", choice(
                '+', '-', '*', '/', '%',
                '==', '!=', '<', '<=', '>', '>=',
                '&&', '||', '&', '|', '^', '<<', '>>'
            )),
            field("right", $._expression)
        )),

        unary_expression: $ => prec.right(3, seq(
            field("operator", choice('-', '!', '~', '*', '&')),
            field("argument", $._expression)
        )),

        parenthesized_expression: $ => seq(
            '(',
            $._expression,
            ')'
        ),

        identifier: $ => /[a-zA-Z_]\w*/,
        number: $ => /\d+/,
        float: $ => /\d+\.\d+/,
        string: $ => seq('"', optional($.string_content), '"'),
        
        member_access: $ => prec(6, seq(
            field("object", $._expression),
            '.',
            field("property", $.identifier)
        )),
        
        range_expression: $ => prec.right(2, seq(
            $._expression,
            '..',
            $._expression
        )),
        boolean: $ => choice('true', 'false'),
        null: $ => 'null'
    }
});