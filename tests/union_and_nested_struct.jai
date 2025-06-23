// tree-sitter generate && tree-sitter parse tests/union_and_nested_struct.jai
Instruction_Tacky :: struct {
    type: Instruction_Type_Tacky;
    as : union {
        ret: Val_Tacky;
        unary: struct { op: Unary_Op_Type_Tacky; src: Val_Tacky; dst: Val_Tacky; };
    };
}
