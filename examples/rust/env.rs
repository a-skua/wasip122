fn main() {
    let env = std::env::vars().collect::<Vec<(String, String)>>();
    println!("{env:?}");
}
