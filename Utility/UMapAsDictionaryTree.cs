using Godot;
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
            int outerIndexInArray = (export.OuterIndex) - 1;
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
                            int packageArrayIndex = Math.Abs(staticMeshImport.OuterIndex) - 1;
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
                else if (propertyName == "RelativeLocation") {
                    if (propertyData is StructPropertyData structPropertyData) {
                        if (structPropertyData.Value[0] is VectorPropertyData vectorPropertyData) {
                            treeNode["translation"] = ConvertLocationFromUnrealToGodot(vectorPropertyData.Value);
                        }
                    }
                }
                else if (propertyName == "RelativeRotation") {
                    if (propertyData is StructPropertyData structPropertyData) {
                        if (structPropertyData.Value[0] is RotatorPropertyData rotatorPropertyData) {
                            treeNode["rotation_degrees"] = ConvertRotationFromUnrealToGodot(rotatorPropertyData.Value);
                        }
                    }
                }
                else if (propertyName == "RelativeScale3D") {
                    if (propertyData is StructPropertyData structPropertyData) {
                        if (structPropertyData.Value[0] is VectorPropertyData vectorPropertyData) {
                            treeNode["scale"] = ConvertScaleFromUnrealToGodot(vectorPropertyData.Value);
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

}