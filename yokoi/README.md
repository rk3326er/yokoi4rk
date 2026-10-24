# Yokoi - Game & Watch Emulator (PortMaster)

Single-screen (PortMaster) port of [RetroValou's Yokoi Game & Watch emulator](https://github.com/RetroValou/Yokoi_Game_-_Watch_emulator_3ds).

Emulates the Sharp **SM5A, SM510, SM511/SM512** chips used in Nintendo Game & Watch
models (1980-1991), plus supported Tronica and Elektronika titles — the same
game list as the 3DS/Android upstream releases.

## Notes / ROM pack

Thanks to **[RetroValou](https://github.com/RetroValou)** for making Yokoi —
the emulation core, ROM-pack format and artwork pipeline are all his work.
Also thanks to the MAME and Game & Watch FPGA (Adam Gastineau) projects the
emulator is inspired by.

**No ROMs are included.** Game & Watch ROMs and artwork are copyrighted, so
you must generate your own ROM pack from MAME ROMs with the upstream tool:

```
git clone https://github.com/RetroValou/Yokoi_Game_-_Watch_emulator_3ds.git
cd Yokoi_Game_-_Watch_emulator_3ds/CONVERT_ROM
pip install -r requirements.txt
python convert_3ds.py --target portmaster
```

Then copy the generated pack to:

```
ports/yokoi/yokoi/yokoi_pack_portmaster.ykp
```

(Android/RGDS packs `yokoi_pack_rgds.ykp` are also accepted.)

## Controls

| Button | Action |
|--|--|
| D-Pad | Left controller (game dependent) |
| A / B / X / Y | Right controller (game dependent: Y=left2, A=right2, X=up2, B=down2) |
| L1 | TIME button |
| START | GAME A |
| SELECT | GAME B |
| L1 + R1 | Return to game menu (auto-saves) |
| L2 + R2 | Settings (background color / LCD marking effect) |

Dual-screen Game & Watch games are shown stacked (top screen above bottom
screen) on the single display, like the upstream Android layout.

## Saves / settings

Savestates and settings are stored in `ports/yokoi/yokoi/conf/`
(`yokoi_gw_saves/`, `yokoi_gw_settings.dat`). Time is synced from the device
clock like on 3DS.

## Compile

```
git clone https://github.com/RetroValou/Yokoi_Game_-_Watch_emulator_3ds.git
cd Yokoi_Game_-_Watch_emulator_3ds
make -f Makefile.portmaster            # host build (needs sdl2 via pkg-config)
./scripts/portmaster-cross-build.sh   # aarch64 via PortMaster docker
```

The port adds: `source/portmaster/` (SDL2 single-screen frontend:
`main_pm.cpp`, `pm_screen.cpp`, `pm_input.cpp`, `pm_sound.cpp`,
vendored `stb_image.h`), `Makefile.portmaster`, and the
`--target portmaster` ROM-pack profile in `CONVERT_ROM`.

## License

Upstream Yokoi is public domain ("free to use, no attribution required").
The PortMaster frontend additions in this port are likewise released into the
public domain. See `yokoi/licenses/` for third-party notices (stb_image.h).