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

import std.format;
import std.exception;

struct VoxelAsset {
    string name;
    string filePath;

    // magicavoxel .vox reader, from spec https://github.com/ephtracy/voxel-model/blob/master/MagicaVoxel-file-format-vox.txt
    bool tryLoadAsset(string name, string filePath) {
        this.name = name;
        this.filePath = filePath;

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

        try {
            auto mainChunk = readChunk(data);
            enforce(mainChunk.type == "MAIN",
                format("expected 1st chunk type 'MAIN', got %s",
                    mainChunk.type));
            enforce(data.length == 0,
                format("unexpected %s byte(s) after 1st main chunk!",
                    data.length));

            printChunksRecursive(mainChunk);

            static struct VoxelDimensions { uint x, y, z; }
            static struct Voxel           { ubyte r, g, b, a; }
            static struct VoxelModel {
                VoxelDimensions dimensions;
                Voxel[]         vodels;
            }
            static VoxelModel readVoxelModel (ref Chunk[] chunks) {
                auto modelSize = expectChunkStruct!SIZE(chunks);

                enforce(modelSize.x > 0 && modelSize.y > 0 && modelSize.z > 0,
                    format("invalid model size: %s", modelSize));

                auto voxelData = expectChunk(chunks, "XYZI");

                uint expectedSize = modelSize.x * modelSize.y * modelSize.z * 4;
                enforce(voxelData.data.length == 4 + expectedSize,
                    format("expected 'XYZI' data size = (%s * %s * %s * 4 = %s) + 4 = %s, got %s",
                        modelSize.x, modelSize.y, modelSize.z,
                        expectedSize,
                        expectedSize + 4,
                        voxelData.data.length));

                int numVoxels = *(cast(int*)voxelData.data.ptr);
                enforce(numVoxels * 4 + 4 == voxelData.data.length,
                    format("expected %s * 4 + 4 == %s, got %s != %s",
                        numVoxels, voxelData.data.length,
                        numVoxels * 4 + 4, voxelData.data.length));

                assert(numVoxels == modelSize.x * modelSize.y * modelSize.z,
                    format("%s != %s * %s * %s", numVoxels, modelSize.x, modelSize.y, modelSize.z));

                auto voxels = (cast(Voxel[])voxelData.data)[1..$];
                assert(numVoxels == voxelData.data.length,
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

            auto chunks      = mainChunk.childChunks;
            auto voxelModels = readVoxelModels(chunks);
            

        } catch (Exception e) {
            writefln("%s", e);
            return false;
        }
        return true;
    }
}
