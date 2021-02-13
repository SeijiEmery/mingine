import raylib;
import std.stdio;
import std.string: toStringz;
import std.format: format;
import std.algorithm;
import std.datetime;
import std.datetime.systime;
import std.file;
import std.array;

import mingine.editor_ui;

Texture2D[string] textureFileCache;
Texture2D readTextureCached (string path) {
    auto ptr = path in textureFileCache;
    if (ptr) return *ptr;
    return textureFileCache[path] = LoadTexture(path.toStringz);
}

void main() {
    ToolWindow.createWindow("assets")
        .setRect(Rectangle(610, 10, 300, 200));

    auto fileListView = FileListViewWindow(
        *ToolWindow.createWindow("local image files", Rectangle(10, 10, 300, 200)),
        "../assets",
        "*.png");

    void drawTexturePreview (string path, Rectangle neighboringRect) {
        auto texture = readTextureCached(path);
        //if (neighboringRect.x - texture.width > 0) {
        if (neighboringRect.x + neighboringRect.width / 2 > GetScreenWidth() / 2) {
            // draw on left hand side
            DrawTexture(texture, cast(int)(neighboringRect.x - texture.width), cast(int)neighboringRect.y, Colors.WHITE);
        } else {
            // draw on right hand side
            DrawTexture(texture, 
                cast(int)(neighboringRect.x + neighboringRect.width),
                cast(int)(neighboringRect.y),
                Colors.WHITE);
        }
    }
    fileListView.onMouseOver = delegate(string path, Rectangle selectionRect, ref ToolWindow window) {
        auto drawAt = window.rect; drawAt.x -= 5; drawAt.width += 10;
        drawTexturePreview(path, drawAt);
    };

    SpriteEditor[string] openSpriteEditors;
    string               activeSpriteEditor = null;

    void openSpriteEditor (string path) {
        if (path !in openSpriteEditors) {
            openSpriteEditors[path] = SpriteEditor(path);
        }
        activeSpriteEditor = path;
    }
    fileListView.onSelected = delegate(string path, Rectangle selectionRect, ref ToolWindow window) { openSpriteEditor(path); };

    InitWindow(1400, 900, "sprite asset editor");
    while (!WindowShouldClose())
    {
        setMouseScrollHandledThisFrame(false);

        BeginDrawing();
        ClearBackground(Colors.BLACK);

        SpriteEditor* spriteEditor = activeSpriteEditor ?
            activeSpriteEditor in openSpriteEditors :
            null;

        // draw background 1st so doesn't overlap tool windows / etc
        if (spriteEditor) drawBackground(*spriteEditor);

        //assetBrowserWindow.updateLayoutAndRedraw!((){
        //    DrawText("Hello, World!", 20, 20, 28, Colors.BLACK);
        //});
        fileListView.updateLayoutAndRedraw();

        if (spriteEditor) {
            updateAndRedraw(*spriteEditor);
            if (spriteEditor.wantsClose) {
                openSpriteEditors.remove(activeSpriteEditor);
                activeSpriteEditor = null;
            }
        }

        EndDrawing();
    }
    CloseWindow();
}

struct SpriteEditor {
    string      path;
    Texture2D   texture;
    bool        wantsClose = false;
    Camera2D    camera;

    Vector2[]   pointSelections;

    size_t      currentFrame = 0;
    double      nextFrameTime = 0;
    double      animationFrameRate = 30; // frames / sec

    @property auto toolsWindow () { return ToolWindow.getWindow("tools"); }

    this (string path) {
        this.path = path;
        texture = readTextureCached(path);

        camera.offset = Vector2(texture.width / 2, texture.height / 2);
        camera.zoom   = 4;

        ToolWindow.createWindow("tools", Rectangle(10, 220, 300, 100));
    }
}
void drawBackground (ref SpriteEditor editor) {
   
    auto mouseXY = Vector2(
            (GetMouseX() - editor.camera.offset.x) / editor.camera.zoom, 
            (GetMouseY() - editor.camera.offset.y) / editor.camera.zoom,
        );//.GetWorldToScreen2D(editor.camera);
    auto cursorRect = Rectangle(mouseXY.x, mouseXY.y, 100, 100);

    if (!hasDragAction && IsMouseButtonPressed(0)) {
        editor.pointSelections ~= mouseXY;
    } else if (IsKeyPressed(KeyboardKey.KEY_TAB) && editor.pointSelections.length) {
        editor.pointSelections = editor.pointSelections[0..$-1];
    }

   // draw image + manipulators
    BeginMode2D(editor.camera);
    
    DrawRectangleLines(-1, -1, editor.texture.width + 2, editor.texture.height + 2, 
        Color(100, 110, 110, 150));
    DrawTexture(editor.texture, 0, 0, Colors.WHITE);

    Rectangle getRect (Vector2 p0, Vector2 p1) {
        if (p1.x < p0.x) swap(p1.x, p0.x);
        if (p1.y < p0.y) swap(p1.y, p0.y);
        return Rectangle(p0.x, p0.y, p1.x - p0.x, p1.y - p0.y);
    }
    Rectangle clampToBounds (Rectangle rect, int width, int height) {
        if (rect.x < 0) rect.x = 0;
        if (rect.y < 0) rect.y = 0;
        if (rect.x + rect.width > width) rect.width = width - rect.x;
        if (rect.y + rect.height > height) rect.height = height - rect.y;
        return rect;
    }

    // draw animation frame(s), if present
    size_t numFrames = editor.pointSelections.length / 2;
    if (numFrames > 0) {
        if (numFrames > 1 && GetTime() > editor.nextFrameTime) {
            editor.nextFrameTime = GetTime() + 1.0 / editor.animationFrameRate;
            editor.currentFrame += 1;
        }
        if (editor.currentFrame >= numFrames) {
            editor.currentFrame = 0;
        }
        auto frame = clampToBounds(getRect(
                editor.pointSelections[editor.currentFrame * 2], 
                editor.pointSelections[editor.currentFrame * 2 + 1]),
            editor.texture.width, editor.texture.height);

        //writefln("Drawing frame %s => %s", editor.currentFrame, frame);

        DrawTextureRec(editor.texture, frame, 
            Vector2(0, 20),
            Colors.WHITE);
    }

    void drawRect(Vector2 p0, Vector2 p1) {        
        DrawRectangleLinesEx(clampToBounds(getRect(p0, p1), editor.texture.width, editor.texture.height),
            1, Color(255, 255, 255, 100));
    }

    size_t i = 0;
    for (; i + 1 < editor.pointSelections.length; i += 2) {
        auto p0 = editor.pointSelections[i];
        auto p1 = editor.pointSelections[i+1];
        drawRect(p0, p1);
    }
    if (i < editor.pointSelections.length) {
        drawRect(editor.pointSelections[i], mouseXY);
    }

    //DrawRectangleLinesEx(cursorRect, 1, Colors.WHITE);
    //writefln("%s", mouseXY);

    EndMode2D();

    DrawText("%s, %s".format(cast(int)mouseXY.x, cast(int)mouseXY.y).toStringz,
        GetMouseX(), GetMouseY() - 20, 12, Colors.WHITE);
}

// update camera + draw foreground editor UI elements...
void updateAndRedraw (ref SpriteEditor editor) {

    editor.toolsWindow.draw((ref layout){

    });

    // move camera when dragging w/ right / middle mouse button
    auto camDragTarget = cast(Rectangle*)(&editor.camera.offset);
    if (!_dragTarget && (IsMouseButtonPressed(1) || IsMouseButtonPressed(2))) {
        _dragTarget = camDragTarget;
        _dragStartPosition.x = GetMouseX() - editor.camera.offset.x;
        _dragStartPosition.y = GetMouseY() - editor.camera.offset.y;
    } else if (_dragTarget == camDragTarget) {

        editor.camera.offset.x = GetMouseX() - _dragStartPosition.x;
        editor.camera.offset.y = GetMouseY() - _dragStartPosition.y;

        if (!IsMouseButtonDown(1) && !IsMouseButtonDown(2)) {
            _dragTarget = null;
        }
    }

    // zoom w/ scroll wheel, or cmd/ctrl +/-/0
    Vector2 scroll;
    if (hasUnhandledMouseScrollXY(scroll)) {
        setMouseScrollHandledThisFrame();
        editor.camera.zoom -= scroll.y / 10;
    }

    if (IsKeyPressed(KeyboardKey.KEY_MINUS)) {        // top row '-' key
        editor.camera.zoom /= 2;
    } else if (IsKeyPressed(KeyboardKey.KEY_EQUAL)) { // top row '+' key
        editor.camera.zoom *= 2;
    } else if (IsKeyPressed(KeyboardKey.KEY_ZERO)) {
        editor.camera.zoom = 2;
    }

    editor.camera.zoom = clamp(editor.camera.zoom, 0.5, 10);

    // manipulators
    BeginMode2D(editor.camera);
        
    EndMode2D();
}

struct ToolWindow2 {
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
void updateLayoutAndRedraw (alias drawContents)(ref ToolWindow2 window) {

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

    // enforce constraints st. window cannot go fully off screen
    window.rect.x = clamp(window.rect.x, 20 - window.rect.width, GetScreenWidth() - 20);
    window.rect.y = clamp(window.rect.y, 20 - window.rect.height, GetScreenHeight() - 20);

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
            if (mouseOver && hasUnhandledMouseScrollXY(scroll)) {
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

    auto backgroundColor = Color(100, 90, 100, 150);
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

    void delegate(string path, Rectangle selection, ref ToolWindow window) onMouseOver  = null;
    void delegate(string path, Rectangle selection, ref ToolWindow window) onSelected   = null;
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
            .array
            .sort()
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
        //files.window.contentRect.width  = minWidth;
        //files.window.contentRect.height = max(minHeight, height);
        //files.window.minWidth = minWidth;
    }

    string    selectedFile  = null;
    string    mouseoverFile = null;
    Rectangle cursorAtRect;

    files.window.draw((ref layout){
        //int x = cast(int)(files.window.contentRect.x - files.window.scrollPos.x);
        //int y = cast(int)(files.window.contentRect.y - files.window.scrollPos.y);

        foreach (file; files.paths) {
            auto width = MeasureText(file.toStringz, 16);
            auto rect = layout.layoutRect(width, 18);
            rect.width = files.window.rect.width;
            //auto rect = Rectangle(x, y, files.window.rect.width, 18);

            if (rect.y + rect.height >= layout.parentViewRect.top &&
                rect.y + rect.height / 2 < layout.parentViewRect.bottom &&
                rect.hasMouseOver) {
                mouseoverFile = file;
                cursorAtRect  = rect;
                if (IsMouseButtonDown(0)) {
                    if (IsMouseButtonPressed(0)) selectedFile = file;
                    DrawRectangleRec(rect, Color(150, 225, 150, 100));
                } else {
                    DrawRectangleRec(rect, Color(150, 250, 250, 100));
                }
            }
            DrawText(file.toStringz, cast(int)rect.x, cast(int)rect.y, 16, Colors.BLACK);
            //y += 18;
        }
    });
    if (selectedFile && files.onSelected) files.onSelected(selectedFile, cursorAtRect, files.window);
    else if (mouseoverFile && files.onMouseOver) files.onMouseOver(mouseoverFile, cursorAtRect, files.window);
}
