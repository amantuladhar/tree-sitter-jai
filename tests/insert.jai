read_until :: (using reader: *Socket_Reader, delimiter: u8, $max_count: u16 = 4096) -> success: bool = true, bytes: []u8 {

    return_if_delimiter_found :: #code {
        for read_pos..buffer.count - 1 {
            if buffer[it] == delimiter {
                bytes := array_view(buffer, read_pos, (it + 1) - reader.read_pos);
                reader.read_pos = xx (it + 1);
                return success = true, bytes = bytes;
            }
        }
    }

    #insert return_if_delimiter_found;

    local_read_count : u16 = 0;

    while true {
        #insert return_if_delimiter_found;
    }
}
