# AMD enemy-effect crash workaround and pipeline preparation

Published by **MitsuSarkar**, investigated and documented with Codex assistance. Tested locally on November 10, 2026 with NX2navi 0.6.1, RX 6800 XT, Ryzen 7 5800X and 32 GB RAM. This is a configuration workaround for an existing installation, not a modified executable or an official release.

## Symptoms and evidence

Some enemy deaths caused access violations in AMD's Vulkan driver, `amdvlk64.dll`. Several captured sessions had graphics pipeline libraries enabled. Setting `gpl = 0` stopped the reported enemy-death crashes in the owner's subsequent play, but this is not a controlled guarantee for all enemies or GPUs. A driver-module fault alone does not establish whether the underlying bug belongs to the driver or the application's Vulkan usage.

Disabling GPL can make new graphics pipelines slower to compile. A later log showed a 3,076.8 ms frame with 2,434.2 ms spent building pipelines. Importantly, 4,920 recorded pipelines had been skipped during startup because a failure marker was present.

That marker was caused by our timed diagnostic test being stopped during preparation, not a demonstrated preparation crash. We corrected this mistake, backed up the marker, and allowed preparation to finish: **5,156 pipelines built, zero failed, zero left in the background**, in about two minutes. The cache was saved and the running marker cleared. Post-recovery gameplay smoothness still needs measurement; no guaranteed FPS or VRAM reduction is claimed.

## Manual instructions

1. Save and close the game. Back up `nx2navi.ini` in the folder containing `ocarina.exe`.
2. Add `gpl = 0` to that INI file, or change an existing GPL entry to zero. Sections only group settings. Do not overwrite the rest of your configuration.
3. Launch normally and allow shader/pipeline preparation to finish. The first start may take several minutes. Do not terminate it merely because the compilation screen is taking time.
4. Retest the same enemy and area. Keep your pipeline and shader caches.

```ini
[renderer compatibility]
gpl = 0
```

If the log explicitly says recorded pipelines were **not built ahead of play** because an earlier start died, inspect `pipeline-prewarm-skip.txt` and `pipeline-prewarm-running.txt` in the game folder. Only if you know preparation was interrupted intentionally, close the game and move these files into a backup folder before relaunching. If preparation genuinely crashed, preserve the logs and investigate; repeatedly clearing its safeguard can repeat the crash.

## Optional helper

Download [Apply-AMD-Compatibility.ps1](Apply-AMD-Compatibility.ps1), review it, and run it in PowerShell with your actual game directory:

```powershell
.\Apply-AMD-Compatibility.ps1 -GameDirectory 'G:\games\NX2navi'
```

It checks that the game is closed, creates a unique settings backup under `diagnostics`, and sets `gpl = 0`. It does not require administrator rights. If Windows blocks a downloaded script, use the manual INI instructions above or review and unblock that file through its Properties dialog; no system-wide execution-policy change is needed.

For a **known intentionally interrupted** precompile only:

```powershell
.\Apply-AMD-Compatibility.ps1 -GameDirectory 'G:\games\NX2navi' -ResetPrewarmMarkers
```

The optional switch moves the two markers to the backup. It does not delete shader caches or prepare pipelines itself. Start the game normally afterwards and let preparation finish.

## Files and rollback

| File | Role |
| --- | --- |
| `nx2navi.ini` | Only setting changed: `gpl = 0` |
| `pipeline-keys.bin` | Existing descriptions used by the game to prepare known pipelines; retained |
| `pipeline-cache.bin` | Driver cache saved by the game; retained |
| `pipeline-prewarm-running.txt` | Preparation-in-progress marker; removed by the game on completion |
| `pipeline-prewarm-skip.txt` | Failed-preparation safeguard; moved only for a known false interruption |
| `Apply-AMD-Compatibility.ps1` | Independently written settings/backup helper |

To undo the helper's setting, close the game and restore `nx2navi.ini.before` from its printed backup location. That restores the prior GPL behaviour, including any prior crash risk. Existing failure markers can also be restored from that backup if needed.

No save migration is needed. No executable, upstream source patch, game files, account identity, saves, logs containing personal paths, or generated shader data are distributed here. NX2navi belongs to its upstream authors. This workaround is not affiliated with or endorsed by the upstream maintainer.
