import raylib;
import std.string: toStringz;
import std.format: format;
import std.algorithm;

void main() {
    auto assetBrowserWindow = ToolWindow("assets", Rectangle(10, 10, 300, 200));

    InitWindow(1400, 900, "Hello, Raylib-D!");
    while (!WindowShouldClose())
    {
        BeginDrawing();
        ClearBackground(Colors.RAYWHITE);
        DrawText("Hello, World!", 400, 300, 28, Colors.BLACK);

        assetBrowserWindow.draw!((){
            DrawText("Hello, World!", 20, 20, 28, Colors.BLACK);
        });

        EndDrawing();
    }
    CloseWindow();
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
    Rectangle   rect;
    Rectangle   dragRect;

    int minWidth = 100;
    int minHeight = 50;
}
void draw (alias drawContents)(ref ToolWindow window) {
    int FONT_SIZE           = 16;
    int WINDOW_TITLE_HEIGHT = 20;

    int mouseX = GetMouseX();
    int mouseY = GetMouseY();

    bool mouseOver = window.rect.hasMouseOver;

    // window resize area at lower right
    window.dragRect.x = window.rect.x + window.rect.width - 20;
    window.dragRect.y = window.rect.y + window.rect.height - 20;
    window.dragRect.width = window.dragRect.height = 20;

    if (window.dragRect.makeMouseDraggable) {
        window.dragRect.x = max(window.dragRect.x, window.rect.x + window.minWidth);
        window.dragRect.y = max(window.dragRect.y, window.rect.y + window.minHeight);

        window.rect.width = window.dragRect.x - window.rect.x + 20;
        window.rect.height = window.dragRect.y - window.rect.y + 20;
    
    } else {
        window.rect.makeMouseDraggable;
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

    auto info = "%s\n%s, %s\n%s, %s".format(
        window.rect, mouseX, mouseY, 
        _dragStartPosition.x,
        _dragStartPosition.y);

    DrawText(info.toStringz,
        cast(int)window.rect.x,
        cast(int)window.rect.y + 30,
        FONT_SIZE,
        Colors.WHITE);


    drawContents();
}






