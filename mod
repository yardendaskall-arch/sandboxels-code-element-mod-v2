runAfterLoad(function () {
    logMessage("code block mod loaded");

    elements.code_block = {
        name: "code block",
        color: "#4f7cff",
        behavior: behaviors.WALL,
        category: "special",
        state: "solid",
        density: 9999,
        hidden: false,
        desc: "Test block. Turns into fire when placed.",
        onPlace: function(pixel) {
            changePixel(pixel, "fire");
        }
    };
});
