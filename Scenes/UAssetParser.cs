using Godot;
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

    }

    public void GuaranteeAssetListFromPakFiles() {
        if (_assetPathToPakFilePathMap == default(Godot.Collections.Dictionary<string, string>)) {
            ReadAssetListFromPakFiles();
        }
    }

    public void ReadAssetListFromPakFiles() {
        // Find all files in the game's "Paks" directory
        string gameDirectory = (string)GetNode("/root/Editor").Call("read_config_prop", "game_directory");
        string gamePakFilePath = gameDirectory + "/BloodstainedRotN/Content/Paks";
        string u4pakPath = ProjectSettings.GlobalizePath(@"res://VendorBinary/U4pak/u4pak.exe");
        string[] filesInPakDirectory = System.IO.Directory.GetFiles(gamePakFilePath);
        _assetPathToPakFilePathMap = new Godot.Collections.Dictionary<string, string>();

        // Loop through each file, check if it is a .pak file
        foreach (string filePath in filesInPakDirectory) {
            string fileName = Regex.Split(filePath, @"[\\/]").Last();
            if (fileName.StartsWith("pakchunk")) {
                using (Process pathList = new Process()) {
                    pathList.StartInfo.FileName = u4pakPath;
                    pathList.StartInfo.Arguments = @" list -n " + "\"" + filePath + "\"";
                    pathList.StartInfo.UseShellExecute = false;
                    pathList.StartInfo.RedirectStandardOutput = true;
                    pathList.Start();
                    string output = pathList.StandardOutput.ReadToEnd();
                    pathList.WaitForExit();
                    string[] packagePaths = output.Split("\n");

                    // For each package path found in the .pak file, store in a dictionary in memory that specifies which .pak file it was found in
                    foreach (string packagePath in packagePaths) {
                        _assetPathToPakFilePathMap[packagePath] = filePath;

                        // Add any room/level assets we find to a separate list for easy reading
                        if (Regex.Match(packagePath, @"^BloodstainedRotN/Content/Core/Environment/[^/]*?/Level/m[0-9]{2}[A-Z]{3}_[0-9]{3}").Success) {
                            string packageName = packagePath.Split("/").Last();
                            string levelName = packageName.Substring(0, 10);
                            Godot.Collections.Dictionary<string, string> roomPackageDef = default(Godot.Collections.Dictionary<string, string>);
                            try {
                                roomPackageDef = _levelNameToAssetPathMap[levelName];
                            } catch (Exception e) {
                                roomPackageDef = new Godot.Collections.Dictionary<string, string>();
                                _levelNameToAssetPathMap[levelName] = roomPackageDef;
                            }
                            if (packageName.EndsWith("_BG.umap")) {
                                roomPackageDef["bg"] = packagePath;
                            } else if (packageName.EndsWith("_BG_BuiltData.umap")) {
                                roomPackageDef["bg_built_data"] = packagePath;
                            } else if (packageName.EndsWith("_Enemy.umap")) {
                                roomPackageDef["enemy"] = packagePath;
                            } else if (packageName.EndsWith("_Enemy_Normal.umap")) {
                                roomPackageDef["enemy_normal"] = packagePath;
                            } else if (packageName.EndsWith("_Enemy_Hard.umap")) {
                                roomPackageDef["enemy_hard"] = packagePath;
                            } else if (packageName.EndsWith("_Gimmick.umap")) {
                                roomPackageDef["gimmick"] = packagePath;
                            } else if (packageName.EndsWith("_Gimmick_BuiltData.umap")) {
                                roomPackageDef["gimmick_built_data"] = packagePath;
                            } else if (packageName.EndsWith("_Event.umap")) {
                                roomPackageDef["event"] = packagePath;
                            } else if (packageName.EndsWith("_Setting.umap")) {
                                roomPackageDef["setting"] = packagePath;
                            } else if (packageName.EndsWith("_RV.umap")) {
                                roomPackageDef["rv"] = packagePath;
                            }
                        }
                    }
                }
            }
        }
    }

    public void GuaranteeMapData() {
        if (_mapRooms == default(Godot.Collections.Array)) {
            ReadMapData();
        }
    }

    public void ReadMapData() {
        _mapRooms = new Godot.Collections.Array();

        // Extract map data to uasset
        string u4pakPath = ProjectSettings.GlobalizePath(@"res://VendorBinary/U4pak/u4pak.exe");
        string outputPath = ProjectSettings.GlobalizePath(@"user://PakExtract");
        string mapDataTablePath = "BloodstainedRotN/Content/Core/DataTable/PB_DT_RoomMaster.uasset";
        using (Process pathList = new Process()) {
            pathList.StartInfo.FileName = u4pakPath;
            pathList.StartInfo.Arguments = @" unpack -o " + "\"" + outputPath + "\" \"" + _assetPathToPakFilePathMap[mapDataTablePath] + "\" \"" + mapDataTablePath + "\"";
            pathList.StartInfo.UseShellExecute = false;
            pathList.StartInfo.RedirectStandardOutput = true;
            pathList.Start();
            string output = pathList.StandardOutput.ReadToEnd();
            pathList.WaitForExit();
        }

        // Parse map data uasset
        UAsset uAsset = new UAsset(outputPath + "/" + mapDataTablePath, UE4Version.VER_UE4_18, true, true);
        foreach (Export baseExport in uAsset.Exports) {
            // Data table
            if (baseExport is DataTableExport export) {
                if (export.ReferenceData.ObjectName.Value.ToString() == "PB_DT_RoomMaster") {
                    // Loop through table rows
                    foreach (DataTableEntry dataTableEntry in export.Data2.Table) {
                        Godot.Collections.Dictionary<string, object> mapRoom = new Godot.Collections.Dictionary<string, object>();
                        if (dataTableEntry.Data is StructPropertyData structPropertyData) {
                            foreach (PropertyData propertyData in structPropertyData.Value) {
                                string propertyName = propertyData.Name.Value.ToString();
                                string propertyType = propertyData.Type.Value.ToString();
                                string propertyNameSnakeCase = CamelCaseToSnakeCase(propertyName);
                                try {
                                    if (propertyData is NamePropertyData namePropertyData) {
                                        mapRoom[propertyNameSnakeCase] = namePropertyData.Value.Value.ToString();
                                    } else if (propertyData is StrPropertyData strPropertyData) {
                                        mapRoom[propertyNameSnakeCase] = strPropertyData.Value;
                                    } else if (propertyData is BytePropertyData bytePropertyData) {
                                        mapRoom[propertyNameSnakeCase] = bytePropertyData.Value;
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
                        }
                        _mapRooms.Add(mapRoom);
                    }
                }
            }
        }
    }

    public void ExtractAssetToFolder(string pakFilePath, string assetPath, string outputFolderPath) {
        // Extract uasset
        string u4pakPath = ProjectSettings.GlobalizePath(@"res://VendorBinary/U4pak/u4pak.exe");
        using (Process unpack = new Process()) {
            unpack.StartInfo.FileName = u4pakPath;
            unpack.StartInfo.Arguments = @" unpack -o " + "\"" + outputFolderPath + "\" \"" + pakFilePath + "\" \"" + assetPath + "\"";
            unpack.StartInfo.UseShellExecute = false;
            unpack.StartInfo.RedirectStandardOutput = true;
            unpack.Start();
            string output = unpack.StandardOutput.ReadToEnd();
            unpack.WaitForExit();
        }
    }

    public void PackageAndInstallMod(string packageName) {
        string gameDirectory = (string)GetNode("/root/Editor").Call("read_config_prop", "game_directory");
        string selectedPackageName = (string)GetNode("/root/Editor").Get("selected_package");
        string unrealPakPath = ProjectSettings.GlobalizePath(@"res://VendorBinary/UnrealPak/UnrealPak.exe");
        string filelistPath = ProjectSettings.GlobalizePath(@"user://UserPackages/" + selectedPackageName + "/PackageFileList.txt");
        string modifiedAssetsFolder = ProjectSettings.GlobalizePath(@"user://UserPackages/" + selectedPackageName + "/ModifiedAssets");
        string outputPakFilePath = ProjectSettings.GlobalizePath(@"user://UserPackages/" + selectedPackageName + "/ModifiedAssets.pak");
        string gamePakLinkPath = gameDirectory + "/BloodstainedRotN/Content/Paks/~BloodstainedLevelEditor/" + selectedPackageName + ".pak";

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
    }

    public void ParseBlueprintForReuse(string pakFilePath, string assetPath, string objectName) {
        // Extract uasset
        string outputPath = ProjectSettings.GlobalizePath(@"user://PakExtract");
        if (!System.IO.File.Exists(outputPath + "/" + assetPath)) {
            ExtractAssetToFolder(pakFilePath, assetPath, outputPath);
        }

        // Parse uasset
        try {
            GD.Print("Parsing UAsset ", assetPath);
            UAsset uAsset = new UAsset(outputPath + "/" + assetPath, UE4Version.VER_UE4_18, true, true);
            GD.Print("Data preserved: " + (uAsset.VerifyParsing() ? "YES" : "NO"));

            int blueprintExportIndex = -1;

            // Find the index of the export we want
            int exportIndex = 0;
            foreach (Export baseExport in uAsset.Exports) {
                if (baseExport is NormalExport export) {
                    FName objectFName = export.ReferenceData.ObjectName;
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
            UAsset uAsset = new UAsset(targetAssetFilePath, UE4Version.VER_UE4_18, true, true);
            GD.Print("Data preserved: " + (uAsset.VerifyParsing() ? "YES" : "NO"));
            snippet.AddToUAsset(uAsset);
            uAsset.Write(targetAssetFilePath);
        } else {
            GD.Print("Cached blueprint not found. ", dictionaryKey);
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