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
using UAssetAPI.PropertyTypes;
using UAssetAPI.StructTypes;

public class UMapAsDictionaryTree {

    public class ParseInfo {
        private System.Collections.Generic.Dictionary<int, List<int>> _exportDependencyMap = null;
        public System.Collections.Generic.Dictionary<int, List<int>> ExportDependencyMap {
            get {
                return _exportDependencyMap;
            }
            set {
                _exportDependencyMap = value;
            }
        }
    }

    public static Godot.Collections.Dictionary<string, object> ToDictionaryTree(UAsset uAsset) {
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

        return ParseExportsRecursive(uAsset, mainExportIndex, parseInfo);
    }

    public static Godot.Collections.Dictionary<string, object> ParseExportsRecursive(UAsset uAsset, int exportIndex, ParseInfo parseInfo) {
        Export export = uAsset.Exports[exportIndex];
        Godot.Collections.Dictionary<string, object> treeNode = new Godot.Collections.Dictionary<string, object>();

        treeNode["export_index"] = exportIndex;

        // Get the type of node
        FPackageIndex classIndex = export.ClassIndex;
        string nodeType = "";
        if (classIndex.IsImport()) {
            Import classImport = classIndex.ToImport(uAsset);
            string className = classImport.ClassName.Value.Value;
            if (className == "Class") {
                nodeType = classImport.ObjectName.Value.Value;
            } else {
                nodeType = className;
            }
        }
        treeNode["type"] = nodeType;

        // Get the name of the node
        treeNode["name"] = export.ObjectName.Value.Value;

        // Read property data for params we can edit
        if (export is NormalExport normalExport) {
            foreach (PropertyData propertyData in normalExport.Data) {
                string propertyName = propertyData.Name.Value.Value;
                if (propertyName == "RootComponent") {
                    if (propertyData is ObjectPropertyData objectPropertyData) {
                        treeNode["root_component_export_index"] = Math.Abs(objectPropertyData.Value.Index) - 1;
                    }
                }
                else if (propertyName == "StaticMesh") {
                    if (propertyData is ObjectPropertyData objectPropertyData) {
                        FPackageIndex staticMeshPointer = objectPropertyData.Value;
                        if (staticMeshPointer.IsImport()) {
                            Import staticMeshImport = staticMeshPointer.ToImport(uAsset);
                            int packageArrayIndex = Math.Abs(staticMeshImport.OuterIndex.Index) - 1;
                            if (packageArrayIndex > -1) {
                                Import packageImport = uAsset.Imports[packageArrayIndex];
                                treeNode["static_mesh_name"] = staticMeshImport.ObjectName.Value.Value;
                                treeNode["static_mesh_name_instance"] = staticMeshImport.ObjectName.Number;
                                // TODO - check if this actually exists, auto-suffix here for packages that use that...
                                treeNode["static_mesh_asset_path"] = packageImport.ObjectName.Value.Value.Replace("/Game", "BloodstainedRotN/Content") + ".uasset";
                            }
                        }
                    }
                }
                else if (propertyName == "CapsuleHalfHeight") {
                    if (propertyData is FloatPropertyData floatPropertyData) {
                        treeNode["capsule_half_height"] = floatPropertyData.Value * 0.01f;
                    }
                }
                else if (propertyName == "CapsuleRadius") {
                    if (propertyData is FloatPropertyData floatPropertyData) {
                        treeNode["capsule_radius"] = floatPropertyData.Value * 0.01f;
                    }
                }
                else if (propertyName == "RelativeLocation") {
                    if (propertyData is StructPropertyData structPropertyData) {
                        if (structPropertyData.Value[0] is VectorPropertyData vectorPropertyData) {
                            treeNode["translation"] = ConvertLocationFromUnrealToGodot(new float[]{vectorPropertyData.X, vectorPropertyData.Y, vectorPropertyData.Z});
                        }
                    }
                }
                else if (propertyName == "RelativeRotation") {
                    if (propertyData is StructPropertyData structPropertyData) {
                        if (structPropertyData.Value[0] is RotatorPropertyData rotatorPropertyData) {
                            treeNode["rotation_degrees"] = ConvertRotationFromUnrealToGodot(new float[]{rotatorPropertyData.Pitch, rotatorPropertyData.Yaw, rotatorPropertyData.Roll});
                        }
                    }
                }
                else if (propertyName == "RelativeScale3D") {
                    if (propertyData is StructPropertyData structPropertyData) {
                        if (structPropertyData.Value[0] is VectorPropertyData vectorPropertyData) {
                            treeNode["scale"] = ConvertScaleFromUnrealToGodot(new float[]{vectorPropertyData.X, vectorPropertyData.Y, vectorPropertyData.Z});
                        }
                    }
                }
            }
        }

        // Parse children
        Godot.Collections.Array<Godot.Collections.Dictionary<string, object>> children = new Godot.Collections.Array<Godot.Collections.Dictionary<string, object>>();
        if (parseInfo.ExportDependencyMap.ContainsKey(exportIndex)) {
            foreach (int childIndex in parseInfo.ExportDependencyMap[exportIndex]) {
                children.Add(ParseExportsRecursive(uAsset, childIndex, parseInfo));
            }
        }
        treeNode["children"] = children;

        return treeNode;
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
                    else if (propName == "capsule_half_height") {
                        uAsset.AddNameReference(new FString("CapsuleHalfHeight"));
                        FloatPropertyData unrealCapsuleHalfHeight = new FloatPropertyData(new FName("CapsuleHalfHeight"));
                        unrealCapsuleHalfHeight.Value = propValue.Value<float>() * 100f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("CapsuleHalfHeight"), unrealCapsuleHalfHeight);
                    }
                    else if (propName == "capsule_radius") {
                        uAsset.AddNameReference(new FString("CapsuleRadius"));
                        FloatPropertyData unrealCapsuleRadius = new FloatPropertyData(new FName("CapsuleRadius"));
                        unrealCapsuleRadius.Value = propValue.Value<float>() * 100f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("CapsuleRadius"), unrealCapsuleRadius);
                    }
                    else if (propName == "translation") {
                        JObject translationObject = (JObject)propValue;
                        uAsset.AddNameReference(new FString("RelativeLocation"));
                        uAsset.AddNameReference(new FString("Vector"));
                        VectorPropertyData unrealLocation = ConvertLocationFromGodotToUnreal(new Vector3(
                            translationObject.Value<float>("x"),
                            translationObject.Value<float>("y"),
                            translationObject.Value<float>("z")
                        ));
                        StructPropertyData unrealLocationStruct = new StructPropertyData(new FName("RelativeLocation"), new FName("Vector"));
                        unrealLocationStruct.Value.Add(unrealLocation);
                        SetPropertyDataByName<StructPropertyData>(export.Data, new FName("RelativeLocation"), unrealLocationStruct);
                    }
                    else if (propName == "rotation_degrees") {
                        JObject rotationObject = (JObject)propValue;
                        uAsset.AddNameReference(new FString("RelativeRotation"));
                        uAsset.AddNameReference(new FString("Rotator"));
                        RotatorPropertyData unrealRotation = ConvertRotationFromGodotToUnreal(new Vector3(
                            rotationObject.Value<float>("x"),
                            rotationObject.Value<float>("y"),
                            rotationObject.Value<float>("z")
                        ));
                        StructPropertyData unrealRotationStruct = new StructPropertyData(new FName("RelativeRotation"), new FName("Rotator"));
                        unrealRotationStruct.Value.Add(unrealRotation);
                        SetPropertyDataByName<StructPropertyData>(export.Data, new FName("RelativeRotation"), unrealRotationStruct);
                    }
                    else if (propName == "scale") {
                        JObject scaleObject = (JObject)propValue;
                        uAsset.AddNameReference(new FString("RelativeScale3D"));
                        uAsset.AddNameReference(new FString("Vector"));
                        VectorPropertyData unrealScale = ConvertScaleFromGodotToUnreal(new Vector3(
                            scaleObject.Value<float>("x"),
                            scaleObject.Value<float>("y"),
                            scaleObject.Value<float>("z")
                        ));
                        StructPropertyData unrealScaleStruct = new StructPropertyData(new FName("RelativeScale3D"), new FName("Vector"));
                        unrealScaleStruct.Value.Add(unrealScale);
                        SetPropertyDataByName<StructPropertyData>(export.Data, new FName("RelativeScale3D"), unrealScaleStruct);
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
        return new Vector3(
            unrealRotation[2],
            -unrealRotation[1],
            unrealRotation[0]
        );
    }

    static Vector3 ConvertScaleFromUnrealToGodot(float[] unrealScale) {
        return new Vector3(
            unrealScale[0],
            unrealScale[2],
            unrealScale[1]
        );
    }

    static VectorPropertyData ConvertLocationFromGodotToUnreal(Vector3 godotLocation) {
        VectorPropertyData unrealLocation = new VectorPropertyData(new FName("RelativeLocation"));
        unrealLocation.X = godotLocation.x * 100f;
        unrealLocation.Y = godotLocation.z * 100f;
        unrealLocation.Z = godotLocation.y * 100f;
        return unrealLocation;
    }

    static RotatorPropertyData ConvertRotationFromGodotToUnreal(Vector3 godotRotation) {
        RotatorPropertyData unrealRotation = new RotatorPropertyData(new FName("RelativeRotation"));
        unrealRotation.Pitch = godotRotation.z;
        unrealRotation.Yaw = -godotRotation.y;
        unrealRotation.Roll = godotRotation.x;
        return unrealRotation;
    }

    static VectorPropertyData ConvertScaleFromGodotToUnreal(Vector3 godotScale) {
        VectorPropertyData unrealScale = new VectorPropertyData(new FName("RelativeScale3D"));
        unrealScale.X = godotScale.x;
        unrealScale.Y = godotScale.z;
        unrealScale.Z = godotScale.y;
        return unrealScale;
    }

}