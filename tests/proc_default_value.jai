proc_default_no_type :: (x := 10) {}
proc :: (x: u32 = 10) {}
proc2 :: (x: string = "asf"){}

main :: () {
    proc();
    proc2();
    print("Done with default values");
}
