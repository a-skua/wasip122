use clap::Parser;
use wasi_preview1_component_adapter_provider::{
    WASI_SNAPSHOT_PREVIEW1_ADAPTER_NAME, WASI_SNAPSHOT_PREVIEW1_COMMAND_ADAPTER,
};
use wit_component::ComponentEncoder;

#[derive(Parser, Debug)]
struct Wasm {
    #[arg(short, long)]
    output: String,
    #[arg()]
    input: String,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let wasm = Wasm::parse();

    let wasm_p1_bytes = std::fs::read(wasm.input)?;

    let wasm_p2_bytes = ComponentEncoder::default()
        .module(&wasm_p1_bytes)?
        .adapter(
            WASI_SNAPSHOT_PREVIEW1_ADAPTER_NAME,
            WASI_SNAPSHOT_PREVIEW1_COMMAND_ADAPTER,
        )?
        .validate(true)
        .encode()?;

    std::fs::write(wasm.output, wasm_p2_bytes)?;

    Ok(())
}
