/** Hybrid immediate / retained mode UI framework for rapidly prototyping out usable 2d editor UIs to build tools + editors with 
*/
module mingine.editor_ui;
import std.algorithm;
import std.array;
import std.format;
import std.stdio;
import std.string: toStringz;
import raylib;

// rect extension methods
auto top (Rectangle rect) { return rect.y; }
auto bottom (Rectangle rect) { return rect.y + rect.height; }
auto left (Rectangle rect) { return rect.x; }
auto right (Rectangle rect) { return rect.x + rect.height; }

// utility functions + internal state
float scrollSensitivity = 2.5;
bool handledScrollThisFrame = false;

bool hasUnhandledMouseScrollXY () { return !handledScrollThisFrame; }
Vector2 getMouseScrollXY () {
    auto x = GetMouseWheelMove();
    if (IsKeyDown(KeyboardKey.KEY_LEFT_SHIFT) || IsKeyDown(KeyboardKey.KEY_RIGHT_SHIFT)) {
        return Vector2(
            -GetMouseWheelMove() * scrollSensitivity,
            0
        );
    } else {
        return Vector2(
            0,
            -GetMouseWheelMove() * scrollSensitivity
        );
    }
}

bool hasUnhandledMouseScrollXY (out Vector2 scrollDir) {
    if (hasUnhandledMouseScrollXY) {
        scrollDir = getMouseScrollXY();
        return true;
    }
    return false;
}
void setMouseScrollHandledThisFrame(bool value = true) {
    handledScrollThisFrame = value;
}

public Rectangle* _dragTarget = null;
public Vector2    _dragStartPosition;

bool hasDragAction () { return _dragTarget !is null; }

// implement drag actions + return true iff dragged / interacted
// with this frame
bool makeMouseDraggable (ref Rectangle dragTarget, int mouseButton = 0) {
    if (!_dragTarget && IsMouseButtonPressed(mouseButton) && hasMouseOver(dragTarget)) {

        //writefln("drag start! %s", dragTarget);

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
    return mouseX >= rect.x && mouseX < rect.x + rect.width &&
        mouseY >= rect.y && mouseY < rect.y + rect.height;
}



struct UILayoutState {
    Rectangle parentViewRect;
    Rectangle contentRect;
    Vector2   nextLayoutPosition;
    LayoutDir layoutDir;

    enum LayoutDir { VERTICAL, HORIZONTAL }

    static UILayoutState createFromParentRect (Rectangle parentViewRect) {
        return UILayoutState(parentViewRect,
            Rectangle(parentViewRect.x, parentViewRect.y, 0, 0),
            Vector2(parentViewRect.x, parentViewRect.y));
    }
}

auto positionRectAndAdvanceLayout (ref UILayoutState state, ref Rectangle rect) {
    rect.x = state.nextLayoutPosition.x;
    rect.y = state.nextLayoutPosition.y;
    final switch (state.layoutDir) {
        case UILayoutState.LayoutDir.VERTICAL:
            state.nextLayoutPosition.y += rect.height;
            state.contentRect.height   += rect.height;
            state.contentRect.width     = max(state.contentRect.width, rect.width);
            break;
        case UILayoutState.LayoutDir.HORIZONTAL:
            state.nextLayoutPosition.x += rect.width;
            state.contentRect.width    += rect.width;
            state.contentRect.height    = max(state.contentRect.height, rect.height);
            break;
    }
    return rect;
}
auto layoutRect (ref UILayoutState state, float width, float height) {
    auto rect = Rectangle(0, 0, width, height);
    return state.positionRectAndAdvanceLayout(rect);
}
auto shrinkRectByPadding (Rectangle rect, float pad) {
    rect.x += pad;
    rect.y += pad;
    rect.width -= pad * 2;
    rect.height -= pad * 2;
    return rect;
}


/** ToolWindow: root EditorUI window that other elements can be drawn within **/
struct ToolWindow {
    string      name;
    string      windowTitle;

    Rectangle   rect;            // outside window rect, incl window title bar
    Rectangle   dragRect;        // internal rect used as a window resizing widget

    // scroll state
    ScrollRegion scrollRegion;

    // configuration options
    float contentPad  = 5; // content padding on contentRect applied in all directions
    bool showTitleBar   = true;
    bool draggable      = true;
    bool resizable      = true;

    int minWidth = 100;
    int minHeight = 50;

    /// tool window management
    private static ToolWindow[string] _allWindowsByName;
    static bool hasWindow (string name) { return (name in _allWindowsByName) !is null; }
    static auto getWindow (string name) { assert(hasWindow(name), format("no window named '%s'!", name)); return &_allWindowsByName[name]; }
    static auto createWindow (string name, Rectangle rect = Rectangle(20, 20, 200, 200)) {
        return hasWindow(name) ?
            getWindow(name) :
            &(_allWindowsByName[name] = ToolWindow(name, name, rect));
    }
    auto setRect (Rectangle rect) {
        this.rect = rect;
        return &this;
    }
    auto setPos (int x, int y) {
        rect.x = x;
        rect.y = y;
        return &this;
    }
    auto setSize (int width, int height) {
        rect.width = width;
        rect.height = height;
        return &this;
    }
}

void draw (ToolWindow* window, void delegate(ref UILayoutState) drawContents) {
    assert(window);
    draw(*window, drawContents);
}

/** draw a window w/ arbitrary contents inside of drawContents(), which will be wrapped in a scroll region */
void draw (ref ToolWindow window, void delegate(ref UILayoutState) drawContents) {

    // config
    int FONT_SIZE           = 16;
    int WINDOW_TITLE_HEIGHT = 20;
    int SCROLLBAR_WIDTH     = 8;

    // apply min width / height constraint
    if (window.rect.width < window.minWidth) window.rect.width = window.minWidth;
    if (window.rect.height < window.minHeight) window.rect.height = window.minHeight;

    // draw window background (and highlight if we have mouseover this window)
    auto backgroundColor = Color(100, 90, 100, 150);
    if (window.rect.hasMouseOver) {
        backgroundColor.r += 20;
        backgroundColor.b += 20;
        backgroundColor.g += 20;
    }
    DrawRectangleRounded(window.rect, 0.07, 10, backgroundColor);

    auto innerWindowRect = window.rect.shrinkRectByPadding(window.contentPad);

    // draw window title bar, if enabled
    if (window.showTitleBar) {
        auto titleBarColor = backgroundColor;
        titleBarColor.a = 200;

        DrawRectangleRounded(
            Rectangle(window.rect.x + 1, window.rect.y + 1, window.rect.width - 2, WINDOW_TITLE_HEIGHT),
            0.05,
            10,
            titleBarColor,
        );
        innerWindowRect.y      += WINDOW_TITLE_HEIGHT;
        innerWindowRect.height -= WINDOW_TITLE_HEIGHT;

        const(char)* windowTitle = window.name.toStringz;
        int textWidth = MeasureText(windowTitle, FONT_SIZE);
        DrawText(windowTitle,
            cast(int)(window.rect.x + (window.rect.width - textWidth) / 2),
            cast(int)(window.rect.y),
            FONT_SIZE,
            Colors.WHITE
        );
    }

    // draw window contents wrapped in a scroll region
    window.scrollRegion.draw(innerWindowRect, drawContents);

    // draw resize widget + handle window resize, if enabled
    if (window.resizable) {
        // window resize area at lower right
        window.dragRect.x     = window.rect.x + window.rect.width - 20;
        window.dragRect.y     = window.rect.y + window.rect.height - 20;
        window.dragRect.width = window.dragRect.height = 20;

        if (window.dragRect.makeMouseDraggable) {
            window.dragRect.x = max(window.dragRect.x, window.rect.x + window.minWidth);
            window.dragRect.y = max(window.dragRect.y, window.rect.y + window.minHeight);
        
            window.rect.width = window.dragRect.x - window.rect.x + 20;
            window.rect.height = window.dragRect.y - window.rect.y + 20;
        }
    }

    // make window draggable, if enabled
    if (window.draggable) {
        window.rect.makeMouseDraggable;
    }

    window.rect.makeMouseDraggable;
}

struct ScrollRegion {
    Vector2     scrollPos   = Vector2(0, 0);
    Vector2     scrollPct   = Vector2(1, 1);
}

/** wraps an arbitrary EditorUI w/ a scroll region bounded by parentRect. 
    This UI will turn into a scroll region (vertical + horizontal scrollbars) if the contents overflow past the passed in region
*/
void draw (ref ScrollRegion scrollRegion, Rectangle parentRect, void delegate(ref UILayoutState) drawContents) {

    // config
    int SCROLLBAR_WIDTH     = 8;

    auto layout = UILayoutState.createFromParentRect(parentRect);

    // offset by current scroll pos
    layout.nextLayoutPosition.x = layout.contentRect.x = layout.nextLayoutPosition.x - scrollRegion.scrollPos.x;
    layout.nextLayoutPosition.y = layout.contentRect.y = layout.nextLayoutPosition.y - scrollRegion.scrollPos.y;

    // draw contents w/ scissored region around parent rect
    BeginScissorMode(cast(int)parentRect.x, cast(int)parentRect.y, cast(int)parentRect.width, cast(int)parentRect.height);
    drawContents(layout);
    EndScissorMode();

    // draw scrollbars if / as needed, and handle scrolling events
    bool needsScrollbarX = layout.contentRect.width > parentRect.width;
    bool needsScrollbarY = layout.contentRect.height > parentRect.height;

    // clear scroll pos if scroll not needed
    if (!needsScrollbarX) scrollRegion.scrollPos.x = 0;
    if (!needsScrollbarY) scrollRegion.scrollPos.y = 0;

    // try updating update scrollPos if scroll bars visible + get unhandled scroll event
    // (ie. scroll input + mouse over this region + mouse input not recieved / handled by another element, presumably in drawContents())
    if (needsScrollbarX || needsScrollbarY) {

        // update scroll pos in response to scroll events
        if (parentRect.hasMouseOver && hasUnhandledMouseScrollXY()) {
            auto scrollInput = getMouseScrollXY();
            setMouseScrollHandledThisFrame();

            if (needsScrollbarX) scrollRegion.scrollPos.x += scrollInput.x;
            if (needsScrollbarY) scrollRegion.scrollPos.y += scrollInput.y;
        }


        // apply scrollbar constraints
        scrollRegion.scrollPos.x = scrollRegion.scrollPos.x.clamp(0, max(0, layout.contentRect.width  - parentRect.width));
        scrollRegion.scrollPos.y = scrollRegion.scrollPos.y.clamp(0, max(0, layout.contentRect.height - parentRect.height));

        // draw scrollbars
        if (needsScrollbarY) {
            auto scrollTravel        = layout.contentRect.height - parentRect.height;
            auto scrollPosNormalized = scrollRegion.scrollPos.y / scrollTravel;
            auto scrollbarHeight     = parentRect.height * parentRect.height / layout.contentRect.height;

            auto scrollRect = Rectangle(
                parentRect.x + parentRect.width - SCROLLBAR_WIDTH,
                parentRect.y + (parentRect.height - scrollbarHeight) * scrollPosNormalized,
                SCROLLBAR_WIDTH,
                scrollbarHeight
            );
            DrawRectangleRounded(
                scrollRect,
                0.5,
                10,
                Color(255, 255, 255, 100)
            );
            //writefln("scroll %s %s", scrollTravel, scrollPosNormalized);
        }

        if (needsScrollbarX) {
            auto scrollTravel        = layout.contentRect.width - parentRect.width;
            auto scrollPosNormalized = scrollRegion.scrollPos.x / scrollTravel;
            auto scrollbarHeight     = parentRect.width * parentRect.width / layout.contentRect.width;

            auto scrollRect = Rectangle(
                parentRect.x + (parentRect.width - scrollbarHeight) * scrollPosNormalized,
                parentRect.y + parentRect.height - SCROLLBAR_WIDTH,
                scrollbarHeight,
                SCROLLBAR_WIDTH,
            );
            DrawRectangleRounded(
                scrollRect,
                0.5,
                10,
                Color(255, 255, 255, 100)
            );
        }
    }
}







