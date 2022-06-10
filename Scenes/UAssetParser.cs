using Godot;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Formatters.Binary;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using UAssetAPI;
using UAssetAPI.PropertyTypes;
using UAssetAPI.StructTypes;

public class UAssetParser : Control {

    /**
     * Maps package path of each .uasset or .umap (e.g. BloodstainedRotN/Content/Core/Environment/Common/Mesh/null.uasset) 
     * To the filename that it can be extracted from (e.g. C:/Bloodstained/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak)
     */
    private Godot.Collections.Dictionary<string, string> _assetPathToPakFilePathMap = default(Godot.Collections.Dictionary<string, string>);
    public Godot.Collections.Dictionary<string, string> AssetPathToPakFilePathMap {
        get {
            return _assetPathToPakFilePathMap;
        }
        set {
            _assetPathToPakFilePathMap = value;
        }
    }

    /**
     * Maps unique level name (e.g. m01SIP_000) to a mapping of level "asset type" to the package path where that asset can be loaded.
     * Asset types may include (but are not guaranteed to exist) bg, bg_built_data, enemy, enemy_normal, enemy_hard, gimmick, gimmick_built_data, event, setting, rv
     */
    private Godot.Collections.Dictionary<string, Godot.Collections.Dictionary<string, string>> _levelNameToAssetPathMap = new Godot.Collections.Dictionary<string, Godot.Collections.Dictionary<string, string>>();
    public Godot.Collections.Dictionary<string, Godot.Collections.Dictionary<string, string>> LevelNameToAssetPathMap {
        get {
            return _levelNameToAssetPathMap;
        }
        set {
            _levelNameToAssetPathMap = value;
        }
    }

    /**
     * 
     */
    private Godot.Collections.Dictionary<string, Godot.Collections.Array<string>> _characterMeshAssetPathMap = new Godot.Collections.Dictionary<string, Godot.Collections.Array<string>>();
    public Godot.Collections.Dictionary<string, Godot.Collections.Array<string>> CharacterMeshAssetPathMap {
        get {
            return _characterMeshAssetPathMap;
        }
        set {
            _characterMeshAssetPathMap = value;
        }
    }

    /**
     * Array of dictionaries, each dictionary contains all info for that map room. Keys converted to snake case.
     */
    private Godot.Collections.Array _mapRooms = default(Godot.Collections.Array);
    public Godot.Collections.Array MapRooms {
        get {
            return _mapRooms;
        }
        set {
            _mapRooms = value;
        }
    }

    /**
     * When EnsureModelCache is called, this dictionary is populated with lists of material/texture assets used by the model (by asset path)
     */
    private Godot.Collections.Dictionary<string, object> _cachedModelResourcesByAssetPath = new Godot.Collections.Dictionary<string, object>();
    public Godot.Collections.Dictionary<string, object> CachedModelResourcesByAssetPath {
        get {
            return _cachedModelResourcesByAssetPath;
        }
        set {
            _cachedModelResourcesByAssetPath = value;
        }
    }

    /**
     * Map of assetPath|modelName|modelNameInstance to assetPath where the model was actually located (package referenced had a _# at the end of the filename)
     */
    private Godot.Collections.Dictionary<string, string> _cachedModelReLookupAssetPaths = new Godot.Collections.Dictionary<string, string>();
    public Godot.Collections.Dictionary<string, string> CachedModelReLookupAssetPaths {
        get {
            return _cachedModelReLookupAssetPaths;
        }
        set {
            _cachedModelReLookupAssetPaths = value;
        }
    }

    public string UAssetExtractFolder = "";

    /**
     * Map of "filename|uassetPath|objectName" key to snippet object for blueprint reuse.
     */
    private Dictionary<string, UAssetSnippet> _blueprintSnippets = new Dictionary<string, UAssetSnippet>();

    /**
     * OS Library
     */

    enum SymbolicLink {
        File = 0,
        Directory = 1
    }

    [DllImport("kernel32.dll")]
    static extern bool CreateSymbolicLink(string lpSymlinkFileName, string lpTargetFileName, SymbolicLink dwFlags);

    /**
     * Lifecycle
     */

    public override void _Ready() {
        UAssetExtractFolder = ProjectSettings.GlobalizePath(@"user://PakExtract");
    }

    public void GuaranteeAssetListFromPakFiles() {
        if (_assetPathToPakFilePathMap == default(Godot.Collections.Dictionary<string, string>)) {
            ReadAssetListFromPakFiles();
        }
    }

    public void ReadAssetListFromPakFiles() {
        try {
            // Find all files in the game's "Paks" directory
            string gameDirectory = (string)GetNode("/root/Editor").Call("read_config_prop", "game_directory");
            string gamePakFilePath = gameDirectory + "/BloodstainedRotN/Content/Paks";
            string ueViewerPath = ProjectSettings.GlobalizePath(@"res://VendorBinary/UEViewer/umodel_64.exe");
            // string[] filesInPakDirectory = System.IO.Directory.GetFiles(gamePakFilePath);
            _assetPathToPakFilePathMap = new Godot.Collections.Dictionary<string, string>();

            // Loop through each file, check if it is a .pak file
            // foreach (string filePath in filesInPakDirectory) {
            //     string fileName = Regex.Split(filePath, @"[\\/]").Last();
            //     if (fileName.StartsWith("pakchunk")) {
            using (Process pathList = new Process()) {
                pathList.StartInfo.FileName = ueViewerPath;
                pathList.StartInfo.Arguments = " -path=\"" + gamePakFilePath + "\" -game=ue4.22 -pkginfo *";
                pathList.StartInfo.UseShellExecute = false;
                pathList.StartInfo.RedirectStandardOutput = true;
                pathList.Start();
                string output = pathList.StandardOutput.ReadToEnd();
                pathList.WaitForExit();
                string[] packageInfoLines = output.Split("\n");

                // For each package path found in the .pak file, store in a dictionary in memory that specifies which .pak file it was found in
                foreach (string packageInfoLine in packageInfoLines) {
                    if (!packageInfoLine.StartsWith("Loading package:")) continue;
                    string packagePath = packageInfoLine.Replace("Loading package: /Game/", "BloodstainedRotN/Content/");
                    if (packagePath.IndexOf(".uasset") > -1) {
                        packagePath = packagePath.Substring(0, packagePath.IndexOf(".uasset") + 7); 
                    }
                    if (packagePath.IndexOf(".umap") > -1) {
                        packagePath = packagePath.Substring(0, packagePath.IndexOf(".umap") + 5);
                    }

                    _assetPathToPakFilePathMap[packagePath] = "pakchunk0-WindowsNoEditor.pak"; // filePath;

                    // Add any character model assets we find to a separate list for easy reading
                    if (Regex.Match(packagePath, @"^BloodstainedRotN/Content/Core/Character/[^/]*?/Mesh/").Success) {
                        string[] pathSplit = packagePath.Split("/");
                        string characterId = "";
                        bool hasFoundCharacterFolder = false;
                        foreach (string folderName in pathSplit) {
                            if (hasFoundCharacterFolder) {
                                characterId = folderName;
                                break;
                            }
                            if (folderName == "Character") {
                                hasFoundCharacterFolder = true;
                            }
                        }
                        Godot.Collections.Array<string> characterMeshAssets = default(Godot.Collections.Array<string>);
                        if (_characterMeshAssetPathMap.ContainsKey(characterId)) {
                            characterMeshAssets = _characterMeshAssetPathMap[characterId];
                        } else {
                            characterMeshAssets = new Godot.Collections.Array<string>();
                            _characterMeshAssetPathMap[characterId] = characterMeshAssets;
                        }
                        characterMeshAssets.Add(packagePath);
                    }

                    // Add any room/level assets we find to a separate list for easy reading
                    if (Regex.Match(packagePath, @"^BloodstainedRotN/Content/Core/Environment/[^/]*?/Level/m[0-9]{2}[A-Z]{3}_[0-9]{3}").Success) {
                        string packageName = packagePath.Split("/").Last();
                        string levelName = packageName.Substring(0, 10);
                        Godot.Collections.Dictionary<string, string> roomPackageDef = default(Godot.Collections.Dictionary<string, string>);
                        if (_levelNameToAssetPathMap.ContainsKey(levelName)) {
                            roomPackageDef = _levelNameToAssetPathMap[levelName];
                        } else {
                            roomPackageDef = new Godot.Collections.Dictionary<string, string>();
                            _levelNameToAssetPathMap[levelName] = roomPackageDef;
                        }
                        if (packageName.EndsWith("_BG.umap")) {
                            roomPackageDef["bg"] = packagePath;
                        } else if (packageName.EndsWith("_BG_BuiltData.uasset")) {
                            roomPackageDef["bg_built_data"] = packagePath;
                        } else if (packageName.EndsWith("_Enemy.umap")) {
                            roomPackageDef["enemy"] = packagePath;
                        } else if (packageName.EndsWith("_Enemy_Normal.umap")) {
                            roomPackageDef["enemy_normal"] = packagePath;
                        } else if (packageName.EndsWith("_Enemy_Hard.umap")) {
                            roomPackageDef["enemy_hard"] = packagePath;
                        } else if (packageName.EndsWith("_Gimmick.umap")) {
                            roomPackageDef["gimmick"] = packagePath;
                        } else if (packageName.EndsWith("_Gimmick_BuiltData.uasset")) {
                            roomPackageDef["gimmick_built_data"] = packagePath;
                        } else if (packageName.EndsWith("_Event.umap")) {
                            roomPackageDef["event"] = packagePath;
                        } else if (packageName.EndsWith("_Light.umap") || packageName.EndsWith("_Ljght.umap")) {
                            roomPackageDef["light"] = packagePath;
                        } else if (packageName.EndsWith("_Light_BuiltData.uasset") || packageName.EndsWith("_Ljght_BuiltData.uasset")) {
                            roomPackageDef["light_built_data"] = packagePath;
                        } else if (packageName.EndsWith("_Setting.umap")) {
                            roomPackageDef["setting"] = packagePath;
                        } else if (packageName.EndsWith("_Setting_BuiltData.uasset")) {
                            roomPackageDef["setting_built_data"] = packagePath;
                        } else if (packageName.EndsWith("_RV.umap")) {
                            roomPackageDef["rv"] = packagePath;
                        }
                    }
                }
            }
        //         }
        //     }
        } catch (Exception e) {
            GD.Print(e);
        }
    }

    public void GuaranteeMapData() {
        if (_mapRooms == default(Godot.Collections.Array)) {
            ReadMapData();
        }
    }

    public void ReadMapData() {
        try {
            _mapRooms = new Godot.Collections.Array();

            // Extract map data to uasset
            string outputPath = UAssetExtractFolder;
            string mapDataTablePath = "BloodstainedRotN/Content/Core/DataTable/PB_DT_RoomMaster.uasset";

            if (!_assetPathToPakFilePathMap.ContainsKey(mapDataTablePath)) {
                GD.Print("Unable to find map data package in AssetPathToPakFilePathMap");
                return;
            }

            ExtractAssetToFolder(_assetPathToPakFilePathMap[mapDataTablePath], mapDataTablePath, outputPath);

            // Parse map data uasset
            UAsset uAsset = new UAsset(outputPath + "/" + mapDataTablePath, UE4Version.VER_UE4_22);
            foreach (Export baseExport in uAsset.Exports) {
                // Data table
                if (baseExport is DataTableExport export) {
                    if (export.ObjectName.Value.ToString() == "PB_DT_RoomMaster") {
                        // Loop through table rows
                        foreach (StructPropertyData structPropertyData in export.Table.Data) {
                            Godot.Collections.Dictionary<string, object> mapRoom = new Godot.Collections.Dictionary<string, object>();
                            foreach (PropertyData propertyData in structPropertyData.Value) {
                                string propertyName = propertyData.Name.Value.ToString();
                                string propertyNameSnakeCase = CamelCaseToSnakeCase(propertyName);
                                try {
                                    if (propertyData is NamePropertyData namePropertyData) {
                                        mapRoom[propertyNameSnakeCase] = namePropertyData.Value.Value.ToString();
                                    } else if (propertyData is StrPropertyData strPropertyData) {
                                        FString strPropertyValue = strPropertyData.Value;
                                        mapRoom[propertyNameSnakeCase] = (strPropertyValue == null) ? null : strPropertyValue.Value;
                                    } else if (propertyData is BytePropertyData bytePropertyData) {
                                        mapRoom[propertyNameSnakeCase] = bytePropertyData.Value.ToString();
                                    } else if (propertyData is BoolPropertyData boolPropertyData) {
                                        mapRoom[propertyNameSnakeCase] = boolPropertyData.Value;
                                    } else if (propertyData is IntPropertyData intPropertyData) {
                                        mapRoom[propertyNameSnakeCase] = intPropertyData.Value;
                                    } else if (propertyData is FloatPropertyData floatPropertyData) {
                                        mapRoom[propertyNameSnakeCase] = floatPropertyData.Value;
                                    } else if (propertyData is EnumPropertyData enumPropertyData) {
                                        mapRoom[propertyNameSnakeCase] = enumPropertyData.Value.Value.ToString();
                                    } else if (propertyData is ArrayPropertyData arrayPropertyData) {
                                        Godot.Collections.Array refArray = new Godot.Collections.Array();
                                        foreach (PropertyData arrayItem in arrayPropertyData.Value) {
                                            if (arrayItem is NamePropertyData arrayNamePropertyData) {
                                                refArray.Add(arrayNamePropertyData.Value.Value.ToString());
                                            } else if (arrayItem is IntPropertyData arrayIntPropertyData) {
                                                refArray.Add(arrayIntPropertyData.Value);
                                            }
                                        }
                                        mapRoom[propertyNameSnakeCase] = refArray;
                                    }
                                } catch (Exception e) {
                                    GD.Print(propertyName);
                                    GD.Print(e);
                                }
                            }
                            _mapRooms.Add(mapRoom);
                        }
                    }
                }
            }
        } catch (Exception e) {
            GD.Print(e);
        }
    }

    public void ExtractAssetToFolder(string pakFilePath, string assetPath, string outputFolderPath) {
        // Extract uasset
        string gameDirectory = (string)GetNode("/root/Editor").Call("read_config_prop", "game_directory");
        string gamePakFilePath = gameDirectory + "/BloodstainedRotN/Content/Paks";
        string ueViewerPath = ProjectSettings.GlobalizePath(@"res://VendorBinary/UEViewer/umodel_64.exe");
        using (Process unpack = new Process()) {
            unpack.StartInfo.FileName = ueViewerPath;
            unpack.StartInfo.Arguments = " -path=\"" + gamePakFilePath + "\" -out=\"" + outputFolderPath.Replace("/", "\\") + "\" -save -keepdirectorystructure \"" + assetPath.Replace("\\", "/").Replace(".uasset", "").Replace("BloodstainedRotN/Content/", "Game/") + "\"";
            // unpack.StartInfo.Arguments = " unpack -o " + "\"" + outputFolderPath.Replace("/", "\\") + "\" \"" + pakFilePath.Replace("/", "\\") + "\" \"" + assetPath.Replace("\\", "/") + "\"";
            unpack.StartInfo.UseShellExecute = false;
            unpack.StartInfo.RedirectStandardOutput = true;
            unpack.Start();
            string output = unpack.StandardOutput.ReadToEnd();
            unpack.WaitForExit();
            string[] outputLines = output.Split("\n");
            foreach (string line in outputLines) {
                if (line.StartsWith("Saving: ")) {
                    string filePath = line.Replace("Saving: ", "").Trim();
                    string copyFrom = filePath.Replace("//", "/").Replace("/", @"\");
                    string copyTo = filePath.Replace("//", "/").Replace("/Game/", "/BloodstainedRotN/Content/").Replace("/", @"\");
                    System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(copyTo));
                    System.IO.File.Delete(copyTo);
                    System.IO.File.Move(copyFrom, copyTo);
                }
            }
        }
    }

    public void ExtractRoomAssets(string levelName) {
        try {
            Godot.Collections.Dictionary<string, string> levelAssets = _levelNameToAssetPathMap[levelName];
            string outputFolder = UAssetExtractFolder;
            foreach (string key in levelAssets.Keys) {
                if (!System.IO.File.Exists(outputFolder + "/" + levelAssets[key])) {
                    ExtractAssetToFolder(_assetPathToPakFilePathMap[levelAssets[key]], levelAssets[key], outputFolder);
                }
            }
        } catch (Exception e) {
            GD.Print(e);
        }
    }

    private string EnsureModelCache(string assetPath, string meshName, int meshNameInstance) {
        string newAssetPath = assetPath;
        try {
            string extractAssetOutputFolder = UAssetExtractFolder;
            string extractModelOutputFolder = ProjectSettings.GlobalizePath(@"user://ModelCache");
            string ueViewerPath = ProjectSettings.GlobalizePath(@"res://VendorBinary/UEViewer/umodel_64.exe");

            // Extract model uasset to output folder
            if (!_cachedModelReLookupAssetPaths.ContainsKey(assetPath + "|" + meshName + "|" + meshNameInstance)) {
                List<string> assetPartPaths = new List<string>();
                UAsset uAsset;
                for (int i = -1; i < 20; i++) {
                    string suffix = (i == -1 ? "" : "_" + i);
                    string assetPathWithSuffix = assetPath.Replace(".uasset", "") + suffix + ".uasset";
                    if (_assetPathToPakFilePathMap.ContainsKey(assetPathWithSuffix)) {
                        assetPartPaths.Add(assetPathWithSuffix);
                        // Extract assets to asset cache
                        if (!System.IO.File.Exists(extractAssetOutputFolder + "/" + assetPathWithSuffix)) {
                            _cachedModelResourcesByAssetPath.Remove(assetPathWithSuffix);
                            ExtractAssetToFolder(_assetPathToPakFilePathMap[assetPathWithSuffix], assetPathWithSuffix, extractAssetOutputFolder);
                        }
                        if (i > -1 && System.IO.File.Exists(extractAssetOutputFolder + "/" + assetPathWithSuffix)) {
                            uAsset = new UAsset(extractAssetOutputFolder + '/' + assetPathWithSuffix, UE4Version.VER_UE4_22);
                            foreach (Export export in uAsset.Exports) {
                                if (export.bIsAsset && export.ObjectName.Value.Value == meshName && export.ObjectName.Number == meshNameInstance) {
                                    newAssetPath = assetPathWithSuffix;
                                    break;
                                }
                            }
                        }
                        if (newAssetPath != assetPath) {
                            _cachedModelReLookupAssetPaths[assetPath + "|" + meshName + "|" + meshNameInstance] = newAssetPath;
                            break;
                        }
                    }
                }
                uAsset = null;
            } else {
                newAssetPath = _cachedModelReLookupAssetPaths[assetPath + "|" + meshName + "|" + meshNameInstance];
            }

            if (System.IO.File.Exists(extractAssetOutputFolder + "/" + newAssetPath)) {
                // Extract material imports inside model
                if (!_cachedModelResourcesByAssetPath.ContainsKey(newAssetPath)) {
                    // _cachedModelResourcesByAssetPath[newAssetPath] = ExtractModelMaterialsRecursive(newAssetPath);
                }

                // Extract gltf and png textures from model uasset
                string gltfOutputPath = extractModelOutputFolder + "/" + newAssetPath.Replace(".uasset", ".gltf");
                if (!System.IO.File.Exists(gltfOutputPath)) {
                    using (Process ueExtract = new Process()) {
                        ueExtract.StartInfo.FileName = ueViewerPath;
                        ueExtract.StartInfo.Arguments = @" -export -path=" + "\"" + extractAssetOutputFolder + "\"" + @" -out=" + "\"" + extractModelOutputFolder + "/BloodstainedRotN/Content/\"" + @" -game=ue4.22 -gltf -png " + newAssetPath;
                        ueExtract.StartInfo.UseShellExecute = false;
                        ueExtract.StartInfo.RedirectStandardOutput = true;
                        ueExtract.StartInfo.RedirectStandardError = true;
                        ueExtract.Start();
                        string output = ueExtract.StandardOutput.ReadToEnd();
                        string error = ueExtract.StandardError.ReadToEnd();
                        ueExtract.WaitForExit();
                    }
                }

                if (System.IO.File.Exists(gltfOutputPath)) {
                    JObject gltfJson = default(JObject);
                    using (StreamReader reader = System.IO.File.OpenText(gltfOutputPath)) {
                        gltfJson = (JObject)JToken.ReadFrom(new JsonTextReader(reader));
                        if (gltfJson.ContainsKey("nodes")) {
                            JArray nodes = (JArray)gltfJson["nodes"];
                            foreach (JObject node in nodes) {
                                if (node.ContainsKey("skin")) {
                                    node.Remove("skin");
                                }
                            }
                        }
                    }
                    System.IO.File.WriteAllText(gltfOutputPath, gltfJson.ToString());
                }
            }
        } catch (Exception e) {
            GD.Print("Error extracting model asset: ", assetPath);
            GD.Print(e);
        }
        return newAssetPath;
    }

    public Godot.Collections.Array<Godot.Collections.Dictionary<string, object>> ExtractModelMaterialsRecursive(string assetPath, Godot.Collections.Array<Godot.Collections.Dictionary<string, object>> extractedMaterials = default(Godot.Collections.Array<Godot.Collections.Dictionary<string, object>>), int materialIndex = -1) {
        if (extractedMaterials == default(Godot.Collections.Array<Godot.Collections.Dictionary<string, object>>)) {
            extractedMaterials = new Godot.Collections.Array<Godot.Collections.Dictionary<string, object>>();
        }
        string extractAssetOutputFolder = UAssetExtractFolder;
        string assetFileName = assetPath.Split("/").Last();
        try {
            UAsset asset = new UAsset(extractAssetOutputFolder + "/" + assetPath, UE4Version.VER_UE4_22);
            string assetType = "mesh";
            if (assetFileName.StartsWith("MI_") || assetFileName.StartsWith("M_") || assetFileName.StartsWith("MIP_")) {
                assetType = "material";
            } else if (assetFileName.StartsWith("T_")) {
                assetType = "texture";
            }
            // Assume is mesh
            if (assetType == "mesh") {
                foreach (Export baseExport in asset.Exports) {
                    if (baseExport.bIsAsset && baseExport is NormalExport export) {
                        foreach (PropertyData propertyData in export.Data) {
                            string propertyName = propertyData.Name.Value.Value;
                            if (propertyName == "StaticMaterials" && propertyData is ArrayPropertyData staticMaterialsData) {
                                foreach (PropertyData staticMaterial in staticMaterialsData.Value) {
                                    if (staticMaterial is StructPropertyData staticMaterialStruct) {
                                        foreach (PropertyData staticMaterialProperty in staticMaterialStruct.Value) {
                                            string staticMaterialPropertyName = staticMaterialProperty.Name.Value.Value;
                                            if (staticMaterialPropertyName == "MaterialInterface") {
                                                if (staticMaterialProperty is ObjectPropertyData materialInterface) {
                                                    if (materialInterface.Value.IsImport()) {
                                                        Godot.Collections.Dictionary<string, object> materialDictionary = new Godot.Collections.Dictionary<string, object>();
                                                        materialDictionary["material_name"] = materialInterface.Value.ToImport(asset).ObjectName.Value.Value;
                                                        materialDictionary["texture"] = new Godot.Collections.Dictionary<string, string>();
                                                        extractedMaterials.Add(materialDictionary);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        break;
                    }
                }
            }
            // Build list of materials.
            foreach (Import import in asset.Imports) {
                if (import.ClassName.Value.Value == "Package") {
                    if (import.ObjectName.Value.Value.StartsWith("/Game")) {
                        string packageFileName = import.ObjectName.Value.Value.Split("/").Last();
                        if (packageFileName.StartsWith("MI_") || packageFileName.StartsWith("M_") || packageFileName.StartsWith("MIP_")) {
                            string materialAssetPath = import.ObjectName.Value.Value.Replace("/Game/", "BloodstainedRotN/Content/") + ".uasset";
                            bool isParentMaterial = false;
                            if (materialIndex == -1) {
                                isParentMaterial = true;
                                for (materialIndex = 0; materialIndex < extractedMaterials.Count; materialIndex++) {
                                    if ((string)extractedMaterials[materialIndex]["material_name"] == packageFileName) {
                                        break;
                                    }
                                }
                            }
                            if (!isParentMaterial) {
                                extractedMaterials[materialIndex]["material_asset_path"] = materialAssetPath;
                            }
                            try {
                                if (!System.IO.File.Exists(extractAssetOutputFolder + "/" + materialAssetPath)) {
                                    ExtractAssetToFolder(_assetPathToPakFilePathMap[materialAssetPath], materialAssetPath, extractAssetOutputFolder);
                                }
                                extractedMaterials = ExtractModelMaterialsRecursive(materialAssetPath, extractedMaterials, materialIndex);
                            } catch (Exception e) {
                                GD.Print("Failed to extract material " + materialAssetPath);
                                GD.Print(e);
                            }
                        }
                        else if (packageFileName.StartsWith("T_")) {
                            Godot.Collections.Dictionary<string, object> materialDef = extractedMaterials[materialIndex];
                            Godot.Collections.Dictionary textureDef = (Godot.Collections.Dictionary)materialDef["texture"];
                            string textureAssetPath = import.ObjectName.Value.Value.Replace("/Game/", "BloodstainedRotN/Content/") + ".uasset";
                            try {
                                if (!System.IO.File.Exists(extractAssetOutputFolder + "/" + textureAssetPath)) {
                                    ExtractAssetToFolder(_assetPathToPakFilePathMap[textureAssetPath], textureAssetPath, extractAssetOutputFolder);
                                }
                            } catch (Exception e) {
                                GD.Print("Failed to extract texture " + textureAssetPath);
                                GD.Print(e);
                            }
                            try {
                                object whatever = textureDef["albedo"];
                            } catch (Exception e) {
                                if (packageFileName.EndsWith("_D") || packageFileName.EndsWith("_Col") || packageFileName.EndsWith("_Color")) {
                                    textureDef["albedo"] = textureAssetPath;
                                }
                            }
                            try {
                                object whatever = textureDef["normal"];
                            } catch (Exception e) {
                                if (packageFileName.EndsWith("_N")) {
                                    textureDef["normal"] = textureAssetPath;
                                }
                            }
                            try {
                                object whatever = textureDef["roughness"];
                            } catch (Exception e) {
                                if (
                                    (packageFileName.EndsWith("_RoMaAo") || packageFileName.EndsWith("_ORM") || packageFileName.EndsWith("_AoMeGI"))
                                ) {
                                    textureDef["roughness"] = textureAssetPath;
                                }
                            }
                            try {
                                object whatever = textureDef["metallic"];
                            } catch (Exception e) {
                                if (
                                    (packageFileName.EndsWith("_RoMaAo") || packageFileName.EndsWith("_ORM") || packageFileName.EndsWith("_AoMeGI"))
                                ) {
                                    textureDef["metallic"] = textureAssetPath;
                                }
                            }
                            try {
                                object whatever = textureDef["ao"];
                            } catch (Exception e) {
                                if (
                                    (packageFileName.EndsWith("_RoMaAo") || packageFileName.EndsWith("_ORM"))
                                ) {
                                    textureDef["ao"] = textureAssetPath;
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            GD.Print(e);
        }
        return extractedMaterials;
    }

    public void PackageAndInstallMod(string packageName) {
        GuaranteeAssetListFromPakFiles();
        try {
            string gameDirectory = (string)GetNode("/root/Editor").Call("read_config_prop", "game_directory");
            string selectedPackageName = packageName;
            string unrealPakPath = ProjectSettings.GlobalizePath(@"res://VendorBinary/UnrealPak/UnrealPak.exe");
            string pakExtractFolder = UAssetExtractFolder;
            string filelistPath = ProjectSettings.GlobalizePath(@"user://UserPackages/" + selectedPackageName + "/PackageFileList.txt");
            string modifiedAssetsFolder = ProjectSettings.GlobalizePath(@"user://UserPackages/" + selectedPackageName + "/ModifiedAssets");
            string editsFolder = ProjectSettings.GlobalizePath(@"user://UserPackages/" + selectedPackageName + "/Edits").Replace("\\", "/");
            string outputPakFilePath = ProjectSettings.GlobalizePath(@"user://UserPackages/" + selectedPackageName + "/ModifiedAssets.pak");
            string gamePakLinkPath = gameDirectory + "/BloodstainedRotN/Content/Paks/~BloodstainedLevelEditor/" + selectedPackageName + ".pak";

            // Modify .uasset files based on room edit .json files
            foreach (string file in FileExt.GetFilesRecursive(editsFolder)) {
                string filePath = file.Replace("\\", "/");
                string assetBasePath = filePath.Replace(editsFolder + "/", "").Replace(".json", "");
                bool editsJsonHasChanges = false;
                JObject editsJson;
                using (StreamReader reader = System.IO.File.OpenText(filePath)) {
                    editsJson = (JObject)JToken.ReadFrom(new JsonTextReader(reader));
                    editsJsonHasChanges = editsJson.ContainsKey("has_changes") && editsJson["has_changes"].Value<bool>() == true;
                    if (editsJsonHasChanges) {
                        GD.Print("Applying modifications from ", filePath);
                        List<System.Collections.Generic.Dictionary<string, string>> assetsToCheck = new List<System.Collections.Generic.Dictionary<string, string>>();
                        assetsToCheck.Add(
                            new System.Collections.Generic.Dictionary<string, string>{
                                { "key", "bg" },
                                { "suffix", "_BG.umap" }
                            }
                        );
                        assetsToCheck.Add(
                            new System.Collections.Generic.Dictionary<string, string>{
                                { "key", "gimmick" },
                                { "suffix", "_Gimmick.umap" }
                            }
                        );
                        assetsToCheck.Add(
                            new System.Collections.Generic.Dictionary<string, string>{
                                { "key", "enemy" },
                                { "suffix", "_Enemy.umap" }
                            }
                        );
                        assetsToCheck.Add(
                            new System.Collections.Generic.Dictionary<string, string>{
                                { "key", "enemy_normal" },
                                { "suffix", "_Enemy_Normal.umap" }
                            }
                        );
                        assetsToCheck.Add(
                            new System.Collections.Generic.Dictionary<string, string>{
                                { "key", "enemy_hard" },
                                { "suffix", "_Enemy_Hard.umap" }
                            }
                        );
                        assetsToCheck.Add(
                            new System.Collections.Generic.Dictionary<string, string>{
                                { "key", "setting" },
                                { "suffix", "_Setting.umap" }
                            }
                        );
                        foreach (System.Collections.Generic.Dictionary<string, string> checkDef in assetsToCheck) {
                            if (editsJson.ContainsKey(checkDef["key"]) && AssetPathToPakFilePathMap.ContainsKey(assetBasePath + checkDef["suffix"])) {
                                if (editsJson[checkDef["key"]]["existing_exports"].Count() > 0 || editsJson[checkDef["key"]]["new_exports"].Count() > 0) {
                                    ExtractAssetToFolder(AssetPathToPakFilePathMap[assetBasePath + checkDef["suffix"]], assetBasePath + checkDef["suffix"], modifiedAssetsFolder);
                                    UAsset uAsset = new UAsset(modifiedAssetsFolder + "/" + assetBasePath + checkDef["suffix"], UE4Version.VER_UE4_22);
                                    UMapAsDictionaryTree.ModifyAssetFromEditsJson(uAsset, (JObject)editsJson[checkDef["key"]]);
                                    uAsset.Write(modifiedAssetsFolder + "/" + assetBasePath + checkDef["suffix"]);
                                } else {
                                    if (System.IO.File.Exists(modifiedAssetsFolder + "/" + assetBasePath + checkDef["suffix"])) {
                                        System.IO.File.Delete(modifiedAssetsFolder + "/" + assetBasePath + checkDef["suffix"]);
                                    }
                                }
                            }
                        }
                    }
                }
                if (editsJsonHasChanges) {
                    try {
                        editsJson.Remove("has_changes");
                        System.IO.File.WriteAllText(filePath, editsJson.ToString());
                    } catch (Exception e) {
                        GD.Print(e);
                    }
                }
            }

            // Package uassets
            System.IO.File.WriteAllText(filelistPath, "\"" + modifiedAssetsFolder.Replace("/", "\\") + "\\*.*\" \"..\\..\\..\\*.*\"");
            using (Process pack = new Process()) {
                pack.StartInfo.FileName = unrealPakPath;
                pack.StartInfo.Arguments = " \"" + outputPakFilePath.Replace("/", "\\") + "\" \"-Create=" + filelistPath.Replace("/", "\\") + "\"";
                pack.StartInfo.UseShellExecute = false;
                pack.StartInfo.RedirectStandardOutput = true;
                pack.Start();
                pack.WaitForExit();
            }
            System.IO.File.Copy(outputPakFilePath, gamePakLinkPath, true);
        } catch (Exception e) {
            GD.Print(e);
        }
    }

    public void ParseBlueprintForReuse(string pakFilePath, string assetPath, string objectName) {
        // Extract uasset
        string outputPath = UAssetExtractFolder;
        if (!System.IO.File.Exists(outputPath + "/" + assetPath)) {
            ExtractAssetToFolder(pakFilePath, assetPath, outputPath);
        }

        // Parse uasset
        try {
            GD.Print("Parsing UAsset ", assetPath);
            UAsset uAsset = new UAsset(outputPath + "/" + assetPath, UE4Version.VER_UE4_22);
            GD.Print("Data preserved: " + (uAsset.VerifyBinaryEquality() ? "YES" : "NO"));

            int blueprintExportIndex = -1;

            // Find the index of the export we want
            int exportIndex = 0;
            foreach (Export baseExport in uAsset.Exports) {
                if (baseExport is NormalExport export) {
                    FName objectFName = export.ObjectName;
                    if (objectName == objectFName.Value + "(" +  objectFName.Number + ")") {
                        blueprintExportIndex = exportIndex;
                        break;
                    }
                }
                exportIndex++;
            }

            if (blueprintExportIndex == -1) {
                GD.Print("Blueprint export not found: ", objectName);
                return;
            }

            UAssetSnippet snippet = new UAssetSnippet(uAsset, blueprintExportIndex);
            _blueprintSnippets[pakFilePath + "|" + assetPath + "|" + objectName] = snippet;

        } catch (Exception e) {
            GD.Print(e);
        }
    }

    public void ParseEnemyDefinitionsToUserProjectFolder(Godot.Collections.Array<Godot.Collections.Dictionary> blueprintLocations) {
        string gameDirectory = (string)GetNode("/root/Editor").Call("read_config_prop", "game_directory");
        string selectedPackageName = (string)GetNode("/root/Editor").Get("selected_package");
        string userProjectPath = ProjectSettings.GlobalizePath(@"user://UserPackages/" + selectedPackageName);
        foreach (Godot.Collections.Dictionary blueprintDef in blueprintLocations) {
            ParseBlueprintForReuse(gameDirectory + "/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak", (string)blueprintDef["example_placement_package"], (string)blueprintDef["example_placement_export_object_name"]);
            ExtractAssetToFolder(gameDirectory + "/BloodstainedRotN/Content/Paks/pakchunk0-WindowsNoEditor.pak", (string)blueprintDef["example_placement_package"], userProjectPath + "/ModifiedAssets");
        }
    }

    public void AddBlueprintToAsset(
        string blueprintPakFilePath,
        string blueprintAssetPath,
        string blueprintObjectName,
        string targetAssetFilePath
    ) {
        string dictionaryKey = blueprintPakFilePath + "|" + blueprintAssetPath + "|" + blueprintObjectName;
        if (_blueprintSnippets.ContainsKey(dictionaryKey)) {
            UAssetSnippet snippet = _blueprintSnippets[dictionaryKey];
            GD.Print("Parsing UAsset ", targetAssetFilePath);
            UAsset uAsset = new UAsset(targetAssetFilePath, UE4Version.VER_UE4_22);
            GD.Print("Data preserved: " + (uAsset.VerifyBinaryEquality() ? "YES" : "NO"));
            snippet.AddToUAsset(uAsset);
            uAsset.Write(targetAssetFilePath);
        } else {
            GD.Print("Cached blueprint not found. ", dictionaryKey);
        }
    }

    public Godot.Collections.Dictionary<string, object> GetRoomDefinition(string levelName) {
        try {
            ExtractRoomAssets(levelName);
            string outputFolder = UAssetExtractFolder;
            Godot.Collections.Dictionary<string, object> roomDefinition = new Godot.Collections.Dictionary<string, object>();
            Godot.Collections.Dictionary<string, string> levelAssets = _levelNameToAssetPathMap[levelName];
            string[] checkKeys = new string[]{ "bg", "enemy", "enemy_hard", "enemy_normal", "event", "gimmick", "light", "setting", "rv" };
            foreach (string key in checkKeys) {
                if (levelAssets.ContainsKey(key)) {
                    roomDefinition[key] = UMapAsDictionaryTree.ToDictionaryTree(new UAsset(outputFolder + "/" + levelAssets[key], UE4Version.VER_UE4_22), this);
                }
            }
            return roomDefinition;
        } catch (Exception e) {
            GD.Print(e);
            return new Godot.Collections.Dictionary<string, object>();
        }
    }

    public static string CamelCaseToSnakeCase(string text) {
        if (text == null) {
            throw new ArgumentNullException(nameof(text));
        }
        if (text.Length < 2) {
            return text;
        }
        var sb = new StringBuilder();
        sb.Append(char.ToLowerInvariant(text[0]));
        for (int i = 1; i < text.Length; ++i) {
            char c = text[i];
            if (char.IsUpper(c)) {
                sb.Append('_');
                sb.Append(char.ToLowerInvariant(c));
            } else {
                sb.Append(c);
            }
        }
        return sb.ToString();
    }
}