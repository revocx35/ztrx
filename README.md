# ztrx

**ztrx** runs the Xbox Series build of the game natively on Windows PCs with
NVIDIA graphics cards, from game files you supply yourself.

**This repository contains no game files or assets.** You need your own copy
of the game. Not affiliated with or endorsed by its developer or publisher.

## Status (2026-11-25)

Tested on Windows 11 with an **NVIDIA GeForce RTX 3050** (8 GB):

| | |
|---|---|
| Boot, first-boot screens, intro, opening credits | works |
| Prologue | playable from the cell to the boat chase: cell, cafeteria, robbery, police chase (wanted level, minimap), boat, binoculars |
| Stability | 1 h 30 min+ in one session without a crash |
| Frame rate | 1-3 fps in the world (the first run is slower while shaders translate; they are cached after that) |
| Known problems | anything in shadow is black and bright scenes overexpose (the game's ray-traced lighting does not run yet); some blocky artifacts; boats sit low in the water |

## Requirements

- Windows 10/11 x64, a CPU with AVX2
- A Direct3D 12 GPU with shader model 6.6 and mesh shaders (NVIDIA RTX 20 series or newer)
- Rust (the version in `rust-toolchain.toml`)
- Several GB of free Windows commit memory (raise the paging file if `crashes.log` reports error 1455)

## Build

```powershell
cargo build --release -p victory
```

## Play

```powershell
powershell -ExecutionPolicy Bypass -File scripts\play.ps1 -Game "<your game folder>\<the game's exe>"
```

`scripts\play.ps1` keeps the shader cache and saves in folders you choose
(`-Cache`, `-Data`) and presses no buttons for you. Controller: XInput pads
(a DualShock/DualSense through DS4Windows works). With no pad connected the
keyboard acts as one while the game window has focus.

## Faster settings (optional, off by default)

`VICTORY_RELAY=2`, or `VICTORY_LATE_WAIT=3 VICTORY_WIDE_BACK=1` cut frame
time on the test machines. Set them in PowerShell before running the script.

## Linux (Wine) on an 8 GB NVIDIA card

Measured on an RTX 3070 Laptop 8 GB, CachyOS, KDE Wayland: wine from
GE-Proton10-34, vkd3d-proton 3.2.0 (`d3d12.dll`/`d3d12core.dll` from
GE-Proton11-14) and DXVK 3.1.1 `dxgi.dll` beside `victory.exe`, on XWayland.

- Settings used: `VICTORY_RELAY=2 VICTORY_LATE_WAIT=3 VICTORY_WIDE_BACK=1`
  `VICTORY_TEXTURE_NO_WAIT=1`.
- Microsoft's `d3dcompiler_47.dll` in the prefix (`winetricks d3dcompiler_47`):
  with Wine's built-in one the indirect-argument clamp does not compile and
  every indirect execution is dropped.
- vkd3d-proton older than the November build crashes the NVIDIA shader
  compiler in `vkCreateComputePipelines` at world entry; 3.2.0 does not.
- `VICTORY_SHADER_LOOP_LIMIT=256` matters more than any other knob here: with the
  default 2^20 per-lane loop cap the intro cinematic's frames took **5.1 s of GPU
  time each** (13 draws, 0.2 fps, white screen, audio dropping out in growing
  gaps because audio is advanced per frame). At 256 the same frames run 33 ms
  (30 fps, 4.4 ms on the GPU).
- Result here: first-boot screens and menus at 30 fps, worst frame 2.2 s once
  (the intro), then 30 fps, with a warm shader cache and pipeline library.
  Before the pipeline-library fix below the same run sat at 0.1 fps with 8-22 s
  frames through the intro.

## Debugging switches

| Switch | Effect |
|---|---|
| `VICTORY_CAPTURE=<dir>` + `VICTORY_CAPTURE_FRAMES=<list>` | save those frames as PNG (diagnostics build) |
| `VICTORY_KEYS=30:Enter,35:X` | press keys at those seconds (diagnostics build) |
| `VICTORY_D3D12_DRED=1` | on a GPU failure, report the commands in flight |
| `VICTORY_PIPELINE_WAIT_MS=24` | shorter per-frame wait for pipelines still being built |

Diagnostics build: `cargo build --profile diag -p victory --features diagnostics`

## License

GPL-3.0-or-later (see `LICENSE`). Based on VIctory (Marvisak) and victory-fork (fxceless).
