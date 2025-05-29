to_string :: inline (s: *u8, length: s64) -> string {  // We should probably deprecate this in favor of your using string.{...}?
    if !s return "";

    result: string = ---;
    result.count = length;
    result.data  = s;
    return result;
}
