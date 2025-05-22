// This is a simple Jai test file to verify syntax highlighting

// Import directives
#import "Basic";
#import "Math";

// Constants
PI :: 3.14159;
VERSION :: "1.0.0";

// Simple function definition
add :: (a: int, b: int) -> int {
    return a + b;
}

// Function with no return type
print_hello :: () {
    print("Hello, Jai!");
}

// Struct definition
Vector2 :: struct {
    x: float;
    y: float;
    
    // Default value
    initialized: bool = false;
}

// Enum definition
Direction :: enum {
    North;
    East;
    South;
    West;
}

// Enum with specified values
ErrorCode :: enum u16 {
    Success = 0;
    InvalidArgument = 1;
    FileNotFound = 404;
}

// Main function
main :: () {
    // Variable declarations
    a: int = 10;
    b := 20;
    result := add(a, b);
    
    // Conditional
    if result > 25 {
        print("Result is large!");
    } else {
        print("Result is small.");
    }
    
    // Loop
    for i: 0..5 {
        print("Loop iteration: %", i);
    }
    
    // While loop
    count := 0;
    while count < 3 {
        print("Count: %", count);
        count += 1;
    }
    
    // Create struct instance
    position: Vector2;
    position.x = 10.5;
    position.y = 20.7;
    position.initialized = true;
    
    // Using enum
    current_direction := Direction.North;
    
    if current_direction == Direction.North {
        print("Going north!");
    }
}