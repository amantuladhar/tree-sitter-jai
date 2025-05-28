#if OS == {
    case .MACOS;
        MacOS :: #import "MacOS";
    case .LINUX;
        Linux :: #import "Linux";
    case;
}

test :: () {
    #if OS == {
        case .LINUX;
            POSIX.close(ev.evl_queue_fd);
        case .MACOS;
            POSIX.close(ev.evl_queue_fd);
        case;
            #assert(false, "Unsupported OS");
    }

    min   := ifx size < reader.buffer.count - reader.read_pos then size
            else reader.buffer.count - reader.read_pos;
}
