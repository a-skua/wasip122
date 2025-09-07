use clap::Parser;
use wit_component::ComponentEncoder;

#[derive(Parser, Debug)]
struct Wasm {
    #[arg(short, long)]
    output: String,
    #[arg()]
    input: String,
    #[arg(long, help = "Path to custom WASI adapter")]
    adapter: Option<String>,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let wasm = Wasm::parse();

    let wasm_p1_bytes = std::fs::read(wasm.input)?;

    let mut encoder = ComponentEncoder::default();
    encoder = encoder.module(&wasm_p1_bytes)?;

    if let Some(adapter_path) = wasm.adapter {
        // Use custom adapter
        let adapter_bytes = std::fs::read(adapter_path)?;
        encoder = encoder.adapter("wasi_snapshot_preview1", &adapter_bytes)?;
    } else {
        // Use default adapter
        use wasi_preview1_component_adapter_provider::{
            WASI_SNAPSHOT_PREVIEW1_ADAPTER_NAME, WASI_SNAPSHOT_PREVIEW1_COMMAND_ADAPTER,
        };
        encoder = encoder.adapter(
            WASI_SNAPSHOT_PREVIEW1_ADAPTER_NAME,
            WASI_SNAPSHOT_PREVIEW1_COMMAND_ADAPTER,
        )?;
    }

    let wasm_p2_bytes = encoder.validate(true).encode()?;

    std::fs::write(wasm.output, wasm_p2_bytes)?;

    Ok(())
}
