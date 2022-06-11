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
using System.Runtime.Serialization;
using System.Runtime.Serialization.Formatters.Binary;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using UAssetAPI;
using UAssetAPI.PropertyTypes.Objects;
using UAssetAPI.PropertyTypes.Structs;
using UAssetAPI.UnrealTypes;

public class UMapAsDictionaryTree {

    public class EncounteredBlueprintInstance {
        public string ClassAssetPath = "";
        public Export Export = default(Export);
    }

    public class ParseInfo {
        // Mapping of export index to the export indices of other exports that reference that export as outer index.
        public System.Collections.Generic.Dictionary<int, List<int>> ExportDependencyMap = null;
        // Mapping of export index to the treeNode generated in the ParseExportsRecursive method.
        public System.Collections.Generic.Dictionary<int, Godot.Collections.Dictionary<string, object>> ExportIndexDefinitionMap = null;
        public UAssetParser Parser = default(UAssetParser);
        // Mapping of ClassAssetPath to Export ObjectName to the list of properties in that export (for a Blueprint _GEN_VARIABLE export).
        public System.Collections.Generic.Dictionary<string, System.Collections.Generic.Dictionary<string, List<PropertyData>>> BlueprintDefaultSettings = default(System.Collections.Generic.Dictionary<string, System.Collections.Generic.Dictionary<string, List<PropertyData>>>);
        // Mapping of blueprint asset path to its parent asset path.
        public System.Collections.Generic.Dictionary<string, string> BlueprintParents = default(System.Collections.Generic.Dictionary<string, string>);
        public System.Collections.Generic.Dictionary<string, UAsset> BlueprintAssets = default(System.Collections.Generic.Dictionary<string, UAsset>);
        // Mapping of export index to to EncounteredBlueprintInstance, list populated as exports parsed.
        public System.Collections.Generic.Dictionary<int, EncounteredBlueprintInstance> EncounteredBlueprintInstances = default(System.Collections.Generic.Dictionary<int, EncounteredBlueprintInstance>);
        public int CurrentParentExportIndex = 0;
    }

    public static Godot.Collections.Dictionary<string, object> ToDictionaryTree(UAsset uAsset, UAssetParser parser) {
        System.Collections.Generic.Dictionary<int, List<int>> exportDependencyMap = new System.Collections.Generic.Dictionary<int, List<int>>();
        int mainExportIndex = -1;
        int exportIndex = 0;
        foreach (Export export in uAsset.Exports) {
            // Populate exportDependencyMap
            int outerIndexInArray = (export.OuterIndex.Index) - 1;
            if (!exportDependencyMap.ContainsKey(outerIndexInArray)) {
                exportDependencyMap[outerIndexInArray] = new List<int>();
            }
            exportDependencyMap[outerIndexInArray].Add(exportIndex);

            // Take note of root asset index
            if (export.bIsAsset) {
                mainExportIndex = exportIndex;
            }

            exportIndex++;
        }

        ParseInfo parseInfo = new ParseInfo();
        parseInfo.ExportDependencyMap = exportDependencyMap;
        parseInfo.ExportIndexDefinitionMap = new System.Collections.Generic.Dictionary<int, Godot.Collections.Dictionary<string, object>>();
        parseInfo.Parser = parser;
        parseInfo.BlueprintDefaultSettings = new System.Collections.Generic.Dictionary<string, System.Collections.Generic.Dictionary<string, List<PropertyData>>>();
        parseInfo.BlueprintParents = new System.Collections.Generic.Dictionary<string, string>();
        parseInfo.BlueprintAssets = new System.Collections.Generic.Dictionary<string, UAsset>();
        parseInfo.EncounteredBlueprintInstances = new System.Collections.Generic.Dictionary<int, EncounteredBlueprintInstance>();

        Godot.Collections.Dictionary<string, object> parsedExports = ParseExportsRecursive(uAsset, mainExportIndex, parseInfo);

        // Fill in default property data parsed from blueprints
        foreach (var blueprintInstanceLoop in parseInfo.EncounteredBlueprintInstances) {
            int blueprintExportIndex = blueprintInstanceLoop.Key;
            EncounteredBlueprintInstance blueprintInstance = blueprintInstanceLoop.Value;
            string currentBlueprintLoadAssetPath = blueprintInstance.ClassAssetPath;
            
            while (currentBlueprintLoadAssetPath != "") {
                if (parseInfo.BlueprintAssets.ContainsKey(currentBlueprintLoadAssetPath)) {
                    System.Collections.Generic.Dictionary<string, List<PropertyData>> objectNameToPropertyDataMap = parseInfo.BlueprintDefaultSettings[currentBlueprintLoadAssetPath];
                    if (blueprintInstance.Export is NormalExport export) {
                        foreach (PropertyData propertyData in export.Data) {
                            if (propertyData is ObjectPropertyData objectPropertyData) {
                                string propertyName = objectPropertyData.Name.Value.Value;
                                int objectRefIndex = objectPropertyData.Value.Index - 1;
                                if (objectNameToPropertyDataMap.ContainsKey(propertyName) && parseInfo.ExportIndexDefinitionMap.ContainsKey(objectRefIndex)) {
                                    MapPropertyDataList(parseInfo.BlueprintAssets[currentBlueprintLoadAssetPath], objectNameToPropertyDataMap[propertyName], parseInfo.ExportIndexDefinitionMap[objectRefIndex], true);
                                }
                            }
                        }
                    }
                }
                if (parseInfo.BlueprintParents.ContainsKey(currentBlueprintLoadAssetPath)) {
                    currentBlueprintLoadAssetPath = parseInfo.BlueprintParents[currentBlueprintLoadAssetPath];
                } else {
                    currentBlueprintLoadAssetPath = "";
                }
            }
        }

        // Reorganize children by attach parent if property exists
        foreach (var exportDefinition in parseInfo.ExportIndexDefinitionMap) {
            exportIndex = exportDefinition.Key;
            Godot.Collections.Dictionary<string, object> definition = exportDefinition.Value;
            int outerExportIndex = (int)definition["outer_export_index"];
            if (definition.ContainsKey("attach_parent_export_index") && (int)definition["attach_parent_export_index"] != outerExportIndex) {
                int attachParentIndex = (int)definition["attach_parent_export_index"];
                if (parseInfo.ExportIndexDefinitionMap.ContainsKey(attachParentIndex)) {
                    try {
                        Godot.Collections.Dictionary<string, object> attachParentDefinition = parseInfo.ExportIndexDefinitionMap[attachParentIndex];
                        if (parseInfo.ExportIndexDefinitionMap.ContainsKey(outerExportIndex)) {
                            ((Godot.Collections.Array)parseInfo.ExportIndexDefinitionMap[outerExportIndex]["children"]).Remove(definition);
                        }
                        ((Godot.Collections.Array)parseInfo.ExportIndexDefinitionMap[attachParentIndex]["children"]).Add(definition);
                    } catch (Exception e) {
                        GD.Print(e);
                    }
                }
            }
        }

        parseInfo = null;
        return parsedExports;
    }

    public static void ParseBlueprintDefaultSettings(string classAssetPath, ParseInfo parseInfo) {
        if (parseInfo.BlueprintDefaultSettings.ContainsKey(classAssetPath)) {
            return;
        }
        System.Collections.Generic.Dictionary<string, List<PropertyData>> blueprintDefaultSettings = new System.Collections.Generic.Dictionary<string, List<PropertyData>>();
        string classAssetExtractPath = parseInfo.Parser.UAssetExtractFolder + "/" + classAssetPath;
        if (parseInfo.Parser.AssetPathToPakFilePathMap.ContainsKey(classAssetPath)) {
            if (!System.IO.File.Exists(classAssetExtractPath)) {
                parseInfo.Parser.ExtractAssetToFolder(parseInfo.Parser.AssetPathToPakFilePathMap[classAssetPath], classAssetPath, parseInfo.Parser.UAssetExtractFolder);
            }
        }
        if (System.IO.File.Exists(classAssetExtractPath)) {
            UAsset blueprintAsset = new UAsset(classAssetExtractPath, UE4Version.VER_UE4_22);
            string parentBlueprintAssetPath = "";

            foreach (Export baseExport in blueprintAsset.Exports) {
                if (baseExport.OuterIndex.Index == 0 && baseExport.SuperIndex.IsImport()) {
                    Import classImport = baseExport.SuperIndex.ToImport(blueprintAsset);
                    if (classImport.ClassName.Value.Value == "BlueprintGeneratedClass" && classImport.OuterIndex.IsImport()) {
                        Import packageImport = classImport.OuterIndex.ToImport(blueprintAsset);
                        if (packageImport.ClassName.Value.Value == "Package") {
                            parentBlueprintAssetPath = packageImport.ObjectName.Value.Value;
                            parentBlueprintAssetPath = Regex.Replace(parentBlueprintAssetPath, @"^\/Game/", @"/BloodstainedRotN/Content/");
                            parentBlueprintAssetPath = Regex.Replace(parentBlueprintAssetPath, @"^[\/]", "");
                            if (parentBlueprintAssetPath.StartsWith(@"BloodstainedRotN/")) {
                                parentBlueprintAssetPath = parentBlueprintAssetPath + ".uasset";
                            } else {
                                parentBlueprintAssetPath = "";
                            }
                        }
                    }
                }

                if (baseExport is NormalExport export) {
                    string objectName = export.ObjectName.Value.Value;
                    if (objectName.EndsWith("_GEN_VARIABLE")) {
                        blueprintDefaultSettings[objectName.Replace("_GEN_VARIABLE", "")] = export.Data;
                    }
                }
            }
            parseInfo.BlueprintAssets[classAssetPath] = blueprintAsset;

            if (parentBlueprintAssetPath != "") {
                ParseBlueprintDefaultSettings(parentBlueprintAssetPath, parseInfo);
                parseInfo.BlueprintParents[classAssetPath] = parentBlueprintAssetPath;
            }
        }
        parseInfo.BlueprintDefaultSettings[classAssetPath] = blueprintDefaultSettings;
    }

    public static Godot.Collections.Dictionary<string, object> ParseExportsRecursive(UAsset uAsset, int exportIndex, ParseInfo parseInfo) {
        Export export = uAsset.Exports[exportIndex];
        Godot.Collections.Dictionary<string, object> treeNode = new Godot.Collections.Dictionary<string, object>();

        treeNode["export_index"] = exportIndex;
        treeNode["outer_export_index"] = parseInfo.CurrentParentExportIndex;

        // Get the type of node
        FPackageIndex classIndex = export.ClassIndex;
        string nodeType = "";
        string classConstructor = "";
        string classAssetPath = "";
        if (classIndex.IsImport()) {
            Import classImport = classIndex.ToImport(uAsset);
            string className = classImport.ClassName.Value.Value;
            classConstructor = classImport.ObjectName.Value.Value;
            if (className == "Class") {
                nodeType = classImport.ObjectName.Value.Value;
            } else {
                nodeType = className;
            }
            if (classImport.OuterIndex.Index != 0) {
                Import classPackageImport = classImport.OuterIndex.ToImport(uAsset);
                string classPackageImportName = classPackageImport.ClassName.Value.Value;
                if (classPackageImportName == "Package") {
                    classAssetPath = classPackageImport.ObjectName.Value.Value;
                    // TODO - PB_Slope_4_4
                    // if (classAssetPath.IndexOf("Slope") > -1) {
                    //     GD.Print(classPackageImport.ClassName.Value.Value);
                    //     GD.Print(classPackageImport.ObjectName.Value, classPackageImport.ObjectName.Number);
                    // }
                    classAssetPath = Regex.Replace(classAssetPath, @"^\/Game/", @"/BloodstainedRotN/Content/");
                    classAssetPath = Regex.Replace(classAssetPath, @"^[\/]", "");
                    if (classAssetPath.StartsWith(@"BloodstainedRotN/")) {
                        classAssetPath = classAssetPath + ".uasset";
                    }
                }
            }
        }
        treeNode["type"] = nodeType;
        treeNode["class_constructor"] = classConstructor;
        treeNode["class_asset_path"] = classAssetPath;

        // Get the name of the node
        treeNode["name"] = export.ObjectName.Value.Value;

        // Read property data for params we can edit
        if (export is NormalExport normalExport) {

            if (nodeType == "BlueprintGeneratedClass" && classAssetPath != "") {
                ParseBlueprintDefaultSettings(classAssetPath, parseInfo);
                EncounteredBlueprintInstance instance = new EncounteredBlueprintInstance();
                instance.ClassAssetPath = classAssetPath;
                instance.Export = normalExport;
                parseInfo.EncounteredBlueprintInstances[exportIndex] = instance;
            }

            MapPropertyDataList(uAsset, normalExport.Data, treeNode);

        }

        // Parse children
        Godot.Collections.Array<Godot.Collections.Dictionary<string, object>> children = new Godot.Collections.Array<Godot.Collections.Dictionary<string, object>>();
        if (parseInfo.ExportDependencyMap.ContainsKey(exportIndex)) {
            foreach (int childIndex in parseInfo.ExportDependencyMap[exportIndex]) {
                parseInfo.CurrentParentExportIndex = exportIndex;
                children.Add(ParseExportsRecursive(uAsset, childIndex, parseInfo));
                parseInfo.CurrentParentExportIndex = 0;
            }
        }
        treeNode["children"] = children;

        parseInfo.ExportIndexDefinitionMap[exportIndex] = treeNode;

        return treeNode;
    }

    public static void MapPropertyDataList(UAsset uAsset, List<PropertyData> propertyDataList, Godot.Collections.Dictionary<string, object> treeNode, bool noOverride = false) {
        string nodeType = (string)treeNode["type"];
        string classAssetPath = (string)treeNode["class_asset_path"];

        Godot.Collections.Dictionary<string, object> newProperties = new Godot.Collections.Dictionary<string, object>();

        foreach (PropertyData propertyData in propertyDataList) {
            string propertyName = propertyData.Name.Value.Value;
            if (propertyName == "RootComponent") {
                if (propertyData is ObjectPropertyData objectPropertyData) {
                    if (objectPropertyData.Value.Index > 0) {
                        newProperties["root_component_export_index"] = Math.Abs(objectPropertyData.Value.Index) - 1;
                    }
                }
            }
            else if (propertyName == "AttachParent") {
                if (propertyData is ObjectPropertyData objectPropertyData) {
                    if (objectPropertyData.Value.Index > 0) {
                        newProperties["attach_parent_export_index"] = Math.Abs(objectPropertyData.Value.Index) - 1;
                    }
                }
            }
            /*
            * BLUEPRINT/DYNAMIC CLASS PROPS
            */
            else if (propertyName == "Mesh") {
                if (propertyData is ObjectPropertyData objectPropertyData) {
                    FPackageIndex staticMeshPointer = objectPropertyData.Value;
                    if (staticMeshPointer.IsExport()) {
                        newProperties["mesh_export_index"] = Math.Abs(objectPropertyData.Value.Index) - 1;
                    }
                }
            }
            /*
            * CHARACTER PROPS
            */
            else if (propertyName == "CharacterParamaters") {
                if (propertyData is StructPropertyData structPropertyData) {
                    if (classAssetPath.StartsWith("BloodstainedRotN/Content/Core/Character/")) {
                        newProperties["type"] = "Character";
                    }
                    foreach (PropertyData characterPropertyData in structPropertyData.Value) {
                        propertyName = characterPropertyData.Name.Value.Value;
                        if (propertyName == "CharacterId") {
                            if (characterPropertyData is NamePropertyData namePropertyData) {
                                string characterId = namePropertyData.Value.Value.Value;
                                if (characterId == null) {
                                    characterId = "N/A";
                                }
                                newProperties["character_id"] = characterId;
                            }
                        }
                    }
                }
            }
            /*
            * TRANSFORM PROPS
            */
            else if (propertyName == "RelativeLocation") {
                if (propertyData is StructPropertyData structPropertyData) {
                    if (structPropertyData.Value[0] is VectorPropertyData vectorPropertyData) {
                        newProperties["translation"] = ConvertLocationFromUnrealToGodot(new float[]{vectorPropertyData.Value.X, vectorPropertyData.Value.Y, vectorPropertyData.Value.Z});
                    }
                }
            }
            else if (propertyName == "RelativeRotation") {
                if (propertyData is StructPropertyData structPropertyData) {
                    if (structPropertyData.Value[0] is RotatorPropertyData rotatorPropertyData) {
                        newProperties["rotation_degrees"] = ConvertRotationFromUnrealToGodot(new float[]{rotatorPropertyData.Value.Pitch, rotatorPropertyData.Value.Yaw, rotatorPropertyData.Value.Roll});
                    }
                }
            }
            else if (propertyName == "RelativeScale3D") {
                if (propertyData is StructPropertyData structPropertyData) {
                    if (structPropertyData.Value[0] is VectorPropertyData vectorPropertyData) {
                        newProperties["scale"] = ConvertScaleFromUnrealToGodot(new float[]{vectorPropertyData.Value.X, vectorPropertyData.Value.Y, vectorPropertyData.Value.Z});
                    }
                }
            }
            else {
                /*
                * STATIC MESH PROPS
                */
                if (nodeType == "InstancedStaticMeshComponent" || nodeType == "StaticMeshComponent" || nodeType == "PBSwingObjectComponent") {
                    if (propertyName == "StaticMesh") {
                        if (propertyData is ObjectPropertyData objectPropertyData) {
                            FPackageIndex staticMeshPointer = objectPropertyData.Value;
                            if (staticMeshPointer.IsImport()) {
                                Import staticMeshImport = staticMeshPointer.ToImport(uAsset);
                                int packageArrayIndex = Math.Abs(staticMeshImport.OuterIndex.Index) - 1;
                                if (packageArrayIndex > -1) {
                                    Import packageImport = uAsset.Imports[packageArrayIndex];
                                    newProperties["static_mesh_name"] = staticMeshImport.ObjectName.Value.Value;
                                    newProperties["static_mesh_name_instance"] = staticMeshImport.ObjectName.Number;
                                    // TODO - check if this actually exists, auto-suffix here for packages that use that...
                                    newProperties["static_mesh_asset_path"] = packageImport.ObjectName.Value.Value.Replace("/Game", "BloodstainedRotN/Content") + ".uasset";
                                }
                            }
                        }
                    }
                }
                /*
                * CAPSULE PROPS
                */
                else if (nodeType == "CapsuleComponent") {   
                    if (propertyName == "CapsuleHalfHeight") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["capsule_half_height"] = floatPropertyData.Value * 0.01f;
                        }
                    }
                    else if (propertyName == "CapsuleRadius") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["capsule_radius"] = floatPropertyData.Value * 0.01f;
                        }
                    }
                }
                /*
                * LIGHT PROPS
                */
                else if (nodeType == "PointLightComponent" || nodeType == "SpotLightComponent" || nodeType == "DirectionalLightComponent") {   
                    if (propertyName == "Mobility") {
                        if (propertyData is BytePropertyData byteProperty) {
                            string mobilityEnumValue = byteProperty.GetEnumFull().Value.ToString();
                            if (mobilityEnumValue == "EComponentMobility::Static") {
                                newProperties["mobility"] = "static";
                            } else if (mobilityEnumValue == "EComponentMobility::Stationary") {
                                newProperties["mobility"] = "stationary";
                            } else if (mobilityEnumValue == "EComponentMobility::Movable") {
                                newProperties["mobility"] = "movable";
                            } 
                        }
                    }
                    else if (propertyName == "Intensity") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["intensity"] = floatPropertyData.Value;
                        }
                    }
                    else if (propertyName == "LightColor") {
                        if (propertyData is StructPropertyData structPropertyData) {
                            if (structPropertyData.Value[0] is ColorPropertyData colorPropertyData) {
                                newProperties["light_color"] = new Godot.Color(colorPropertyData.Value.R / 255f, colorPropertyData.Value.G / 255f, colorPropertyData.Value.B / 255f, colorPropertyData.Value.A / 255f);
                            }
                        }
                    }
                    else if (propertyName == "InnerConeAngle") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["inner_cone_angle"] = floatPropertyData.Value;
                        }
                    }
                    else if (propertyName == "OuterConeAngle") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["outer_cone_angle"] = floatPropertyData.Value;
                        }
                    }
                    else if (propertyName == "AttenuationRadius") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["attenuation_radius"] = floatPropertyData.Value * 0.01f;
                        }
                    }
                    else if (propertyName == "SourceRadius") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["source_radius"] = floatPropertyData.Value * 0.01f;
                        }
                    }
                    else if (propertyName == "SoftSourceRadius") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["soft_source_radius"] = floatPropertyData.Value * 0.01f;
                        }
                    }
                    else if (propertyName == "SourceLength") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["source_length"] = floatPropertyData.Value * 0.01f;
                        }
                    }
                    else if (propertyName == "Temperature") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["temperature"] = floatPropertyData.Value;
                        }
                    }
                    else if (propertyName == "bUseTemperature") {
                        if (propertyData is BoolPropertyData boolPropertyData) {
                            newProperties["use_temperature"] = boolPropertyData.Value;
                        }
                    }
                    else if (propertyName == "CastShadows") {
                        if (propertyData is BoolPropertyData boolPropertyData) {
                            newProperties["cast_shadows"] = boolPropertyData.Value;
                        }
                    }
                    else if (propertyName == "bUseInverseSquaredFalloff") {
                        if (propertyData is BoolPropertyData boolPropertyData) {
                            newProperties["use_inverse_squared_falloff"] = boolPropertyData.Value;
                        }
                    }
                    else if (propertyName == "LightFalloffExponent") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["light_falloff_exponent"] = floatPropertyData.Value;
                        }
                    }
                    else if (propertyName == "IndirectLightingIntensity") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["indirect_lighting_intensity"] = floatPropertyData.Value;
                        }
                    }
                    else if (propertyName == "VolumetricScatteringIntensity") {
                        if (propertyData is FloatPropertyData floatPropertyData) {
                            newProperties["volumetric_scattering_intensity"] = floatPropertyData.Value;
                        }
                    }
                }
            }
        }

        foreach (var property in newProperties) {
            if (noOverride) {
                if (!treeNode.ContainsKey(property.Key)) {
                    treeNode[property.Key] = property.Value;
                }
            } else {
                treeNode[property.Key] = property.Value;
            }
        }
    }

    public static void ModifyAssetFromEditsJson(UAsset uAsset, JObject editsJson) {
        JObject existingExports = (JObject)editsJson["existing_exports"];
        foreach (var editExportEntry in existingExports) {
            int exportIndex = int.Parse(editExportEntry.Key);
            Export baseExport = uAsset.Exports[exportIndex];
            if (baseExport is NormalExport export) {
                JObject editExport = (JObject)editExportEntry.Value;
                foreach (var editExportPropEntry in editExport) {
                    string propName = editExportPropEntry.Key;
                    JToken propValue = editExportPropEntry.Value;
                    if (propName == "deleted") {
                        if (propValue.Value<bool>() == true) {
                            FPackageIndex outerIndex = export.OuterIndex;
                            if (outerIndex.IsExport()) {
                                Export parentExport = outerIndex.ToExport(uAsset);
                                if (parentExport is LevelExport parentLevelExport) {
                                    parentLevelExport.IndexData.Remove(exportIndex + 1);
                                }
                            }
                            export.OuterIndex = FPackageIndex.FromRawIndex(0);
                        }
                    }
                    /*
                     * CAPSULE PROPS
                     */
                    else if (propName == "capsule_half_height") {
                        uAsset.AddNameReference(new FString("CapsuleHalfHeight"));
                        FloatPropertyData unrealCapsuleHalfHeight = new FloatPropertyData(new FName(uAsset, "CapsuleHalfHeight"));
                        unrealCapsuleHalfHeight.Value = propValue.Value<float>() * 100f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "CapsuleHalfHeight"), unrealCapsuleHalfHeight);
                    }
                    else if (propName == "capsule_radius") {
                        uAsset.AddNameReference(new FString("CapsuleRadius"));
                        FloatPropertyData unrealCapsuleRadius = new FloatPropertyData(new FName(uAsset, "CapsuleRadius"));
                        unrealCapsuleRadius.Value = propValue.Value<float>() * 100f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "CapsuleRadius"), unrealCapsuleRadius);
                    }
                    /*
                     * LIGHT PROPS
                     */
                    else if (propName == "mobility") {
                        string enumValue = propValue.Value<string>();
                        if (enumValue == "static") {
                            enumValue = "EComponentMobility::Static";
                        } else if (enumValue == "movable") {
                            enumValue = "EComponentMobility::Movable";
                        } else {
                            enumValue = "EComponentMobility::Stationary";
                        }
                        uAsset.AddNameReference(new FString("Mobility"));
                        int mobilityEnumType = uAsset.AddNameReference(new FString("EComponentMobility"));
                        int mobilityEnumValue = uAsset.AddNameReference(new FString(enumValue));
                        BytePropertyData unrealMobility = new BytePropertyData(new FName(uAsset, "Mobility"));
                        unrealMobility.ByteType = BytePropertyType.FName;
                        unrealMobility.EnumType = FName.FromString(uAsset, "EComponentMobility");
                        unrealMobility.EnumValue = FName.FromString(uAsset, enumValue);
                        SetPropertyDataByName<BytePropertyData>(export.Data, new FName(uAsset, "Mobility"), unrealMobility);
                    }
                    else if (propName == "intensity") {
                        uAsset.AddNameReference(new FString("Intensity"));
                        FloatPropertyData unrealIntensity = new FloatPropertyData(new FName(uAsset, "Intensity"));
                        unrealIntensity.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "Intensity"), unrealIntensity);
                    }
                    else if (propName == "light_color") {
                        JObject lightColorObject = (JObject)propValue;
                        uAsset.AddNameReference(new FString("LightColor"));
                        uAsset.AddNameReference(new FString("Color"));
                        ColorPropertyData unrealColor = new ColorPropertyData(new FName(uAsset, "LightColor"));
                        unrealColor.Value = System.Drawing.Color.FromArgb(
                            (int)Math.Round(lightColorObject.Value<float>("a") * 255f),
                            (int)Math.Round(lightColorObject.Value<float>("r") * 255f),
                            (int)Math.Round(lightColorObject.Value<float>("g") * 255f),
                            (int)Math.Round(lightColorObject.Value<float>("b") * 255f)
                        );
                        StructPropertyData unrealLightColorStruct = new StructPropertyData(new FName(uAsset, "LightColor"), new FName(uAsset, "Color"));
                        unrealLightColorStruct.Value.Add(unrealColor);
                        SetPropertyDataByName<StructPropertyData>(export.Data, new FName(uAsset, "LightColor"), unrealLightColorStruct);
                    }
                    else if (propName == "inner_cone_angle") {
                        uAsset.AddNameReference(new FString("InnerConeAngle"));
                        FloatPropertyData unrealInnerConeAngle = new FloatPropertyData(new FName(uAsset, "InnerConeAngle"));
                        unrealInnerConeAngle.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "InnerConeAngle"), unrealInnerConeAngle);
                    }
                    else if (propName == "outer_cone_angle") {
                        uAsset.AddNameReference(new FString("OuterConeAngle"));
                        FloatPropertyData unrealOuterConeAngle = new FloatPropertyData(new FName(uAsset, "OuterConeAngle"));
                        unrealOuterConeAngle.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "OuterConeAngle"), unrealOuterConeAngle);
                    }
                    else if (propName == "attenuation_radius") {
                        uAsset.AddNameReference(new FString("AttenuationRadius"));
                        FloatPropertyData unrealAttenuationRadius = new FloatPropertyData(new FName(uAsset, "AttenuationRadius"));
                        unrealAttenuationRadius.Value = propValue.Value<float>() * 100.0f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "AttenuationRadius"), unrealAttenuationRadius);
                    }
                    else if (propName == "source_radius") {
                        uAsset.AddNameReference(new FString("SourceRadius"));
                        FloatPropertyData unrealSourceRadius = new FloatPropertyData(new FName(uAsset, "SourceRadius"));
                        unrealSourceRadius.Value = propValue.Value<float>() * 100.0f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "SourceRadius"), unrealSourceRadius);
                    }
                    else if (propName == "soft_source_radius") {
                        uAsset.AddNameReference(new FString("SoftSourceRadius"));
                        FloatPropertyData unrealSoftSourceRadius = new FloatPropertyData(new FName(uAsset, "SoftSourceRadius"));
                        unrealSoftSourceRadius.Value = propValue.Value<float>() * 100.0f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "SoftSourceRadius"), unrealSoftSourceRadius);
                    }
                    else if (propName == "source_length") {
                        uAsset.AddNameReference(new FString("SourceLength"));
                        FloatPropertyData unrealSourceLength = new FloatPropertyData(new FName(uAsset, "SourceLength"));
                        unrealSourceLength.Value = propValue.Value<float>() * 100.0f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "SourceLength"), unrealSourceLength);
                    }
                    else if (propName == "temperature") {
                        uAsset.AddNameReference(new FString("Temperature"));
                        FloatPropertyData unrealTemperature = new FloatPropertyData(new FName(uAsset, "Temperature"));
                        unrealTemperature.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "Temperature"), unrealTemperature);
                    }
                    else if (propName == "use_temperature") {
                        uAsset.AddNameReference(new FString("bUseTemperature"));
                        BoolPropertyData unrealbUseTemperature = new BoolPropertyData(new FName(uAsset, "bUseTemperature"));
                        unrealbUseTemperature.Value = propValue.Value<bool>();
                        SetPropertyDataByName<BoolPropertyData>(export.Data, new FName(uAsset, "bUseTemperature"), unrealbUseTemperature);
                    }
                    else if (propName == "cast_shadows") {
                        uAsset.AddNameReference(new FString("CastShadows"));
                        BoolPropertyData unrealCastShadows = new BoolPropertyData(new FName(uAsset, "CastShadows"));
                        unrealCastShadows.Value = propValue.Value<bool>();
                        SetPropertyDataByName<BoolPropertyData>(export.Data, new FName(uAsset, "CastShadows"), unrealCastShadows);
                    }
                    else if (propName == "use_inverse_squared_falloff") {
                        uAsset.AddNameReference(new FString("bUseInverseSquaredFalloff"));
                        BoolPropertyData unrealbUseInverseSquaredFalloff = new BoolPropertyData(new FName(uAsset, "bUseInverseSquaredFalloff"));
                        unrealbUseInverseSquaredFalloff.Value = propValue.Value<bool>();
                        SetPropertyDataByName<BoolPropertyData>(export.Data, new FName(uAsset, "bUseInverseSquaredFalloff"), unrealbUseInverseSquaredFalloff);
                    }
                    else if (propName == "light_falloff_exponent") {
                        uAsset.AddNameReference(new FString("LightFalloffExponent"));
                        FloatPropertyData unrealLightFalloffExponent = new FloatPropertyData(new FName(uAsset, "LightFalloffExponent"));
                        unrealLightFalloffExponent.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "LightFalloffExponent"), unrealLightFalloffExponent);
                    }
                    else if (propName == "indirect_lighting_intensity") {
                        uAsset.AddNameReference(new FString("IndirectLightingIntensity"));
                        FloatPropertyData unrealIndirectLightingIntensity = new FloatPropertyData(new FName(uAsset, "IndirectLightingIntensity"));
                        unrealIndirectLightingIntensity.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "IndirectLightingIntensity"), unrealIndirectLightingIntensity);
                    }
                    else if (propName == "volumetric_scattering_intensity") {
                        uAsset.AddNameReference(new FString("VolumetricScatteringIntensity"));
                        FloatPropertyData unrealVolumetricScatteringIntensity = new FloatPropertyData(new FName(uAsset, "VolumetricScatteringIntensity"));
                        unrealVolumetricScatteringIntensity.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName(uAsset, "VolumetricScatteringIntensity"), unrealVolumetricScatteringIntensity);
                    }
                    /*
                     * TRANSFORM PROPS
                     */
                    else if (propName == "translation") {
                        JObject translationObject = (JObject)propValue;
                        uAsset.AddNameReference(new FString("RelativeLocation"));
                        uAsset.AddNameReference(new FString("Vector"));
                        VectorPropertyData unrealLocation = ConvertLocationFromGodotToUnreal(uAsset, new Vector3(
                            translationObject.Value<float>("x"),
                            translationObject.Value<float>("y"),
                            translationObject.Value<float>("z")
                        ));
                        StructPropertyData unrealLocationStruct = new StructPropertyData(new FName(uAsset, "RelativeLocation"), new FName(uAsset, "Vector"));
                        unrealLocationStruct.Value.Add(unrealLocation);
                        SetPropertyDataByName<StructPropertyData>(export.Data, new FName(uAsset, "RelativeLocation"), unrealLocationStruct);
                    }
                    else if (propName == "rotation_degrees") {
                        JObject rotationObject = (JObject)propValue;
                        uAsset.AddNameReference(new FString("RelativeRotation"));
                        uAsset.AddNameReference(new FString("Rotator"));
                        RotatorPropertyData unrealRotation = ConvertRotationFromGodotToUnreal(uAsset, new Vector3(
                            rotationObject.Value<float>("x"),
                            rotationObject.Value<float>("y"),
                            rotationObject.Value<float>("z")
                        ));
                        StructPropertyData unrealRotationStruct = new StructPropertyData(new FName(uAsset, "RelativeRotation"), new FName(uAsset, "Rotator"));
                        unrealRotationStruct.Value.Add(unrealRotation);
                        SetPropertyDataByName<StructPropertyData>(export.Data, new FName(uAsset, "RelativeRotation"), unrealRotationStruct);
                    }
                    else if (propName == "scale") {
                        JObject scaleObject = (JObject)propValue;
                        uAsset.AddNameReference(new FString("RelativeScale3D"));
                        uAsset.AddNameReference(new FString("Vector"));
                        VectorPropertyData unrealScale = ConvertScaleFromGodotToUnreal(uAsset, new Vector3(
                            scaleObject.Value<float>("x"),
                            scaleObject.Value<float>("y"),
                            scaleObject.Value<float>("z")
                        ));
                        StructPropertyData unrealScaleStruct = new StructPropertyData(new FName(uAsset, "RelativeScale3D"), new FName(uAsset, "Vector"));
                        unrealScaleStruct.Value.Add(unrealScale);
                        SetPropertyDataByName<StructPropertyData>(export.Data, new FName(uAsset, "RelativeScale3D"), unrealScaleStruct);
                    }
                }
            }
        }

    }

    static void SetPropertyDataByName<T>(List<PropertyData> propertyDataList, FName name, T value) where T: PropertyData {
        int index = 0;
        foreach (PropertyData propertyData in propertyDataList) {
            if (propertyData.Name.ToString() == name.ToString()) {
                propertyDataList[index] = (PropertyData)value;
                return;
            }
            index++;
        }
        propertyDataList.Add((PropertyData)value);
    }

    static Vector3 ConvertLocationFromUnrealToGodot(float[] unrealLocation) {
        return new Vector3(
            unrealLocation[0] * 0.01f,
            unrealLocation[2] * 0.01f,
            unrealLocation[1] * 0.01f
        );
    }

    static Vector3 ConvertRotationFromUnrealToGodot(float[] unrealRotation) {
        Spatial spatial = new Spatial();
        spatial.RotateX(Mathf.Deg2Rad(unrealRotation[2])); // Roll
        spatial.RotateZ(Mathf.Deg2Rad(unrealRotation[0])); // Pitch
        spatial.RotateY(Mathf.Deg2Rad(-unrealRotation[1])); // Yaw
        Vector3 godotRotation = new Vector3(
            spatial.RotationDegrees.x,
            spatial.RotationDegrees.y,
            spatial.RotationDegrees.z
        );
        spatial = null;
        return godotRotation;
    }

    static Vector3 ConvertScaleFromUnrealToGodot(float[] unrealScale) {
        return new Vector3(
            unrealScale[0],
            unrealScale[2],
            unrealScale[1]
        );
    }

    static VectorPropertyData ConvertLocationFromGodotToUnreal(UAsset uAsset, Vector3 godotLocation) {
        VectorPropertyData unrealLocation = new VectorPropertyData(new FName(uAsset, "RelativeLocation"));
        unrealLocation.Value = new FVector(
            godotLocation.x * 100f,
            godotLocation.z * 100f,
            godotLocation.y * 100f
        );
        return unrealLocation;
    }

    static RotatorPropertyData ConvertRotationFromGodotToUnreal(UAsset uAsset, Vector3 godotRotation) {
        RotatorPropertyData unrealRotation = new RotatorPropertyData(new FName(uAsset, "RelativeRotation"));
        Spatial spatial = new Spatial();
        spatial.RotateX(Mathf.Deg2Rad(godotRotation.z));
        spatial.RotateZ(Mathf.Deg2Rad(godotRotation.x));
        spatial.RotateY(Mathf.Deg2Rad(-godotRotation.y));
        unrealRotation.Value = new FRotator(
            spatial.RotationDegrees.x, // Pitch
            spatial.RotationDegrees.y, // Yaw
            spatial.RotationDegrees.z // Roll
        );
        spatial = null;
        return unrealRotation;
    }

    static VectorPropertyData ConvertScaleFromGodotToUnreal(UAsset uAsset, Vector3 godotScale) {
        VectorPropertyData unrealScale = new VectorPropertyData(new FName(uAsset, "RelativeScale3D"));
        unrealScale.Value = new FVector(
            godotScale.x,
            godotScale.z,
            godotScale.y
        );
        return unrealScale;
    }

}