external clock_linux_get_time : unit -> int64 = "clock_linux_get_time"

let get () = clock_linux_get_time ()
