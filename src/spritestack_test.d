module spritestack_test;
import mingine.editor_ui;
import std.stdio;
import std.path;
import std.file;
import std.array;
import std.string;
import raylib;

string toRelPath (string path, string relTo) {
    return path.absolutePath.relativePath(relTo.absolutePath).buildNormalizedPath;
}

struct SpriteStackAssetCollection {
    string assetRootPath = "../assets";
    string spriteAssetExt = ".sprite.zip";
    SpriteStackAsset[string] assets;

    void rescan () {
        assets.clear();
        foreach (file; assetRootPath.dirEntries(SpanMode.depth)) {
            if (!file.name.endsWith(spriteAssetExt)) continue;

            string name = file.name[0..$-spriteAssetExt.length].toRelPath(assetRootPath);            
            SpriteStackAsset asset;
            if (asset.tryLoadAsset(name, file)) {
                writefln("found asset '%s'", name);
                assets[asset.name] = asset;
            } else {
                writefln("\033[31merror reading asset '\033[0;1m%s\033[0;31m' at '%s'\033[0m");
            }
            assets[name] = SpriteStackAsset(name, file);
        }
        writefln("found %s asset(s)", assets.length);
    }

    UIActions editorUIActions;
    struct UIActions {
        void delegate (string name) onSelectedAsset;
        void delegate (string name) onMouseover;
    }
    void drawAssetPickerUI () { drawAssetPickerUI(editorUIActions); }

    void drawAssetPickerUI (UIActions actions) {
        auto window = ToolWindow.createWindow("spritestack assets");

        string clickedAsset = null;
        string mouseoverAsset = null;

        window.draw((ref layout){
            foreach (asset; assets.byValue) {
                auto width = MeasureText(asset.name.toStringz, 16);
                auto rect = layout.layoutRect(width, 18);
                auto color = Color(220, 220, 220, 255);
                if (rect.hasMouseOver) {
                    if (IsMouseButtonPressed(0)) {
                        clickedAsset = asset.name;
                        color = Color(200, 255, 200, 255);
                    } else {
                        if (IsMouseButtonDown(0)) {
                            color = Color(180, 220, 180, 255);
                        } else {
                            color = Color(180, 220, 180, 225);
                        }
                        mouseoverAsset = asset.name;
                    }
                }
                DrawText(asset.name.toStringz,
                    cast(int)rect.x, cast(int)rect.y,
                    16, color);
            }
        });
    }
}

struct SpriteStackAsset {
    string name;
    string filePath;

    bool tryLoadAsset(string name, string filePath) {
        this.name = name;
        this.filePath = filePath;
        return true;
    }
}

void main() {
    SpriteStackAssetCollection spriteStackAssets;
    spriteStackAssets.rescan();

    VoxelAssetCollection voxelAssets;
    voxelAssets.rescan();

    spriteStackAssets.editorUIActions.onSelectedAsset = delegate (string name) {
        writefln("select asset '%s'", name);
    };
    spriteStackAssets.editorUIActions.onMouseover = delegate (string name) {

    };

    InitWindow(1400, 900, "sprite asset editor");
    while (!WindowShouldClose())
    {
        setMouseScrollHandledThisFrame(false);

        BeginDrawing();
        ClearBackground(Colors.BLACK);

        spriteStackAssets.drawAssetPickerUI();
        voxelAssets.drawAssetPickerUI();

        EndDrawing();
    }
    CloseWindow();
}


struct VoxelAssetCollection {
    string assetRootPath = "../assets";
    string spriteAssetExt = ".vox";
    VoxelAsset[string] assets;

    void rescan () {
        assets.clear();
        foreach (file; assetRootPath.dirEntries(SpanMode.depth)) {
            if (!file.name.endsWith(spriteAssetExt)) continue;

            string name = file.name[0..$-spriteAssetExt.length].toRelPath(assetRootPath);            
            VoxelAsset asset;
            if (asset.tryLoadAsset(name, file)) {
                writefln("found asset '%s'", name);
                assets[asset.name] = asset;
            } else {
                writefln("\033[31merror reading asset '\033[0;1m%s\033[0;31m' at '%s'\033[0m");
            }
            assets[name] = VoxelAsset(name, file);
        }
        writefln("found %s asset(s)", assets.length);
    }

    UIActions editorUIActions;
    struct UIActions {
        void delegate (string name) onSelectedAsset;
        void delegate (string name) onMouseover;
    }
    void drawAssetPickerUI () { drawAssetPickerUI(editorUIActions); }

    void drawAssetPickerUI (UIActions actions) {
        auto window = ToolWindow.createWindow("voxel assets");

        string clickedAsset = null;
        string mouseoverAsset = null;

        window.draw((ref layout){
            foreach (asset; assets.byValue) {
                auto width = MeasureText(asset.name.toStringz, 16);
                auto rect = layout.layoutRect(width, 18);
                auto color = Color(220, 220, 220, 255);
                if (rect.hasMouseOver) {
                    if (IsMouseButtonPressed(0)) {
                        clickedAsset = asset.name;
                        color = Color(200, 255, 200, 255);
                    } else {
                        if (IsMouseButtonDown(0)) {
                            color = Color(180, 220, 180, 255);
                        } else {
                            color = Color(180, 220, 180, 225);
                        }
                        mouseoverAsset = asset.name;
                    }
                }
                DrawText(asset.name.toStringz,
                    cast(int)rect.x, cast(int)rect.y,
                    16, color);
            }
        });
    }
}

struct VoxelAsset {
    string name;
    string filePath;

    bool tryLoadAsset(string name, string filePath) {
        this.name = name;
        this.filePath = filePath;
        return true;
    }
}