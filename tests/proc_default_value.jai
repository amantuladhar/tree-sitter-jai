proc_default_no_type :: (x := 10) {}
assert_helper :: (message := "") -> bool {}
assert_helper2 :: (message := "", args: .. Any, loc := #caller_location) -> bool {}
proc :: (x: u32 = 10) {}
proc2 :: (x: string = "asf"){}

main :: () {
    proc();
    proc2();
    print("Done with default values");
}
