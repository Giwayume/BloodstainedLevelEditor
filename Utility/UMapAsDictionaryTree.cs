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
        // Mapping of export index to the export indices of other exports that reference that export as outer index.
        private System.Collections.Generic.Dictionary<int, List<int>> _exportDependencyMap = null;
        public System.Collections.Generic.Dictionary<int, List<int>> ExportDependencyMap {
            get {
                return _exportDependencyMap;
            }
            set {
                _exportDependencyMap = value;
            }
        }
        // Mapping of export index to the export index of the parent it wants to attach to.
        private System.Collections.Generic.Dictionary<int, Godot.Collections.Dictionary<string, object>> _exportIndexDefinitionMap = null;
        public System.Collections.Generic.Dictionary<int, Godot.Collections.Dictionary<string, object>> ExportIndexDefinitionMap {
            get {
                return _exportIndexDefinitionMap;
            }
            set {
                _exportIndexDefinitionMap = value;
            }
        }
        public int CurrentParentExportIndex = 0;
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
        parseInfo.ExportIndexDefinitionMap = new System.Collections.Generic.Dictionary<int, Godot.Collections.Dictionary<string, object>>();

        Godot.Collections.Dictionary<string, object> parsedExports = ParseExportsRecursive(uAsset, mainExportIndex, parseInfo);

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

    public static Godot.Collections.Dictionary<string, object> ParseExportsRecursive(UAsset uAsset, int exportIndex, ParseInfo parseInfo) {
        Export export = uAsset.Exports[exportIndex];
        Godot.Collections.Dictionary<string, object> treeNode = new Godot.Collections.Dictionary<string, object>();

        treeNode["export_index"] = exportIndex;
        treeNode["outer_export_index"] = parseInfo.CurrentParentExportIndex;

        // Get the type of node
        FPackageIndex classIndex = export.ClassIndex;
        string nodeType = "";
        string classAssetPath = "";
        if (classIndex.IsImport()) {
            Import classImport = classIndex.ToImport(uAsset);
            string className = classImport.ClassName.Value.Value;
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
                    classAssetPath = Regex.Replace(classAssetPath, @"^\/Game/", @"/BloodstainedRotN/Content/");
                    classAssetPath = Regex.Replace(classAssetPath, @"^[\/]", "");
                    if (classAssetPath.StartsWith(@"BloodstainedRotN/")) {
                        classAssetPath = classAssetPath + ".uasset";
                    }
                }
            }
        }
        treeNode["type"] = nodeType;
        treeNode["class_asset_path"] = classAssetPath;

        // Get the name of the node
        treeNode["name"] = export.ObjectName.Value.Value;

        // Read property data for params we can edit
        if (export is NormalExport normalExport) {
            foreach (PropertyData propertyData in normalExport.Data) {
                string propertyName = propertyData.Name.Value.Value;
                if (propertyName == "RootComponent") {
                    if (propertyData is ObjectPropertyData objectPropertyData) {
                        if (objectPropertyData.Value.Index > 0) {
                            treeNode["root_component_export_index"] = Math.Abs(objectPropertyData.Value.Index) - 1;
                        }
                    }
                }
                else if (propertyName == "AttachParent") {
                    if (propertyData is ObjectPropertyData objectPropertyData) {
                        if (objectPropertyData.Value.Index > 0) {
                            treeNode["attach_parent_export_index"] = Math.Abs(objectPropertyData.Value.Index) - 1;
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
                            treeNode["mesh_export_index"] = Math.Abs(objectPropertyData.Value.Index) - 1;
                        }
                    }
                }
                /*
                 * CHARACTER PROPS
                 */
                else if (propertyName == "CharacterParamaters") {
                    if (propertyData is StructPropertyData structPropertyData) {
                        if (classAssetPath.StartsWith("BloodstainedRotN/Content/Core/Character/")) {
                            treeNode["type"] = "Character";
                        }
                        foreach (PropertyData characterPropertyData in structPropertyData.Value) {
                            propertyName = characterPropertyData.Name.Value.Value;
                            if (propertyName == "CharacterId") {
                                if (characterPropertyData is NamePropertyData namePropertyData) {
                                    string characterId = namePropertyData.Value.Value.Value;
                                    if (characterId == null) {
                                        characterId = "N/A";
                                    }
                                    treeNode["character_id"] = characterId;
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
                else {
                    /*
                    * STATIC MESH PROPS
                    */
                    if (nodeType == "StaticMeshComponent") {
                        if (propertyName == "StaticMesh") {
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
                    }
                    /*
                     * CAPSULE PROPS
                     */
                    else if (nodeType == "CapsuleComponent") {   
                        if (propertyName == "CapsuleHalfHeight") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["capsule_half_height"] = floatPropertyData.Value * 0.01f;
                            }
                        }
                        else if (propertyName == "CapsuleRadius") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["capsule_radius"] = floatPropertyData.Value * 0.01f;
                            }
                        }
                    }
                    /*
                     * LIGHT PROPS
                     */
                    else if (nodeType == "PointLightComponent" || nodeType == "SpotLightComponent") {   
                        if (propertyName == "Mobility") {
                            if (propertyData is BytePropertyData byteProperty) {
                                string mobilityEnumValue = byteProperty.GetEnumFull(uAsset).Value;
                                if (mobilityEnumValue == "EComponentMobility::Static") {
                                    treeNode["mobility"] = "static";
                                } else if (mobilityEnumValue == "EComponentMobility::Stationary") {
                                    treeNode["mobility"] = "stationary";
                                } else if (mobilityEnumValue == "EComponentMobility::Movable") {
                                    treeNode["mobility"] = "movable";
                                } 
                            }
                        }
                        else if (propertyName == "Intensity") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["intensity"] = floatPropertyData.Value;
                            }
                        }
                        else if (propertyName == "LightColor") {
                            if (propertyData is StructPropertyData structPropertyData) {
                                if (structPropertyData.Value[0] is ColorPropertyData colorPropertyData) {
                                    treeNode["light_color"] = new Godot.Color(colorPropertyData.Value.R / 255f, colorPropertyData.Value.G / 255f, colorPropertyData.Value.B / 255f, colorPropertyData.Value.A / 255f);
                                }
                            }
                        }
                        else if (propertyName == "InnerConeAngle") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["inner_cone_angle"] = floatPropertyData.Value;
                            }
                        }
                        else if (propertyName == "OuterConeAngle") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["outer_cone_angle"] = floatPropertyData.Value;
                            }
                        }
                        else if (propertyName == "AttenuationRadius") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["attenuation_radius"] = floatPropertyData.Value * 0.01f;
                            }
                        }
                        else if (propertyName == "SourceRadius") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["source_radius"] = floatPropertyData.Value * 0.01f;
                            }
                        }
                        else if (propertyName == "SoftSourceRadius") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["soft_source_radius"] = floatPropertyData.Value * 0.01f;
                            }
                        }
                        else if (propertyName == "SourceLength") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["source_length"] = floatPropertyData.Value * 0.01f;
                            }
                        }
                        else if (propertyName == "Temperature") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["temperature"] = floatPropertyData.Value;
                            }
                        }
                        else if (propertyName == "bUseTemperature") {
                            if (propertyData is BoolPropertyData boolPropertyData) {
                                treeNode["use_temperature"] = boolPropertyData.Value;
                            }
                        }
                        else if (propertyName == "CastShadows") {
                            if (propertyData is BoolPropertyData boolPropertyData) {
                                treeNode["cast_shadows"] = boolPropertyData.Value;
                            }
                        }
                        else if (propertyName == "bUseInverseSquaredFalloff") {
                            if (propertyData is BoolPropertyData boolPropertyData) {
                                treeNode["use_inverse_squared_falloff"] = boolPropertyData.Value;
                            }
                        }
                        else if (propertyName == "LightFalloffExponent") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["light_falloff_exponent"] = floatPropertyData.Value;
                            }
                        }
                        else if (propertyName == "IndirectLightingIntensity") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["indirect_lighting_intensity"] = floatPropertyData.Value;
                            }
                        }
                        else if (propertyName == "VolumetricScatteringIntensity") {
                            if (propertyData is FloatPropertyData floatPropertyData) {
                                treeNode["volumetric_scattering_intensity"] = floatPropertyData.Value;
                            }
                        }
                    }
                }
            }
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
                        BytePropertyData unrealMobility = new BytePropertyData(new FName("Mobility"));
                        unrealMobility.EnumType = mobilityEnumType;
                        unrealMobility.Value = mobilityEnumValue;
                        SetPropertyDataByName<BytePropertyData>(export.Data, new FName("Mobility"), unrealMobility);
                    }
                    else if (propName == "intensity") {
                        uAsset.AddNameReference(new FString("Intensity"));
                        FloatPropertyData unrealIntensity = new FloatPropertyData(new FName("Intensity"));
                        unrealIntensity.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("Intensity"), unrealIntensity);
                    }
                    else if (propName == "light_color") {
                        JObject lightColorObject = (JObject)propValue;
                        uAsset.AddNameReference(new FString("LightColor"));
                        uAsset.AddNameReference(new FString("Color"));
                        ColorPropertyData unrealColor = new ColorPropertyData(new FName("LightColor"));
                        unrealColor.Value = System.Drawing.Color.FromArgb(
                            (int)Math.Round(lightColorObject.Value<float>("a") * 255f),
                            (int)Math.Round(lightColorObject.Value<float>("r") * 255f),
                            (int)Math.Round(lightColorObject.Value<float>("g") * 255f),
                            (int)Math.Round(lightColorObject.Value<float>("b") * 255f)
                        );
                        StructPropertyData unrealLightColorStruct = new StructPropertyData(new FName("LightColor"), new FName("Color"));
                        unrealLightColorStruct.Value.Add(unrealColor);
                        SetPropertyDataByName<StructPropertyData>(export.Data, new FName("LightColor"), unrealLightColorStruct);
                    }
                    else if (propName == "inner_cone_angle") {
                        uAsset.AddNameReference(new FString("InnerConeAngle"));
                        FloatPropertyData unrealInnerConeAngle = new FloatPropertyData(new FName("InnerConeAngle"));
                        unrealInnerConeAngle.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("InnerConeAngle"), unrealInnerConeAngle);
                    }
                    else if (propName == "outer_cone_angle") {
                        uAsset.AddNameReference(new FString("OuterConeAngle"));
                        FloatPropertyData unrealOuterConeAngle = new FloatPropertyData(new FName("OuterConeAngle"));
                        unrealOuterConeAngle.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("OuterConeAngle"), unrealOuterConeAngle);
                    }
                    else if (propName == "attenuation_radius") {
                        uAsset.AddNameReference(new FString("AttenuationRadius"));
                        FloatPropertyData unrealAttenuationRadius = new FloatPropertyData(new FName("AttenuationRadius"));
                        unrealAttenuationRadius.Value = propValue.Value<float>() * 100.0f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("AttenuationRadius"), unrealAttenuationRadius);
                    }
                    else if (propName == "source_radius") {
                        uAsset.AddNameReference(new FString("SourceRadius"));
                        FloatPropertyData unrealSourceRadius = new FloatPropertyData(new FName("SourceRadius"));
                        unrealSourceRadius.Value = propValue.Value<float>() * 100.0f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("SourceRadius"), unrealSourceRadius);
                    }
                    else if (propName == "soft_source_radius") {
                        uAsset.AddNameReference(new FString("SoftSourceRadius"));
                        FloatPropertyData unrealSoftSourceRadius = new FloatPropertyData(new FName("SoftSourceRadius"));
                        unrealSoftSourceRadius.Value = propValue.Value<float>() * 100.0f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("SoftSourceRadius"), unrealSoftSourceRadius);
                    }
                    else if (propName == "source_length") {
                        uAsset.AddNameReference(new FString("SourceLength"));
                        FloatPropertyData unrealSourceLength = new FloatPropertyData(new FName("SourceLength"));
                        unrealSourceLength.Value = propValue.Value<float>() * 100.0f;
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("SourceLength"), unrealSourceLength);
                    }
                    else if (propName == "temperature") {
                        uAsset.AddNameReference(new FString("Temperature"));
                        FloatPropertyData unrealTemperature = new FloatPropertyData(new FName("Temperature"));
                        unrealTemperature.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("Temperature"), unrealTemperature);
                    }
                    else if (propName == "use_temperature") {
                        uAsset.AddNameReference(new FString("bUseTemperature"));
                        BoolPropertyData unrealbUseTemperature = new BoolPropertyData(new FName("bUseTemperature"));
                        unrealbUseTemperature.Value = propValue.Value<bool>();
                        SetPropertyDataByName<BoolPropertyData>(export.Data, new FName("bUseTemperature"), unrealbUseTemperature);
                    }
                    else if (propName == "cast_shadows") {
                        uAsset.AddNameReference(new FString("CastShadows"));
                        BoolPropertyData unrealCastShadows = new BoolPropertyData(new FName("CastShadows"));
                        unrealCastShadows.Value = propValue.Value<bool>();
                        SetPropertyDataByName<BoolPropertyData>(export.Data, new FName("CastShadows"), unrealCastShadows);
                    }
                    else if (propName == "use_inverse_squared_falloff") {
                        uAsset.AddNameReference(new FString("bUseInverseSquaredFalloff"));
                        BoolPropertyData unrealbUseInverseSquaredFalloff = new BoolPropertyData(new FName("bUseInverseSquaredFalloff"));
                        unrealbUseInverseSquaredFalloff.Value = propValue.Value<bool>();
                        SetPropertyDataByName<BoolPropertyData>(export.Data, new FName("bUseInverseSquaredFalloff"), unrealbUseInverseSquaredFalloff);
                    }
                    else if (propName == "light_falloff_exponent") {
                        uAsset.AddNameReference(new FString("LightFalloffExponent"));
                        FloatPropertyData unrealLightFalloffExponent = new FloatPropertyData(new FName("LightFalloffExponent"));
                        unrealLightFalloffExponent.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("LightFalloffExponent"), unrealLightFalloffExponent);
                    }
                    else if (propName == "indirect_lighting_intensity") {
                        uAsset.AddNameReference(new FString("IndirectLightingIntensity"));
                        FloatPropertyData unrealIndirectLightingIntensity = new FloatPropertyData(new FName("IndirectLightingIntensity"));
                        unrealIndirectLightingIntensity.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("IndirectLightingIntensity"), unrealIndirectLightingIntensity);
                    }
                    else if (propName == "volumetric_scattering_intensity") {
                        uAsset.AddNameReference(new FString("VolumetricScatteringIntensity"));
                        FloatPropertyData unrealVolumetricScatteringIntensity = new FloatPropertyData(new FName("VolumetricScatteringIntensity"));
                        unrealVolumetricScatteringIntensity.Value = propValue.Value<float>();
                        SetPropertyDataByName<FloatPropertyData>(export.Data, new FName("VolumetricScatteringIntensity"), unrealVolumetricScatteringIntensity);
                    }
                    /*
                     * TRANSFORM PROPS
                     */
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