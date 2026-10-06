ObjC.import('AppKit');

function run(argv) {
    var screens = $.NSScreen.screens;
    // AppKit uses bottom-left coordinates; yabai uses top-left coordinates.
    var primary = screens.objectAtIndex(0).frame;
    var top = primary.origin.y + primary.size.height;
    for (var i = 0; i < screens.count; i++) {
        var screen = screens.objectAtIndex(i);
        var id = ObjC.unwrap(screen.deviceDescription.objectForKey('NSScreenNumber'));
        if (Number(id) !== Number(argv[0])) continue;
        var frame = screen.visibleFrame;
        return JSON.stringify({
            x: frame.origin.x,
            y: top - frame.origin.y - frame.size.height,
            w: frame.size.width,
            h: frame.size.height
        });
    }
    throw new Error('Display not found: ' + argv[0]);
}
