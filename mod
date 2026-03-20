// code_blocks.js
// Safe "code block" mod for Sandboxels
// Adds 2 elements:
// - code_block_place: runs its script when placed
// - code_block_liquid: runs its script when touched by a liquid
//
// Supported commands (one per line):
//   SETTEMP 200
//   CHANGE fire
//   SPAWN water 1 0
//   DELETE 1 0
//   COLOR #ff0000
//   EXPLODE 8
//   MESSAGE Hello world
//
// Notes:
// - Coordinates in SPAWN/DELETE are relative to the code block pixel.
// - SHIFT + click existing block with the Pick tool won't edit it automatically;
//   place a new one to set a new script.
// - This is intentionally NOT arbitrary JS execution.

(function () {
    const DEFAULT_SCRIPT = [
        "MESSAGE Hello from code block",
        "SPAWN fire 1 0"
    ].join("\n");

    function askMode(defaultMode) {
        const choice = prompt(
            "Choose trigger mode:\n" +
            "- place\n" +
            "- liquid\n\n" +
            "Type: place or liquid",
            defaultMode || "place"
        );
        if (!choice) return defaultMode || "place";
        const c = choice.trim().toLowerCase();
        return (c === "liquid") ? "liquid" : "place";
    }

    function askScript() {
        const script = prompt(
            "Enter code block script.\n\n" +
            "Commands:\n" +
            "SETTEMP 200\n" +
            "CHANGE fire\n" +
            "SPAWN water 1 0\n" +
            "DELETE 1 0\n" +
            "COLOR #ff0000\n" +
            "EXPLODE 8\n" +
            "MESSAGE Hello\n",
            DEFAULT_SCRIPT
        );
        return (script && script.trim()) ? script.trim() : DEFAULT_SCRIPT;
    }

    function isLiquidElement(elemName) {
        return elements[elemName] && elements[elemName].state === "liquid";
    }

    function runBlockScript(pixel) {
        if (!pixel || !pixel.blockScript) return;
        if (pixel._ranThisTick === pixelTicks) return;
        pixel._ranThisTick = pixelTicks;

        const lines = pixel.blockScript.split(/\r?\n/);

        for (let raw of lines) {
            const line = raw.trim();
            if (!line || line.startsWith("//") || line.startsWith("#")) continue;

            const parts = line.split(/\s+/);
            const cmd = parts[0].toUpperCase();

            try {
                if (cmd === "SETTEMP") {
                    const temp = Number(parts[1]);
                    if (!isNaN(temp)) {
                        pixel.temp = temp;
                        if (typeof pixelTempCheck === "function") {
                            pixelTempCheck(pixel);
                        }
                    }
                }
                else if (cmd === "CHANGE") {
                    const elem = parts[1];
                    if (elem && elements[elem]) {
                        changePixel(pixel, elem);
                    }
                }
                else if (cmd === "SPAWN") {
                    const elem = parts[1];
                    const dx = Number(parts[2]);
                    const dy = Number(parts[3]);
                    const x = pixel.x + (isNaN(dx) ? 0 : dx);
                    const y = pixel.y + (isNaN(dy) ? 0 : dy);

                    if (elem && elements[elem] && !outOfBounds(x, y) && isEmpty(x, y)) {
                        createPixel(elem, x, y);
                    }
                }
                else if (cmd === "DELETE") {
                    const dx = Number(parts[1]);
                    const dy = Number(parts[2]);
                    const x = pixel.x + (isNaN(dx) ? 0 : dx);
                    const y = pixel.y + (isNaN(dy) ? 0 : dy);

                    if (!outOfBounds(x, y) && !isEmpty(x, y, true)) {
                        deletePixel(x, y);
                    }
                }
                else if (cmd === "COLOR") {
                    const color = parts[1];
                    if (color) {
                        pixel.color = color;
                    }
                }
                else if (cmd === "EXPLODE") {
                    const radius = Number(parts[1]);
                    if (!isNaN(radius) && typeof explodeAt === "function") {
                        explodeAt(pixel.x, pixel.y, radius);
                    }
                }
                else if (cmd === "MESSAGE") {
                    const msg = line.slice("MESSAGE".length).trim();
                    if (msg) {
                        logMessage(msg);
                    }
                }
                else {
                    logMessage("Unknown code block command: " + cmd);
                }
            }
            catch (e) {
                logMessage("Code block error: " + e.message);
            }
        }
    }

    function setupPixel(pixel, forcedMode) {
        const mode = forcedMode || askMode("place");
        const script = askScript();

        pixel.blockMode = mode;
        pixel.blockScript = script;

        // If the block element doesn't match the selected mode,
        // convert it so the player can "pick" the behavior at placement time.
        if (mode === "liquid" && pixel.element !== "code_block_liquid") {
            changePixel(pixel, "code_block_liquid");
            pixel.blockMode = mode;
            pixel.blockScript = script;
        }
        else if (mode === "place" && pixel.element !== "code_block_place") {
            changePixel(pixel, "code_block_place");
            pixel.blockMode = mode;
            pixel.blockScript = script;
        }

        if (pixel.blockMode === "place") {
            runBlockScript(pixel);
        }
    }

    function liquidTouchTick(pixel) {
        const neighbors = [
            [0, -1], [1, 0], [0, 1], [-1, 0],
            [1, -1], [1, 1], [-1, 1], [-1, -1]
        ];

        for (const [dx, dy] of neighbors) {
            const x = pixel.x + dx;
            const y = pixel.y + dy;
            if (outOfBounds(x, y) || isEmpty(x, y, true)) continue;

            const other = pixelMap[x][y];
            if (other && isLiquidElement(other.element)) {
                runBlockScript(pixel);
                return;
            }
        }
    }

    elements.code_block_place = {
        color: "#6f6fff",
        category: "special",
        state: "solid",
        density: 9999,
        hardness: 1,
        desc: "Runs its script when placed.",
        behavior: behaviors.WALL,
        onPlace: function (pixel) {
            setupPixel(pixel, "place");
        }
    };

    elements.code_block_liquid = {
        color: "#44ccff",
        category: "special",
        state: "solid",
        density: 9999,
        hardness: 1,
        desc: "Runs its script when touched by a liquid.",
        behavior: behaviors.WALL,
        onPlace: function (pixel) {
            setupPixel(pixel, "liquid");
        },
        tick: function (pixel) {
            liquidTouchTick(pixel);
        },
        onCollide: function (pixel, otherPixel) {
            if (otherPixel && isLiquidElement(otherPixel.element)) {
                runBlockScript(pixel);
            }
        }
    };
})();
