PORT :: 8080;
BUFFER_SIZE :: 1024;

Process_Type :: enum {
    PARENT;
    CHILD;
}

main :: () {
    defer { report_memory_leaks(); }
    logger_data := Custom_Logger_Data.{ .PARENT, POSIX.getpid() };
    context.logger = custom_logger;
    context.logger_data = *logger_data;

    master_main_loop();
}

master_main_loop :: () {
    listener_socket_fd := setup_listener(PORT);
    defer POSIX.close(listener_socket_fd);

    // @investigate
    // What happens to memory allocated in the child process?
    // does memory debugger catch them?
    pid := POSIX.fork();
    if pid == {
        case 0;
            logger_data := Custom_Logger_Data.{ .CHILD, POSIX.getpid() };
            context.logger_data = *logger_data;
            worker_main_loop(listener_socket_fd);
            exit(0);
        case -1;
            log_error("fork failed: %", System.get_error_string(POSIX.errno()));
            exit(1);
        case;
            log("I have a baibeeee.... I am gonna call you - %", pid);
            POSIX.waitpid(pid, null, 0);
    }
}

setup_listener :: (port: int) -> s32 {
    listener_socket_fd := Socket.socket(Socket.AF_INET, .STREAM, 0);
    if listener_socket_fd == -1 {
        log_error("socket creation failed: %", System.get_error_string(POSIX.errno()));
        exit(1);
    }

    opt := 1;
    if Socket.setsockopt(listener_socket_fd, Socket.SOL_SOCKET, Socket.SO_REUSEADDR , *opt, size_of(int)) {
        log_error("setsockopt failed: %", System.get_error_string(POSIX.errno()));
        exit(1);
    }

    address := Socket.sockaddr_in.{
        sin_family = Socket.AF_INET,
        sin_addr = Socket.in_addr.{ s_addr = Socket.INADDR_ANY},
        sin_port = Socket.htons(PORT),
    };

    host := "127.0.0.1";
    if Socket.bind(listener_socket_fd, cast(*Socket.sockaddr, *address), size_of(type_of(address))) == -1 {
        log_error("bind failed: %", System.get_error_string(POSIX.errno()));
        exit(1);
    }
    number_of_backlog_connections : s32 = 3;
    if Socket.listen(listener_socket_fd, number_of_backlog_connections) == -1 {
        log_error("listen failed: %", System.get_error_string(POSIX.errno()));
        exit(1);
    }
    log("Listening on port %", PORT);


    return listener_socket_fd;
}

set_nonblocking :: (socket_fd: s32) {
    flags := POSIX.fcntl(socket_fd, POSIX.F_GETFL, 0);
    if flags == -1 {
        log_error("fcntl failed: %", System.get_error_string(POSIX.errno()));
        exit(1);
    }
    if POSIX.fcntl(socket_fd, POSIX.F_SETFL, flags | POSIX.O_NONBLOCK) == -1 {
        log_error("fcntl failed: %", System.get_error_string(POSIX.errno()));
        exit(1);
    }
}

worker_main_loop :: (listener_socket_fd: s32) {
    ev_loop := queue_init();
    log("Event loop initialized: %", ev_loop);
    defer queue_deinit(*ev_loop);

    // @todo - after multiple child processes are created, I need to
    // still figure out if I can can do this on parent process
    // or if I need to do this on each child process
    set_nonblocking(listener_socket_fd);

    data := New(Client_Conn_Acceptor_EData);
    data.* = .{ listener_socket_fd };

    conn_accept_edata := New(Event_Data);
    conn_accept_edata.* = .{ data, connection_acceptor };
    queue_register(*ev_loop, listener_socket_fd, .READ, conn_accept_edata);

    events: [10]Event;
    while true {
        defer {
            // Adding 1 second delay for debugging - remove later
            POSIX.usleep(1000_000);
        }
        log("Polling for events... event_loop: %", ev_loop);
        n_events := queue_poll(ev_loop, *events);
        log("Number of events: %", n_events);
        for event: array_view(events, 0, n_events) {
            event_data: *Event_Data = parse_event_data(*event);
            event_data.callback(*ev_loop, event_data);
        }
    }
}

Client_Conn_Acceptor_EData :: struct {
    // server socket where connection will be accepted
    socket_fd: s32;
}

connection_acceptor :: (ev_loop: *Event_Loop, event_data: *Event_Data) {
    ctx := cast(*Client_Conn_Acceptor_EData, event_data.ctx);
    listener_socket_fd := ctx.*.socket_fd;
    log("Connection acceptor called. fd = %, event_loop: %", listener_socket_fd, ev_loop.*);

    client_addr: Socket.sockaddr_in;
    addr_len: Socket.socklen_t = size_of(Socket.sockaddr_in);

    client_socket_fd := Socket.accept(listener_socket_fd, cast(*Socket.sockaddr, *client_addr), *addr_len);
    if client_socket_fd == -1 {
        log_error("accept failed: %", System.get_error_string(POSIX.errno()));
        return;
    }

    array_add(*ev_loop.registered_fds, client_socket_fd);

    data := New(Client_Request_Reader_EData);
    data.* = .{ client_socket_fd };
    client_req_reader_edata := New(Event_Data);
    client_req_reader_edata.* = .{ data, client_request_read };
    queue_register(ev_loop, client_socket_fd, .READ, client_req_reader_edata);
    log("Accepted connection from %:%", to_string(Socket.inet_ntoa(client_addr.sin_addr)), Socket.ntohs(client_addr.sin_port));
}
Client_Request_Reader_EData :: struct {
    // client socket where data will be read from and written to
    socket_fd: s32;
}

client_request_read :: (ev_loop: *Event_Loop, event_data: *Event_Data)  {
    ctx := cast(*Client_Request_Reader_EData, event_data.ctx);
    client_socket_fd := ctx.*.socket_fd;
    log("Client request reader called: fd = %, event_loop: %", client_socket_fd, ev_loop.*);

    defer {
        log("Cleaning up resources for fd = %", client_socket_fd);
        queue_unregister(ev_loop, client_socket_fd, .READ);
        array_unordered_remove_by_value(*ev_loop.registered_fds, client_socket_fd);
        POSIX.close(client_socket_fd);
    }

    buffer : [BUFFER_SIZE]u8;
    read_count := POSIX.read(client_socket_fd, buffer.data, BUFFER_SIZE -1);
    if read_count == -1 {
        log_error("read failed: %", System.get_error_string(POSIX.errno()));
        return;
    }
    if read_count == 0 {
        log("Client disconnected: %", System.get_error_string(POSIX.errno()));
        return;
    }
    log("Received: %", to_string(buffer.data, read_count));
    hello := "hello";
    if Socket.send(client_socket_fd, hello.data, xx hello.count, 0) == -1 {
        log_error("send failed: %", System.get_error_string(POSIX.errno()));
        return;
    }
    log("Sent: hello");
}

Event_Loop :: struct {
    event_fd: s32;
    registered_fds: [..]s32;
}

Event_Interest :: enum s16 {
    #if OS == {
        case .LINUX;
            READ :: Linux.EPOLLIN | Linux.EPOLLET;
        case .MACOS;
            READ :: MacOS.Kevent_Filter.READ;
        case;
            #assert(false, "Unsupported OS");
    }
}

Event_Data :: struct {
    ctx: *void;
    callback: (event_loop: *Event_Loop, event_data: *Event_Data);
}

#if OS == {
    case .LINUX;
        Event :: Linux.epoll_event;
    case .MACOS;
        Event :: MacOS.Kevent64;
    case;
        #assert(false, "Unsupported OS");
}

queue_init :: () -> Event_Loop {
    return .{ event_fd = _create_queue() };
}

queue_deinit :: (ev: *Event_Loop) {
    #if OS == {
        case .LINUX;
            POSIX.close(ev.event_fd);
        case .MACOS;
            POSIX.close(ev.event_fd);
        case;
            #assert(false, "Unsupported OS");
    }
    free(*ev.registered_fds);
}

queue_register :: (ev: *Event_Loop, which_fd: s32, interest: Event_Interest, event_data: *Event_Data) {
    #if OS == {
        case .LINUX;
            #assert(false, "Not implemented yet");
        case .MACOS;
            changelist: [1]Event = .[
                .{
                    ident = xx which_fd,
                    filter = xx interest,
                    flags = MacOS.Kevent_Flags.ADD | MacOS.Kevent_Flags.ENABLE,
                    fflags = 0,
                    data = 0,
                    udata = cast(*void, event_data),
                }
            ];
            events: [0]Event;
            MacOS.kevent64(ev.event_fd, changelist.data, 1, events.data, 0, .KEVENT_FLAG_NONE, null);
        case;
            #assert(false, "Unsupported OS");
    }
}

queue_unregister :: (ev: *Event_Loop, which_fd: s32, interest: Event_Interest) {
    #if OS == {
        case .LINUX;
            #assert(false, "Not implemented yet");
        case .MACOS;
            changelist: [1]Event = .[
                .{
                    ident = xx which_fd,
                    filter = xx interest,
                    flags = MacOS.Kevent_Flags.DELETE | MacOS.Kevent_Flags.DISABLE,
                    fflags = 0,
                    data = 0,
                    udata = null,
                }
            ];
            events: [0]Event;
            MacOS.kevent64(ev.event_fd, changelist.data,1, events.data,0, .KEVENT_FLAG_NONE,null);
        case;
            #assert(false, "Unsupported OS");
    }
}

parse_event_data :: (event: Event) -> *Event_Data {
    #if OS == {
        case .MACOS;
            event_data := cast(*Event_Data, event.udata);
            return event_data;
        case .LINUX;
            #assert(false, "Not implemented yet");
        case;
            #assert(false, "Unsupported OS");
    }
}

queue_poll :: (ev: Event_Loop, events: *[10]Event) -> int {
    #if OS == {
        case .MACOS;
            n_events := MacOS.kevent64(ev.event_fd, null, 0, events.data, events.count, .KEVENT_FLAG_NONE, null);
            return n_events;
        case .LINUX;
            #assert(false, "Not implemented yet");
        case;
            #assert(false, "Unsupported OS");
    }
}



Posix :: #import "POSIX";
#if OS == {
    case .MACOS;
        MacOS :: #import "MacOS";
    case .LINUX;
        Linux :: #import "Linux";
    case;
}

#scope_file

_create_queue :: () -> s32 {
    #if OS == {
        case .MACOS;
            return MacOS.kqueue();
        case .LINUX;
            return Posix.epoll_create1(0);
        case;
            #assert(false, "Unsupported OS");
    }
}
Custom_Logger_Data :: struct {
    process_type: Process_Type;
    pid: s32;
};

custom_logger :: (message: string, data: *void, info: Log_Info) {
    mark := get_temporary_storage_mark();
    defer   set_temporary_storage_mark(mark);
    using logger_data := cast(*Custom_Logger_Data, data);
    msg := tprint("[%:%] %\n", process_type, pid, message);
    write_string(msg);
}

#import "Basic"()(MEMORY_DEBUGGER=true);
Socket :: #import "Socket";
System :: #import "System";
POSIX :: #import "POSIX";
