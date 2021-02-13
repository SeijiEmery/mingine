module spritestack_test;
import mingine.editor_ui;
import std.stdio;
import std.path;
import std.file;
import std.array;
import std.string;
import std.algorithm;
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
                writefln("\033[31merror reading asset '\033[0;1m%s\033[0;31m' at '%s'\033[0m",
                    name, file);
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
                writefln("\033[31merror reading asset '\033[0;1m%s\033[0;31m' at '%s'\033[0m",
                    name, file);
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
        auto window = ToolWindow.createWindow("voxel assets", Rectangle(20, 240, 200, 200));

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

// TODO: refactor out most of this into mingine.voxel, or something
import std.format;
import std.exception;

struct VoxelAsset {
    string name;
    string filePath;

    VoxelModel[]       voxelModels;
    VoxelColorPalette  colorPalette;
}

struct VoxelDimensions { uint x, y, z; }
struct Voxel           { ubyte x, y, z, i; }
struct VoxelModel {
    VoxelDimensions dimensions;
    Voxel[]         voxels;
}
struct VoxelColorPalette {
    VoxelColor[]    palette;
}
struct VoxelColor      { ubyte r, g, b, a; }

// magicavoxel .vox reader, from spec https://github.com/ephtracy/voxel-model/blob/master/MagicaVoxel-file-format-vox.txt
bool tryLoadAsset(ref VoxelAsset asset, string name, string filePath) {
    asset.name = name;
    asset.filePath = filePath;

    // try reading .vox file
    ubyte[] data = cast(ubyte[])filePath.read();
    if (data.length < 20 || cast(string)data[0..4] != "VOX ") {
        writefln("invalid .vox file!");
        return false;
    }
    int versionNum = cast(int*)(data.ptr)[1];
    writefln("got .vox file w/ version %s", versionNum);
    if (versionNum != 150 && versionNum != 79) {
        writefln("invalid version!");
        return false;
    }
    data = data[8..$];

    static struct ChunkHeader {
        char[4] type;
        int     numChunkBytes;
        int     numChildChunkBytes;
    }
    static struct Chunk {
        char[4] type;
        ubyte[] data;
        Chunk[] childChunks;
    }
    static Chunk readChunk (ref ubyte[] bytes) {
        enforce(bytes.length >= ChunkHeader.sizeof,
            format("error: expecting chunk but length %s < %s!", 
                bytes.length, ChunkHeader.sizeof));
        auto header = cast(ChunkHeader*)bytes.ptr;
        bytes = bytes[12..$];
        enforce(bytes.length >= header.numChunkBytes + header.numChildChunkBytes,
            format("chunk mismatch! %s, %s byte(s)", header, bytes.length));

        auto data = bytes[0..header.numChunkBytes]; 
        bytes     = bytes[header.numChunkBytes..$];

        auto childChunkData = bytes[0..header.numChildChunkBytes]; 
        bytes               = bytes[header.numChildChunkBytes..$];

        Chunk[] childChunks;
        while (childChunkData.length) {
            childChunks ~= readChunk(childChunkData);
        }
        return Chunk(header.type, data, childChunks);
    }
    static void printChunksRecursive (Chunk chunk, int indentLevel = 0) {
        foreach (i; 0 .. indentLevel) {
            write("  ");
        }
        writefln("chunk '%s' (data: %s byte(s), %s children)",
            chunk.type, chunk.data.length, chunk.childChunks.length);

        foreach (childChunk; chunk.childChunks) {
            printChunksRecursive(childChunk, indentLevel + 1);
        }
    }
    static bool hasChunk(ref Chunk[] chunks, char[4] chunkType) {
        return chunks.length && chunks[0].type == chunkType;
    }
    static Chunk expectChunk (ref Chunk[] chunks, char[4] chunkType) {
        enforce(hasChunk(chunks, chunkType),
            format("expected chunk '%s', but got chunk type '%s'",
                chunkType, chunks.length ?
                    chunks[0].type : "<no chunk>"));

        auto chunk = chunks[0];
        chunks = chunks[1..$];
        return chunk;
    }
    static T* expectChunkStruct2 (T)(ref Chunk[] chunks, char[4] chunkType, bool shouldHaveNoChildren = true) if (!is(T == class)) {
        auto chunk = expectChunk(chunks, chunkType);
        enforce(chunk.data.length == T.sizeof,
            format("expected %s bytes (%s) in '%s' chunk, got %s '%s'",
                chunk.data.length, T.stringof, chunk.type, chunk.data.length, chunk.data));
        
        if (shouldHaveNoChildren) {
            enforce(chunk.childChunks.length == 0,
                format("expected chunk '%s' to have no children, but has %s",
                    chunk.type, chunk.childChunks.length));
        }
        return (cast(T*)chunk.data.ptr);
    }
    static T* expectChunkStruct(T)(ref Chunk[] chunks, bool shouldHaveNoChildren = true) {
        return expectChunkStruct2!T(chunks, T.stringof, shouldHaveNoChildren);
    }

    // chunk types
    struct PACK { int numModels; }
    struct SIZE { int x, y, z; }

    static VoxelModel readVoxelModel (ref Chunk[] chunks) {
        auto modelSize = expectChunkStruct!SIZE(chunks);

        enforce(modelSize.x > 0 && modelSize.y > 0 && modelSize.z > 0,
            format("invalid model size: %s", modelSize));

        auto voxelData = expectChunk(chunks, "XYZI");
        int numVoxels = *(cast(int*)voxelData.data.ptr);
        enforce(numVoxels * 4 + 4 == voxelData.data.length,
            format("expected %s * 4 + 4 == %s, got %s != %s",
                numVoxels, voxelData.data.length,
                numVoxels * 4 + 4, voxelData.data.length));

        auto voxels = (cast(Voxel[])voxelData.data)[1..$];
        assert(numVoxels == voxels.length,
            format("%s != %s!", numVoxels, voxels.length));

        return VoxelModel(
            VoxelDimensions(cast(uint)modelSize.x, cast(uint)modelSize.y, cast(uint)modelSize.z),
            voxels);
    }

    static VoxelModel[] readVoxelModels (ref Chunk[] chunks) {
        VoxelModel[] models;
        if (hasChunk(chunks, "PACK")) {
            // read pack of models
            auto packInfo = expectChunkStruct!PACK(chunks);
            foreach (i; 0 .. packInfo.numModels) {
                models ~= readVoxelModel(chunks);
            }
        } else {
            models ~= readVoxelModel(chunks);
        }
        return models;
    }
    static VoxelColorPalette readColorPalette (Chunk chunk) {
        enforce(chunk.data.length % 4 == 0,
            format("expected RGBA data divisible by 4, got %s (modulo %s)",
                chunk.data.length, chunk.data.length % 4));
        return VoxelColorPalette(
            cast(VoxelColor[])chunk.data);
    }

    try {
        auto mainChunk = readChunk(data);
        enforce(mainChunk.type == "MAIN",
            format("expected 1st chunk type 'MAIN', got %s",
                mainChunk.type));
        enforce(data.length == 0,
            format("unexpected %s byte(s) after 1st main chunk!",
                data.length));

        //printChunksRecursive(mainChunk);

        auto chunks = mainChunk.childChunks;
        asset.voxelModels = readVoxelModels(chunks);

        static immutable int[256] DEFAULT_PALETTE = [
            0x00000000, 0xffffffff, 0xffccffff, 0xff99ffff, 0xff66ffff, 0xff33ffff, 0xff00ffff, 0xffffccff, 0xffccccff, 0xff99ccff, 0xff66ccff, 0xff33ccff, 0xff00ccff, 0xffff99ff, 0xffcc99ff, 0xff9999ff,
            0xff6699ff, 0xff3399ff, 0xff0099ff, 0xffff66ff, 0xffcc66ff, 0xff9966ff, 0xff6666ff, 0xff3366ff, 0xff0066ff, 0xffff33ff, 0xffcc33ff, 0xff9933ff, 0xff6633ff, 0xff3333ff, 0xff0033ff, 0xffff00ff,
            0xffcc00ff, 0xff9900ff, 0xff6600ff, 0xff3300ff, 0xff0000ff, 0xffffffcc, 0xffccffcc, 0xff99ffcc, 0xff66ffcc, 0xff33ffcc, 0xff00ffcc, 0xffffcccc, 0xffcccccc, 0xff99cccc, 0xff66cccc, 0xff33cccc,
            0xff00cccc, 0xffff99cc, 0xffcc99cc, 0xff9999cc, 0xff6699cc, 0xff3399cc, 0xff0099cc, 0xffff66cc, 0xffcc66cc, 0xff9966cc, 0xff6666cc, 0xff3366cc, 0xff0066cc, 0xffff33cc, 0xffcc33cc, 0xff9933cc,
            0xff6633cc, 0xff3333cc, 0xff0033cc, 0xffff00cc, 0xffcc00cc, 0xff9900cc, 0xff6600cc, 0xff3300cc, 0xff0000cc, 0xffffff99, 0xffccff99, 0xff99ff99, 0xff66ff99, 0xff33ff99, 0xff00ff99, 0xffffcc99,
            0xffcccc99, 0xff99cc99, 0xff66cc99, 0xff33cc99, 0xff00cc99, 0xffff9999, 0xffcc9999, 0xff999999, 0xff669999, 0xff339999, 0xff009999, 0xffff6699, 0xffcc6699, 0xff996699, 0xff666699, 0xff336699,
            0xff006699, 0xffff3399, 0xffcc3399, 0xff993399, 0xff663399, 0xff333399, 0xff003399, 0xffff0099, 0xffcc0099, 0xff990099, 0xff660099, 0xff330099, 0xff000099, 0xffffff66, 0xffccff66, 0xff99ff66,
            0xff66ff66, 0xff33ff66, 0xff00ff66, 0xffffcc66, 0xffcccc66, 0xff99cc66, 0xff66cc66, 0xff33cc66, 0xff00cc66, 0xffff9966, 0xffcc9966, 0xff999966, 0xff669966, 0xff339966, 0xff009966, 0xffff6666,
            0xffcc6666, 0xff996666, 0xff666666, 0xff336666, 0xff006666, 0xffff3366, 0xffcc3366, 0xff993366, 0xff663366, 0xff333366, 0xff003366, 0xffff0066, 0xffcc0066, 0xff990066, 0xff660066, 0xff330066,
            0xff000066, 0xffffff33, 0xffccff33, 0xff99ff33, 0xff66ff33, 0xff33ff33, 0xff00ff33, 0xffffcc33, 0xffcccc33, 0xff99cc33, 0xff66cc33, 0xff33cc33, 0xff00cc33, 0xffff9933, 0xffcc9933, 0xff999933,
            0xff669933, 0xff339933, 0xff009933, 0xffff6633, 0xffcc6633, 0xff996633, 0xff666633, 0xff336633, 0xff006633, 0xffff3333, 0xffcc3333, 0xff993333, 0xff663333, 0xff333333, 0xff003333, 0xffff0033,
            0xffcc0033, 0xff990033, 0xff660033, 0xff330033, 0xff000033, 0xffffff00, 0xffccff00, 0xff99ff00, 0xff66ff00, 0xff33ff00, 0xff00ff00, 0xffffcc00, 0xffcccc00, 0xff99cc00, 0xff66cc00, 0xff33cc00,
            0xff00cc00, 0xffff9900, 0xffcc9900, 0xff999900, 0xff669900, 0xff339900, 0xff009900, 0xffff6600, 0xffcc6600, 0xff996600, 0xff666600, 0xff336600, 0xff006600, 0xffff3300, 0xffcc3300, 0xff993300,
            0xff663300, 0xff333300, 0xff003300, 0xffff0000, 0xffcc0000, 0xff990000, 0xff660000, 0xff330000, 0xff0000ee, 0xff0000dd, 0xff0000bb, 0xff0000aa, 0xff000088, 0xff000077, 0xff000055, 0xff000044,
            0xff000022, 0xff000011, 0xff00ee00, 0xff00dd00, 0xff00bb00, 0xff00aa00, 0xff008800, 0xff007700, 0xff005500, 0xff004400, 0xff002200, 0xff001100, 0xffee0000, 0xffdd0000, 0xffbb0000, 0xffaa0000,
            0xff880000, 0xff770000, 0xff550000, 0xff440000, 0xff220000, 0xff110000, 0xffeeeeee, 0xffdddddd, 0xffbbbbbb, 0xffaaaaaa, 0xff888888, 0xff777777, 0xff555555, 0xff444444, 0xff222222, 0xff111111
        ];

        // set default color palette
        asset.colorPalette = VoxelColorPalette((cast(VoxelColor[])DEFAULT_PALETTE).dup);
        bool hasColorPalette = false;

        foreach (chunk; chunks) {
            switch (chunk.type) {
                case "RGBA": {
                    enforce(!hasColorPalette,
                        format("multiple color palette(s) in this file!"));
                    hasColorPalette = true;
                    asset.colorPalette = readColorPalette(chunk); 
                } break;
                case "MATL": break;
                case "rOBJ": break;
                case "rCAM": break; // 117 bytes
                case "nTRN": break; // 28 bytes - guess transform?
                case "nSHP": break; // 20 bytes
                case "nGRP": break; // 16 bytes
                case "NOTE": break;
                case "LAYR": break; // 26 bytes
                default: writefln("unhandled chunk %s (%s byte(s), %s children), data: '%s'",
                    chunk.type, chunk.data.length, chunk.childChunks.length, chunk.data);
            }
        }

        writefln("read %s voxel model(s) with dimension(s) %s, %s color palette with %s colorcolor(s)",
            asset.voxelModels.length,
            asset.voxelModels.map!(model => model.dimensions).array,
            hasColorPalette ? "model-defined" : "default",
            asset.colorPalette.palette.length
        );

        // validate that all voxel indices into our color palette are valid
        Voxel[] invalidVoxels;
        foreach (model; asset.voxelModels) {
            foreach (voxel; model.voxels) {
                if (voxel.i >= asset.colorPalette.palette.length) {
                    invalidVoxels ~= voxel;
                } 
            }
        }
        if (invalidVoxels.length) {
            writefln("%s invalid voxels (color palette indices are out of range of %s palette with %s color(s))!\n\t%s",
                invalidVoxels.length, 
                hasColorPalette ? "model-defined" : "default",
                asset.colorPalette.palette.length,
                invalidVoxels);
            return false;
        }

        } catch (Exception e) {
            writefln("%s", e);
            return false;
        }
        return true;
    }



