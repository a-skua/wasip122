fn main() {
    let args = std::env::args()
        .skip(1)
        .collect::<Vec<_>>();

    println!("Hello, world!");
    println!("Arguments: {:?}", args);
}
