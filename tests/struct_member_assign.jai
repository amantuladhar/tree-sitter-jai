Foo_Style :: struct {
    foo.bar2 = "_";
    foo.bar1 = 4;

    struct_printer: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool;
    struct_printer_data: *void;

    // This is a worker variable used by Print. You probably don't
    // want to change it!
    indentation_depth: s32;

    log_runtime_errors := true;
}

assert_helper :: (message := "", args: .. Any, loc := #caller_location) -> bool {
}
