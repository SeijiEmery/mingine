import raylib;
import std.stdio;
import std.string: toStringz;
import std.format: format;
import std.algorithm;
import std.datetime;
import std.datetime.systime;
import std.file;
import std.array;

void main() {
    auto assetBrowserWindow = ToolWindow("assets", Rectangle(610, 10, 300, 200));

    auto fileListView = FileListViewWindow(
        ToolWindow("image files", Rectangle(10, 10, 300, 200)),
        "../assets",
        "*.png");

    InitWindow(1400, 900, "Hello, Raylib-D!");
    while (!WindowShouldClose())
    {
        setMouseScrollHandledThisFrame(false);

        BeginDrawing();
        ClearBackground(Colors.RAYWHITE);

        //assetBrowserWindow.updateLayoutAndRedraw!((){
        //    DrawText("Hello, World!", 20, 20, 28, Colors.BLACK);
        //});

        fileListView.updateLayoutAndRedraw();

        EndDrawing();
    }
    CloseWindow();
}

float scrollSensitivity = 2.5;
bool handledScrollThisFrame = false;
bool hasUnhandledMouseScrollXY (out Vector2 scrollDir) {
    if (handledScrollThisFrame) return false;
    if (IsKeyDown(KeyboardKey.KEY_LEFT_SHIFT) || IsKeyDown(KeyboardKey.KEY_RIGHT_SHIFT)) {
        scrollDir.x = GetMouseWheelMove() * scrollSensitivity;
        scrollDir.y = 0;
    } else {
        scrollDir.y = -GetMouseWheelMove() * scrollSensitivity;
        scrollDir.x = 0;
    }
    return true;
}
void setMouseScrollHandledThisFrame(bool value = true) {
    handledScrollThisFrame = value;
}

private Rectangle* _dragTarget = null;
private Vector2    _dragStartPosition;

// implement drag actions + return true iff dragged / interacted
// with this frame
bool makeMouseDraggable (ref Rectangle dragTarget, int mouseButton = 0) {
    if (!_dragTarget && IsMouseButtonPressed(mouseButton) && hasMouseOver(dragTarget)) {
        _dragTarget = &dragTarget;
        _dragStartPosition = Vector2(
            GetMouseX() - dragTarget.x, 
            GetMouseY() - dragTarget.y);
        return true;

    } else if (_dragTarget == &dragTarget) {
        if (IsMouseButtonDown(mouseButton)) {
            dragTarget.x = GetMouseX() - _dragStartPosition.x;
            dragTarget.y = GetMouseY() - _dragStartPosition.y;
        } else {
            _dragTarget = null;
        }
        return true;
    }
    return false;
}

bool hasMouseOver (Rectangle rect) {
    int mouseX = GetMouseX(), mouseY = GetMouseY();
    return mouseX >= rect.x && mouseX <= rect.x + rect.width &&
        mouseY >= rect.y && mouseY <= rect.y + rect.height;
}
struct ToolWindow {
    string      name;
    Rectangle   rect;            // outside window rect, incl window title bar
    Rectangle   dragRect;        // internal rect used as a window resizing widget

    Rectangle   contentRect;     // calculated content (inside of window) rect
                                 // should set .width, .height before window draw(),
                                 // and .x, .y will be set to padded / adjusted values w/ window draw

    // scroll state
    Vector2     scrollPos   = Vector2(0, 0);
    Vector2     scrollPct   = Vector2(1, 1);
    bool        hasScrollbarX = false;
    bool        hasScrollbarY = false;

    // configuration options
    float contentPad  = 5; // content padding on contentRect applied in all directions
    bool showTitleBar   = true;
    bool draggable      = true;
    bool resizable      = true;
    bool scrollable     = true;

    int minWidth = 100;
    int minHeight = 50;
}
void updateLayoutAndRedraw (alias drawContents)(ref ToolWindow window) {

    // apply min width / height constraint
    if (window.rect.width < window.minWidth) window.rect.width = window.minWidth;
    if (window.rect.height < window.minHeight) window.rect.height = window.minHeight;

    int FONT_SIZE           = 16;
    int WINDOW_TITLE_HEIGHT = 20;
    int SCROLLBAR_WIDTH     = 8;

    int mouseX = GetMouseX();
    int mouseY = GetMouseY();

    bool mouseOver = window.rect.hasMouseOver;

    // window resize area at lower right
    window.dragRect.x = window.rect.x + window.rect.width - 20;
    window.dragRect.y = window.rect.y + window.rect.height - 20;
    window.dragRect.width = window.dragRect.height = 20;

    if (window.resizable && window.dragRect.makeMouseDraggable) {
        window.dragRect.x = max(window.dragRect.x, window.rect.x + window.minWidth);
        window.dragRect.y = max(window.dragRect.y, window.rect.y + window.minHeight);

        window.rect.width = window.dragRect.x - window.rect.x + 20;
        window.rect.height = window.dragRect.y - window.rect.y + 20;
    
    } else if (window.draggable) {
        window.rect.makeMouseDraggable;
    }

    // calculate content rect
    window.contentRect.x = window.rect.x + window.contentPad;
    window.contentRect.y = window.rect.y + window.contentPad;
    if (window.showTitleBar) {
        window.contentRect.y += WINDOW_TITLE_HEIGHT;
    }

    // check if we need scrolling
    if (!window.scrollable) {

        // no scrolling => content rect may need to be clamped
        window.contentRect.width = min(window.contentRect.width,
            window.rect.width - window.contentPad * 2);
        window.contentRect.height = min(window.contentRect.width,
            window.rect.height - window.contentPad * 2);

        window.hasScrollbarX = window.hasScrollbarY = false;

    } else {
        // do we need scrollbars?
        bool needsScrollbarX = window.contentRect.width + window.contentPad * 2 > window.rect.width;
        bool needsScrollbarY = window.contentRect.height + window.contentPad * 2 > window.rect.height;

        if (needsScrollbarX && !window.hasScrollbarX) { window.scrollPos.x = 0; }
        if (needsScrollbarY && !window.hasScrollbarY) { window.scrollPos.y = 0; }

        window.hasScrollbarX = needsScrollbarX;
        window.hasScrollbarY = needsScrollbarY;

        // update scrolling and calculate scrollbar positioning, if present...
        if (window.hasScrollbarX || window.hasScrollbarY) {
            Vector2 scroll;
            if (hasUnhandledMouseScrollXY(scroll)) {
                setMouseScrollHandledThisFrame();

                if (window.hasScrollbarX) window.scrollPos.x += scroll.x;
                if (window.hasScrollbarY) window.scrollPos.y += scroll.y;

                window.scrollPos.x = max(0, min(window.scrollPos.x, window.contentRect.width - window.rect.width));
                window.scrollPos.y = max(0, min(window.scrollPos.y, window.contentRect.height - window.rect.height));
            }
        }
        if (window.hasScrollbarX && window.contentRect.width > 0) {
            window.scrollPct.x = window.scrollPos.x / (window.contentRect.width - window.rect.width);
        } else {
            window.scrollPct.x = window.scrollPos.x = 0;
        }
        if (window.hasScrollbarY && window.contentRect.height > 0) {
            window.scrollPct.y = window.scrollPos.y / (window.contentRect.height - window.rect.height);
        } else {
            window.scrollPct.y = window.scrollPos.y = 0;
        }
    }

    auto backgroundColor = Color(80, 60, 60, 150);
    if (mouseOver) {
        backgroundColor.r += 20;
        backgroundColor.b += 20;
        backgroundColor.g += 20;
    }

    DrawRectangleRounded(
        window.rect,
        0.07,
        10,
        backgroundColor
    );

    auto titleBarColor = backgroundColor;
    titleBarColor.a = 200;

    DrawRectangleRounded(
        Rectangle(window.rect.x + 1, window.rect.y + 1, window.rect.width - 2, WINDOW_TITLE_HEIGHT),
        0.05,
        10,
        titleBarColor,
    );
    const(char)* windowTitle = window.name.toStringz;
    int textWidth = MeasureText(windowTitle, FONT_SIZE);
    DrawText(windowTitle,
        cast(int)(window.rect.x + (window.rect.width - textWidth) / 2),
        cast(int)(window.rect.y),
        FONT_SIZE,
        Colors.WHITE
    );

    if (window.rect.hasMouseOver) {
        DrawRectangleRounded(window.dragRect, 0.05,
            10,
            titleBarColor);
    }

    // draw scrollbars...
    if (window.hasScrollbarX) {
        //DrawRectangleRounded(
        //    Rectangle(

        //    ),
        //    0.05,
        //    10,
        //    Colors.WHITE
        //);
    }
    if (window.hasScrollbarY) {

        float scrollbarHeight = window.rect.height * window.rect.height / window.contentRect.height;
        float travel = window.rect.height - scrollbarHeight;

        auto scrollRect = Rectangle(
            window.rect.x + window.rect.width - window.contentPad - SCROLLBAR_WIDTH,
            window.rect.y + WINDOW_TITLE_HEIGHT + travel * window.scrollPct.y,
            SCROLLBAR_WIDTH,
            scrollbarHeight
        );
        //writefln("%s %s", window.scrollPct, scrollRect);

        DrawRectangleRounded(
            scrollRect,
            0.5,
            10,
            Color(255, 255, 255, 100)
        );
    }

    //auto info = "%s\n%s, %s\n%s, %s\nscroll %s %s".format(
    //    window.rect, mouseX, mouseY, 
    //    _dragStartPosition.x,
    //    _dragStartPosition.y,
    //    window.scrollPos, window.scrollPct);
    //DrawText(info.toStringz,
    //    cast(int)window.rect.x,
    //    cast(int)window.rect.y + 30,
    //    FONT_SIZE,
    //    Colors.WHITE);


    BeginScissorMode(
        cast(int)window.contentRect.x, 
        cast(int)window.contentRect.y, 
        cast(int)(window.rect.width - window.contentPad * 2), 
        cast(int)(window.rect.height - WINDOW_TITLE_HEIGHT - window.contentPad * 2));
    drawContents();
    EndScissorMode();
}

struct FileListViewWindow {
    ToolWindow  window;
    string      rootPath;
    string      extensions;
    string[]    paths;
    SysTime     timeLastScanned = SysTime.min;
}

void updateLayoutAndRedraw (ref FileListViewWindow files) {
    enum TEXT_HEIGHT    = 20;
    enum TEXT_FONT_SIZE = 16;
    enum OFFSETY        = 30;
    enum PAD            = 8;

    if (files.timeLastScanned + dur!"seconds"(5) < Clock.currTime) {
        files.timeLastScanned = Clock.currTime;
        files.paths = files.rootPath.dirEntries(files.extensions, SpanMode.depth)
            .filter!(entry => entry.exists && entry.isFile)
            .map!(entry => entry.name)
            .array;
        writefln("%s file(s): %s", files.paths.length, files.paths);
    
        // update window layout:
        int minWidth = 100, minHeight = 30;
        int height   = 0;
        foreach (path; files.paths) {
            int width = MeasureText(path.toStringz, TEXT_FONT_SIZE);
            minWidth = max(width, minWidth);
            height  += TEXT_HEIGHT;
        }
        minHeight = max(minHeight, height) + PAD * 2;
        minWidth += PAD * 2;

        writefln("set min width = %s, min height = %s", files.window.minWidth, files.window.minHeight);
        files.window.contentRect.width  = minWidth;
        files.window.contentRect.height = max(minHeight, height);
        files.window.minWidth = minWidth;
    }

    files.window.updateLayoutAndRedraw!((){
        int x = cast(int)(files.window.contentRect.x - files.window.scrollPos.x);
        int y = cast(int)(files.window.contentRect.y - files.window.scrollPos.y);

        foreach (file; files.paths) {
            DrawText(file.toStringz, x, y, 16, Colors.BLACK);
            y += 18;
        }
    });
}
