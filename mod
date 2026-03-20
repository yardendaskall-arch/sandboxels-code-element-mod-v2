runAfterLoad(function () {
    const DEFAULT_SCRIPT = [
        "MESSAGE Hello from code block",
        "SPAWN fire 1 0"
    ].join("\n");

    function askScript() {
        const script = prompt(
            "Enter script:\n\n" +
            "SETTEMP 200\n" +
            "CHANGE fire\n" +
            "SPAWN water 1 0\n" +
            "DELETE 1 0\n" +
            "COLOR #ff0000\n" +
            "MESSAGE Hello",
            DEFAULT_SCRIPT
        );
        return (script && script.trim()) ? script.trim() : DEFAULT_SCRIPT;
    }

    function isLiquidElement(elemName) {
        return elements[elemName] && elements[elemName].state === "liquid";
    }

    function runBlockScript(pixel) {
        if (!pixel || !pixel.blockScript) return;
        if (pixel._lastRunTick === pixelTicks) return;
        pixel._lastRunTick = pixelTicks;

        const lines = pixel.blockScript.split(/\r?\n/);

        for (let raw of lines) {
            const line = raw.trim();
            if (!line) continue;

            const parts = line.split(/\s+/);
            const cmd = parts[0].toUpperCase();

            try {
                if (cmd === "SETTEMP") {
                    const temp = Number(parts[1]);
                    if (!isNaN(temp)) {
                        pixel.temp = temp;
                        if (typeof pixelTempCheck === "function") pixelTempCheck(pixel);
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
                    const dx = Number(parts[2] || 0);
                    const dy = Number(parts[3] || 0);
                    const x = pixel.x + dx;
                    const y = pixel.y + dy;

                    if (elem && elements[elem] && !outOfBounds(x, y) && isEmpty(x, y)) {
                        createPixel(elem, x, y);
                    }
                }
                else if (cmd === "DELETE") {
                    const dx = Number(parts[1] || 0);
                    const dy = Number(parts[2] || 0);
                    const x = pixel.x + dx;
                    const y = pixel.y + dy;

                    if (!outOfBounds(x, y) && !isEmpty(x, y, true)) {
                        deletePixel(x, y);
                    }
                }
                else if (cmd === "COLOR") {
                    const color = parts[1];
                    if (color) pixel.color = color;
                }
                else if (cmd === "MESSAGE") {
                    const msg = line.slice(7).trim();
                    if (msg) logMessage(msg);
                }
            } catch (e) {
                logMessage("Code block error: " + e.message);
            }
        }
    }

    function setupPixel(pixel, mode) {
        pixel.blockMode = mode;
        pixel.blockScript = askScript();

        if (mode === "place") {
            runBlockScript(pixel);
        }
    }

    function checkLiquidTouch(pixel) {
        const dirs = [
            [0,-1],[1,0],[0,1],[-1,0],
            [1,-1],[1,1],[-1,1],[-1,-1]
        ];

        for (const [dx,dy] of dirs) {
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
        behavior: behaviors.WALL,
        category: "special",
        state: "solid",
        density: 9999,
        desc: "Runs its script when placed",
        onPlace: function(pixel) {
            setupPixel(pixel, "place");
        }
    };

    elements.code_block_liquid = {
        color: "#44ccff",
        behavior: behaviors.WALL,
        category: "special",
        state: "solid",
        density: 9999,
        desc: "Runs its script when touched by liquid",
        onPlace: function(pixel) {
            setupPixel(pixel, "liquid");
        },
        tick: function(pixel) {
            checkLiquidTouch(pixel);
        }
    };
});
