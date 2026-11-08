# NX2navi RX 6800 XT investigation

Project owner and report publisher: **[MitsuSarkar](https://github.com/MitsuSarkar)**.

I put together a local experimental build to investigate crashes, visual artifacts, and growing VRAM use on my RX 6800 XT. This repository shares the findings and test results so the upstream maintainer and other users can evaluate them. The investigation and local implementation were developed with Codex assistance.

**This is a technical report, not a downloadable modified game or an approved NX2navi release.** No upstream source code, game executable, game assets, shader binaries, caches, or saves are included. Original NX2navi development belongs to its upstream authors: [tangerineturtle1/NX2navi](https://github.com/tangerineturtle1/NX2navi).

## Tested baseline

- NX2navi v0.5.0, baseline commit `d0da862c87d1129e5f7fbf171b4bce6e9036f25e`.
- Game version 1.1.1.
- AMD Radeon RX 6800 XT, Ryzen 7 5800X, 32 GB RAM.
- AMD Vulkan driver identifies itself as 26.10.2, proprietary shader compiler.

## What I observed

VRAM use grew from approximately 6 GB to 15.8 GB during play. Some enemy-death effects could trigger a crash when visible; looking away appeared to avoid it. Flickering textures and occasional green blocks were also observed. The exact enemy/location and a controlled death-effect reproduction are not recorded, so these observations are not a complete reproduction procedure.

Two captured crashes faulted inside `amdvlk64.dll`, reading address `0x130`. Mapping the application stack with its executable's symbols located the caller in `gpl_link`, reached from a pipeline worker in one capture. This identifies a pipeline-library linking crash path; it does not establish whether the underlying defect is in the driver or the renderer, nor prove VRAM exhaustion caused it.

## Reproduced shader translation defect

Two shaders in `Layout2Shader/MergeShader.Product.100.Nin_Ounce_NVN2.bfsha.zs` failed lowering with `BRX jump table without a bound` at instruction indices 296 and 281.

The backwards scan looking for the register's defining instruction treated BSSY reconvergence setup as a branch boundary. In these programs, BSSY sits between the index clamp and the table lookup. BSSY does not branch or write the general/uniform index register, so stopping there hides the valid bound.

The local correction passes BSSY during that scan while continuing to stop at actual control-flow branches. Both recovered failures then lowered successfully, and both fully translated modules passed `spirv-val --target-env vulkan1.3`. Offline full translation used default texture answers, not every possible runtime binding state. Negative tests replacing the marker with a real branch still rejected the inferred bound.

This fixes the two specific lowering errors. It has not been demonstrated to fix green world-space fog blocks, texture flicker, or every enemy-death crash.

## Missing shader preparation directory

The fast shader inventory omitted `Layout2Shader/`. It found 36,031 programs, whereas a full scan found 36,176. Adding that directory to the preparation walk recovered the additional 145 programs, including both failing ones. The expanded inventory prepared without translation failures.

## Local memory-retention change

The released-texture cache was bounded by image count and overall VRAM pressure. A count limit does not account for large differences in allocation size.

The experimental change tracks actual allocation bytes and adds a 512 MiB target on the proprietary AMD shader-compiler driver branch. Cleanup considers only released, CPU-backed images whose contents can be reconstructed, excluding GPU-owned/dirty images and images aliasing pool allocations. Retirement is bounded per sweep and remains deferred until GPU use is safe.

**This is not a 512 MiB total VRAM cap, and it is not a proven fix for a leak.** Live images, protected GPU contents, buffers, driver allocations, and allocation blocks are outside that target. A focused RX 6800 XT test verified that an image exceeding a 1 MiB test budget could be retired below the count limit and reconstructed with matching texels. Long-session VRAM stabilization remains unverified.

## Pipeline compatibility and diagnostics

The local build defaults to whole graphics-pipeline creation on the proprietary AMD shader-compiler branch, avoiding the captured library-linking path. This can increase startup time and first-use compilation stalls. It is a compatibility workaround, not a general FPS improvement or proof of crash prevention.

Other local changes preserve failed shader requests for offline reproduction and periodically report texture allocations, buffer mirrors, and deferred retirement totals. An optional managed single-file translator build avoids requiring NativeAOT/MSVC build tools; it introduces JIT/startup overhead and is not a runtime performance optimization.

## Validation and limits

- Two exact recovered shader failures now lower and translate; both modules pass Vulkan 1.3 SPIR-V validation.
- Nine previously working recovered programs still lower.
- All 37,943 copied cached inputs translated with zero failures.
- All 3,716 recorded graphics pipelines built with zero failures or dropped records through the compatibility path.
- Expanded inventory preparation reported zero translation failures, including 88 additional translations not already cached.
- The new GPU eviction/reconstruction regression passed on RX 6800 XT.
- ASTC decoding and BC3 encoding probes passed; the CPU texture-layout probe passed 133 cases.
- Normal startup reached the logo and first movie frame. This is not a gameplay benchmark.
- Some upstream probes remain failing: a memory-limit self-test fails in both the original and local executable; the broader renderer probe needs unavailable fixture files; the upstream memory probe has synthetic-texture/slot-redirection issues; its boot diagnostic uses a stale checkpoint for this game layout.

There is no verified long gameplay benchmark, confirmed complete VRAM-leak repair, or controlled proof that the enemy-death crash has been eliminated. No stable-release claim is made.

## Follow-up VRAM measurements

A later local gameplay log still showed substantial VRAM use. At frame 15,000, the renderer reported:

| Tracked category | MiB |
| --- | ---: |
| Allocator blocks reserved | 11,362 |
| Actual allocations within those blocks | 8,394 |
| Live textures with their own allocation | 4,385 |
| Released textures with their own allocation | 2,669 |
| Buffer mirrors | 840 |

The texture and mirror rows are components of actual allocations; they must not be added to that total again. The roughly 2,968 MiB gap between reserved blocks and allocations may include fragmentation and headroom. It is not all proven reclaimable. These renderer counters do not account for the user's entire approximately 14 GB observation or distinguish all driver and other-process usage.

The retention counter reported only 18.1 MiB retired cumulatively. The 512 MiB target does not force eviction of protected GPU-written contents. Further work should first measure those protected categories, then investigate safe preservation and eviction of GPU contents and allocator fragmentation. Simply reducing the target is not a demonstrated solution. No further memory optimization or lower-VRAM gameplay result has been validated.

## Launcher shortcut

Published by **MitsuSarkar**: [Play-RX6800XT-Fork.cmd](Play-RX6800XT-Fork.cmd). People who already have the compatible local launcher installation can use this file to open it. Download the CMD, place it beside that installation's `NX2navi.exe`, and double-click it. Keep the installation's runtime and other required files in place.

This shortcut only opens the adjacent EXE. It does not download or install the fork, apply GPU optimizations, include game files, or make a standard upstream installation into the experimental RX 6800 XT build.

## Download availability

There is currently **no downloadable fork or executable in this repository**. The local graphical launcher and experimental renderer have not been cleared for redistribution under the upstream additions terms. This report can help other users and maintainers investigate the same symptoms, but it cannot install the local changes. Use [official upstream releases](https://github.com/tangerineturtle1/NX2navi/releases) for publicly available builds.

## Upstream contribution and distribution status

Upstream submission: [issue #115](https://github.com/tangerineturtle1/NX2navi/issues/115), filed by @MitsuSarkar. No pull request has been merged, and no redistribution permission has been granted.

I would like the upstream maintainer to review these findings and consider the narrow BSSY scan fix and missing-directory fix. The memory policy and driver compatibility change need broader review and gameplay testing.

The upstream [LICENSE-ADDITIONS](https://github.com/tangerineturtle1/NX2navi/blob/main/LICENSE-ADDITIONS) reserves rights to its additions and requires written permission for redistribution. That permission has not been obtained. This repository therefore publishes this independently written report and a simple launcher shortcut; it does not distribute the local fork, a source patch, or any game-derived executable/data.

Only the upstream maintainer can decide whether to accept changes into the main project. This report is not affiliated with or endorsed by Nintendo or the NX2navi maintainer.
