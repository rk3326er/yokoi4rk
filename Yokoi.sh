#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt

[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

get_controls

GAMEDIR=/$directory/ports/yokoi
YOKOI_DIR="$GAMEDIR"

CONFDIR="$YOKOI_DIR/conf"

mkdir -p "$CONFDIR"

cd "$YOKOI_DIR"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Settings / saves / ROM pack live inside the port folder.
export YOKOI_DATA="$YOKOI_DIR"

export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
# Software renderer: don't let CFWs force GL4ES/GL onto a pure-SDL surface port.
export LIBGL_ALWAYS_SOFTWARE=1
export SDL_RENDER_DRIVER=software

# SDL_VIDEO_FULLSCREEN_DISPLAY / X11: on CFWs the port usually runs windowed at
# the native resolution reported by SDL (DEVICE_INFO DISPLAY_WIDTH x HEIGHT).
# The emulator letterbox-scales its canvas to whatever window size it gets.

SELECTION="$YOKOI_DIR/.selection"
export YOKOI_SELECT_OUT="$SELECTION"

LOVE_RUNTIME="love_11.5"

run_selector() {
    rm -f "$SELECTION"

    # Love2D runtime for the game selector; falls back to the built-in menu
    # when the runtime is unavailable.
    if [ ! -f "$controlfolder/runtimes/${LOVE_RUNTIME}/love.txt" ] && [ -f "$controlfolder/harbourmaster" ]; then
        $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${LOVE_RUNTIME}.squashfs" 2>/dev/null
    fi

    if [ -f "$controlfolder/runtimes/${LOVE_RUNTIME}/love.txt" ]; then
        source "$controlfolder/runtimes/${LOVE_RUNTIME}/love.txt"
        $GPTOKEYB "$LOVE_GPTK" &
        pm_platform_helper "$LOVE_BINARY"
        $LOVE_RUN "$YOKOI_DIR/selector"
        return 0
    fi
    return 1
}

# Selector loop: pick a game -> play it -> back to the selector. Cancel exits.
while true; do
    if run_selector && [ -s "$SELECTION" ]; then
        REF=$(cat "$SELECTION")
        rm -f "$SELECTION"

        $GPTOKEYB "yokoi.${DEVICE_ARCH}" &
        pm_platform_helper "$YOKOI_DIR/yokoi.${DEVICE_ARCH}"
        "$YOKOI_DIR/yokoi.${DEVICE_ARCH}" --ref "$REF"
    else
        # no selector runtime or user cancelled without a runtime: built-in menu
        $GPTOKEYB "yokoi.${DEVICE_ARCH}" &
        pm_platform_helper "$YOKOI_DIR/yokoi.${DEVICE_ARCH}"
        "$YOKOI_DIR/yokoi.${DEVICE_ARCH}"
        break
    fi

    # if the selector was cancelled (no selection), exit the loop
    if [ ! -s "$SELECTION" ]; then
        break
    fi
done

rm -f "$SELECTION"
pm_finish