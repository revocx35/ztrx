# ztrx on Linux (Wine) with an 8 GB NVIDIA card — what was measured

Everything below was measured on one machine, 2026-11-25: CachyOS, KDE Wayland
(XWayland for the game), RTX 3070 Laptop **8 GB**, 32 GB RAM, wine from
GE-Proton10-34, vkd3d-proton **3.2.0** (`d3d12.dll`/`d3d12core.dll` from
GE-Proton11-14) and DXVK 3.1.1 `dxgi.dll` beside `victory.exe`, test data set.

## Launcher

```bash
export VICTORY_SHADER_LOOP_LIMIT=256                 # see "the intro" below
export VICTORY_RELAY=2 VICTORY_LATE_WAIT=3
export VICTORY_WIDE_BACK=1 VICTORY_TEXTURE_NO_WAIT=1 # 8 GB settings, issues #95/#62
victory.exe run '<game>\game_scarlett_master.exe' --execute
```

## The intro: 5.1 s of GPU time per frame at the default loop cap

The cinematic looked like a white screen that jumped back and forth, with the
audio dropping out in growing gaps. The log splits the frame time:

```
0.2 fps, 5116.8 ms/frame (0.1 preparing: copies 0.2 ms 0.1 MB, textures 0.0 ms 0.0 MB;
                          5116.2 on the GPU; ...), 13 draws/frame
```

Not copies, not CPU — five seconds of GPU time for 13 draws. That is the 2^20
per-lane shader loop cap on a 3070.

With `VICTORY_SHADER_LOOP_LIMIT=256` the same frames run:

```
30.0 fps, 33.3 ms/frame (... 4.4 on the GPU ...), 13 draws/frame
```

A 1,000x difference on the same scene. Because the title advances audio per
frame, the 5 s frames were also what starved the audio: the gap grew every
frame until nothing played. The audio modules are not the cause.

256 is a starting point, not a measurement of what the scene needs: a cap that
is too low truncates loops the title relies on (fog, foliage, hair, volumetric
work). Raise it (1024/4096) while the frame still fits in 33 ms.

## The host pipeline library (#1722): pipelines were never kept

`make(&[])` passes an empty Rust slice — a dangling, non-null pointer with
length 0. Windows reads only the length; vkd3d-proton refuses a non-null
zero-length blob with `E_INVALIDARG`, so every run logged

```
INFO victory_gpu::pipeline::library: no host pipeline library: pipelines are not kept
```

and wrote neither `host-pipelines.bin` nor `early-pipelines.txt`: the next run
prebuilt nothing and the first pass through a scene translated everything again
(8-22 s frames through the intro). This fork asks for the empty library through
the vtable with a null pointer and length 0; the same run then logs

```
INFO victory_gpu::pipeline::library: host pipeline library loaded bytes=101816
```

and the intro's worst frame fell to 2.2 s, once, then 30 fps.

## NVIDIA presentation wedges after GPU faults

At world entry the driver took `Xid 13` MMU faults repeatedly (25 in one run).
After enough of them, every later run failed with
`Failed to create swapchain, vr -3` (VK_ERROR_INITIALIZATION_FAILED) at any
size, present mode, wine version or prefix, while the game kept rendering
internally. Nothing short of a reboot cleared it. Check
`journalctl -k --since "-10 min" | grep -c Xid` before blaming the swapchain.

## Where ztrx sits against upstream (2026-11-25)

- ztrx's tree is a single squashed commit on upstream `8e79c80`; it is **532
  commits behind** `main` (`940d32f`).
- Replaying ztrx's ~40k-line delta onto `main` produced **86 conflicting
  files**, mostly in `victory-gpu`.
- Stock upstream on this machine is *worse*: it asserts in
  `vkCreateComputePipelines` (`winevulkan/loader_thunks.c:3151`) at world entry
  and exits 3 with vkd3d-proton 3.2.0.
- The audio modules (`audio.rs`, `apu.rs`, `media.rs`) were therefore taken from
  upstream wholesale (seven XMA/media fixes, see the commit); they compile
  against this tree unchanged.

## Still open

- Voices: the audio fixes above did not bring dialogue back on this machine; the
  dropouts that remain are the frame-time starvation, not the decode path.
- The intro's Bink video at 30 fps was not visually confirmed end to end: the
  screen was captured over XWayland and the run was interrupted.
- `VICTORY_CAPTURE` (in-engine frame capture) produced no files here even in a
  diagnostics build; `victory-hle`'s `diagnostics` feature does enable
  `victory-gpu/diagnostics`, so the cause is elsewhere in the present path.
- The world itself (prologue) was not reached in these runs on 8 GB.
