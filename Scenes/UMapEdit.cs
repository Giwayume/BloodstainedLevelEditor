using Godot;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;
using UAssetAPI;
using UAssetAPI.PropertyTypes;
using UAssetAPI.StructTypes;

class ParsedPackage
{
//     /* Original UAsset Parse */
//     public UAsset uAsset;
//     /* List of all StaticMeshComponent exports in the package */
//     public List<StaticMeshComponent> staticMeshComponents = new List<StaticMeshComponent>();
//     /* Mapping of export index to staticMeshComponents list index */
//     public Dictionary<int, int> staticMeshComponentsExportMap = new Dictionary<int, int>();
//     /* List of all BlueprintGeneratedClass exports in the package */
//     public List<BlueprintGeneratedClass> blueprintGeneratedClasses = new List<BlueprintGeneratedClass>();
//     /* Mapping of export index to blueprintGeneratedClasses list index */
//     public Dictionary<int, int> blueprintGeneratedClassExportMap = new Dictionary<int, int>();
//     /* List of all SceneComponent exports in the package */
//     public List<SceneComponent> sceneComponents = new List<SceneComponent>();
//     /* Mapping of export index to sceneComponents list index */
//     public Dictionary<int, int> sceneComponentExportMap = new Dictionary<int, int>();
//     /* Retrieve any export object by index */
//     public System.Object GetParsedExportByIndex(int index) {
//         // Look in StaticMeshComponent
//         try {
//             StaticMeshComponent staticMeshComponent = staticMeshComponents[staticMeshComponentsExportMap[index]];
//             return staticMeshComponent;
//         } catch (Exception e) {
//             // Not found
//         }
//         // Look in BlueprintGeneratedClass
//         try {
//             BlueprintGeneratedClass blueprintGeneratedClass = blueprintGeneratedClasses[blueprintGeneratedClassExportMap[index]];
//             return blueprintGeneratedClass;
//         } catch (Exception e) {
//             // Not found
//         }
//         // Look in SceneComponent
//         try {
//             SceneComponent sceneComponent = sceneComponents[sceneComponentExportMap[index]];
//             return sceneComponent;
//         } catch (Exception e) {
//             // Not found
//         }
//         return default(System.Object);
//     }
// }

// class ParsedPackageGenericExport
// {
//     public string type = "";
//     public object export;
// }

// class BlueprintGeneratedClass
// {
//     public int exportIndex = -1;
//     public string packageName = "";
//     public int rootComponent = -1;
//     public int sharedRoot = -1;
//     public int defaultSceneRoot = -1;
//     public List<int> blueprintCreatedComponents = new List<int>();
//     public List<int> instArray = new List<int>();
// }

// class SceneComponent
// {
//     public int exportIndex = -1;
//     public string packageName = "";
//     public float[] relativeLocation = { 0, 0, 0 };
//     public float[] relativeRotation = { 0, 0, 0 };
//     public float[] relativeScale3D = { 1, 1, 1 };
// }

// class StaticMeshComponent
// {
//     public int exportIndex = -1;
//     public string packageName = "";
//     public bool isPlaced = false;
//     public bool isCreatedFromScript = false;
//     public float[] relativeLocation = { 0, 0, 0 };
//     public float[] relativeRotation = { 0, 0, 0 };
//     public float[] relativeScale3D = { 1, 1, 1 };
// }

// public class UMapEdit : Control
// {

//     private enum LoadingState
//     {
//         None,
//         ParsingUAsset,
//         ExtractingModels,
//         ImportingModels,
//         Done
//     };

//     private Label loadingStatusLabel;
//     private Control editorContainer;
//     private Control loadingStatusContainer;
//     private Spatial umap3DPreview;
//     private string[] uAssetLoadPaths = {
//         @"X:\Steam\steamapps\common\Bloodstained Ritual of the Night\BloodstainedRotN\Content\Paks\extracted\BloodstainedRotN\Content\Core\Environment\ACT01_SIP\Level\m01SIP_000_Gimmick.umap",
//     };
//     private LoadingState loadingState = LoadingState.None;
//     private string uAssetBasePath = @"X:\Steam\steamapps\common\Bloodstained Ritual of the Night\BloodstainedRotN\Content\Paks\extracted\BloodstainedRotN";

//     /* Mapping of package name to folder path of package, path starts with /Game/Core */
//     private Dictionary<string, string> packagePaths = new Dictionary<string, string>();

//     private Dictionary<string, ParsedPackage> parsedPackages = new Dictionary<string, ParsedPackage>();
    
//     private System.Threading.Thread uAssetParseThread;
//     private System.Threading.Thread modelExtractThread;
//     private System.Threading.Thread modelImportThread;

//     // Called when the node enters the scene tree for the first time.
//     public override void _Ready()
//     {
//         loadingStatusLabel = (Label)FindNode("LoadingStatusLabel", true, true);
//         editorContainer = (Control)FindNode("EditorContainer", true, true);
//         loadingStatusContainer = (Control)FindNode("LoadingStatusContainer", true, true);
//         umap3DPreview = (Spatial)FindNode("UMap3DPreview", true, false);
//         ChangeLoadingState(LoadingState.ParsingUAsset);
//     }

//     // Called every frame. 'delta' is the elapsed time since the previous frame.
//     public override void _Process(float delta)
//     {
//         if (loadingState == LoadingState.ParsingUAsset) {
//             if (uAssetParseThread == default(System.Threading.Thread)) {
//                 ChangeLoadingState(LoadingState.Done);
//             } else {
//                 if (!uAssetParseThread.IsAlive) {
//                     ChangeLoadingState(LoadingState.ExtractingModels);
//                 }
//             }
//         }
//         else if (loadingState == LoadingState.ExtractingModels) {
//             if (modelExtractThread == default(System.Threading.Thread)) {
//                 ChangeLoadingState(LoadingState.Done);
//             } else {
//                 if (!modelExtractThread.IsAlive) {
//                     ChangeLoadingState(LoadingState.ImportingModels);
//                 }
//             }
//         }
//         else if (loadingState == LoadingState.ImportingModels) {
//             if (modelImportThread == default(System.Threading.Thread)) {
//                 ChangeLoadingState(LoadingState.Done);
//             } else {
//                 if (!modelImportThread.IsAlive) {
//                     ChangeLoadingState(LoadingState.Done);
//                 }
//             }
//         }
//     }

//     private void ChangeLoadingState(LoadingState newLoadingState) {
//         loadingState = newLoadingState;
//         if (loadingState == LoadingState.ParsingUAsset) {
//             loadingStatusLabel.Text = "Reading UAsset File...";
//             editorContainer.Hide();
//             loadingStatusContainer.Show();
//             uAssetParseThread = new System.Threading.Thread(new ThreadStart(ParseUAsset));
//             uAssetParseThread.Start();
//         } else if (loadingState == LoadingState.ExtractingModels) {
//             loadingStatusLabel.Text = "Extracting 3D Models...";
//             editorContainer.Hide();
//             loadingStatusContainer.Show();
//             modelExtractThread = new System.Threading.Thread(new ThreadStart(ExtractModels));
//             modelExtractThread.Start();
//         } else if (loadingState == LoadingState.ImportingModels) {
//             loadingStatusLabel.Text = "Importing 3D Models...";
//             editorContainer.Hide();
//             loadingStatusContainer.Show();
//             modelImportThread = new System.Threading.Thread(new ThreadStart(ImportModels));
//             modelImportThread.Start();
//         } else if (loadingState == LoadingState.Done) {
//             loadingStatusLabel.Text = "Done.";
//             editorContainer.Show();
//             loadingStatusContainer.Hide();
//         }
//     }

//     private void ParseUAsset() {
//         try {
//             foreach (string uAssetPath in uAssetLoadPaths) {
//                 ParsedPackage parsedPackage = new ParsedPackage();

//                 GD.Print("Reading UAsset: " + uAssetPath);
//                 UAsset uAsset = new UAsset(uAssetPath, UE4Version.VER_UE4_18, true, true);
//                 parsedPackage.uAsset = uAsset;
//                 GD.Print("Data preserved? " + (uAsset.VerifyParsing() ? "YES" : "NO"));

//                 // Gather package names and paths.
//                 foreach (Import import in uAsset.Imports) {
//                     FName ClassName = import.ClassName;
//                     FName ObjectName = import.ObjectName;
//                     if (ClassName.ToString() == "Package") {
//                         try {
//                             packagePaths.Add(ObjectName.ToString().Split("/").Last(), ObjectName.ToString());
//                         } catch (Exception e) {
//                             // Ignore duplicate package
//                         }
//                     }
//                 }

//                 // Parse each type of export.
//                 int exportIndex = 1;
//                 foreach (Export baseExport in uAsset.Exports) {
//                     if (baseExport is NormalExport export) {
//                         Import classReference = uAsset.GetImportAt(export.ReferenceData.ClassIndex);
//                         string className = "";
//                         string objectName = "";
//                         try {
//                             className = classReference.ClassName.Value.ToString();
//                             objectName = uAsset.GetImportObjectName(export.ReferenceData.ClassIndex).Value.ToString();
//                         } catch (Exception e) {
//                             // Ignore no class name
//                         }
//                         if (className == "BlueprintGeneratedClass" || className == "DynamicClass") {
//                             BlueprintGeneratedClass blueprintGeneratedClass = new BlueprintGeneratedClass();
//                             blueprintGeneratedClass.exportIndex = exportIndex;
//                             blueprintGeneratedClass.packageName = objectName;
//                             foreach (PropertyData propertyData in export.Data) {
//                                 string propertyName = propertyData.Name.ToString();
//                                 if (propertyName == "RootComponent") {
//                                     blueprintGeneratedClass.rootComponent = int.Parse(propertyData.ToString());
//                                 }
//                                 else if (propertyName == "SharedRoot") {
//                                     blueprintGeneratedClass.sharedRoot = int.Parse(propertyData.ToString());
//                                 }
//                                 else if (propertyName == "DefaultSceneRoot") {
//                                     blueprintGeneratedClass.defaultSceneRoot = int.Parse(propertyData.ToString());
//                                 }
//                                 else if (propertyName == "BlueprintCreatedComponents") {
//                                     if (propertyData is ArrayPropertyData arrayPropertyData) {
//                                         foreach (PropertyData arrayProp in arrayPropertyData.Value) {
//                                             int refIndex = -1;
//                                             try {
//                                                 refIndex = int.Parse(arrayProp.ToString());
//                                             } catch (Exception e) {
//                                                 // Ignore.
//                                             }
//                                             blueprintGeneratedClass.blueprintCreatedComponents.Add(refIndex);
//                                         }
//                                     }
//                                 }
//                                 else if (propertyName == "InstArray") {
//                                     if (propertyData is ArrayPropertyData arrayPropertyData) {
//                                         foreach (PropertyData arrayProp in arrayPropertyData.Value) {
//                                             int refIndex = -1;
//                                             try {
//                                                 refIndex = int.Parse(arrayProp.ToString());
//                                             } catch (Exception e) {
//                                                 // Ignore.
//                                             }
//                                             blueprintGeneratedClass.instArray.Add(refIndex);
//                                         }
//                                     }
//                                 }
//                             }
//                             parsedPackage.blueprintGeneratedClasses.Add(blueprintGeneratedClass);
//                             parsedPackage.blueprintGeneratedClassExportMap.Add(exportIndex, parsedPackage.blueprintGeneratedClasses.Count - 1);
//                         }
//                         else if (objectName == "SceneComponent") {
//                             SceneComponent sceneComponent = new SceneComponent();
//                             sceneComponent.exportIndex = exportIndex;
//                             sceneComponent.packageName = objectName;
//                             foreach (PropertyData propertyData in export.Data) {
//                                 string propertyName = propertyData.Name.ToString();
//                                 if (propertyName == "RelativeLocation" || propertyName == "RelativeRotation" || propertyName == "RelativeScale3D") {
//                                     if (propertyData is StructPropertyData structPropertyData) {
//                                         string structType = structPropertyData.StructType.ToString();
//                                         if (structType == "Vector" || structType == "Rotator") {
//                                             float[] vector3 = Array.ConvertAll(
//                                                 Regex.Replace(structPropertyData.Value[0].ToString(), @"[() ]", "").Split(","),
//                                                 float.Parse
//                                             );
//                                             if (propertyName == "RelativeLocation") {
//                                                 sceneComponent.relativeLocation = vector3;
//                                             } else if (propertyName == "RelativeRotation") {
//                                                 sceneComponent.relativeRotation = vector3;
//                                             } else if (propertyName == "RelativeScale3D") {
//                                                 sceneComponent.relativeScale3D = vector3;
//                                             }
//                                         }
//                                     }
//                                 }
//                             }
//                             parsedPackage.sceneComponents.Add(sceneComponent);
//                             parsedPackage.sceneComponentExportMap.Add(exportIndex, parsedPackage.sceneComponents.Count - 1);
//                         }
//                         else if (objectName == "StaticMeshComponent") {
//                             string packageName = "";
//                             float[] relativeLocation = {0, 0, 0};
//                             float[] relativeRotation = {0, 0, 0};
//                             float[] relativeScale3D = {1, 1, 1};
//                             bool isCreatedFromScript = false;
//                             foreach (PropertyData propertyData in export.Data) {
//                                 string propertyName = propertyData.Name.ToString();
//                                 if (propertyName == "StaticMesh") {
//                                     packageName = propertyData.ToString();
//                                 }
//                                 else if (propertyName == "RelativeLocation" || propertyName == "RelativeRotation" || propertyName == "RelativeScale3D") {
//                                     if (propertyData is StructPropertyData structPropertyData) {
//                                         string structType = structPropertyData.StructType.ToString();
//                                         if (structType == "Vector" || structType == "Rotator") {
//                                             float[] vector3 = Array.ConvertAll(
//                                                 Regex.Replace(structPropertyData.Value[0].ToString(), @"[() ]", "").Split(","),
//                                                 float.Parse
//                                             );
//                                             if (propertyName == "RelativeLocation") {
//                                                 relativeLocation = vector3;
//                                             } else if (propertyName == "RelativeRotation") {
//                                                 relativeRotation = vector3;
//                                             } else if (propertyName == "RelativeScale3D") {
//                                                 relativeScale3D = vector3;
//                                             }
//                                         }
//                                     }
//                                 }
//                                 else if (propertyName == "CreationMethod") {
//                                     if (propertyData.ToString() == "EComponentCreationMethod::SimpleConstructionScript" || propertyData.ToString() == "EComponentCreationMethod::UserConstructionScript") {
//                                         isCreatedFromScript = true;
//                                     }
//                                 }
//                             }
//                             if (packageName != "") {
//                                 StaticMeshComponent staticMeshComponent = new StaticMeshComponent();
//                                 staticMeshComponent.exportIndex = exportIndex;
//                                 staticMeshComponent.packageName = packageName;
//                                 staticMeshComponent.relativeLocation = relativeLocation;
//                                 staticMeshComponent.relativeRotation = relativeRotation;
//                                 staticMeshComponent.relativeScale3D = relativeScale3D;
//                                 staticMeshComponent.isCreatedFromScript = isCreatedFromScript;
//                                 parsedPackage.staticMeshComponents.Add(staticMeshComponent);
//                                 parsedPackage.staticMeshComponentsExportMap.Add(exportIndex, parsedPackage.staticMeshComponents.Count - 1);
//                             }
//                         }
//                     }
//                     exportIndex++;
//                 }

//                 parsedPackages.Add(uAssetPath.ToString().Split("/").Last().Split(".")[0], parsedPackage);
//             }
//         } catch (Exception e) {
//             GD.Print("Error during ParseUAsset");
//             GD.Print(e);
//         }
//     }

//     private void ExtractModels() {
//         try {
//             string ueViewerPath = ProjectSettings.GlobalizePath(@"res://VendorBinary/UEViewer/umodel_64.exe");
//             string modelCachePath = ProjectSettings.GlobalizePath(@"user://ModelCache");
//             List<string> extractPackageNames = new List<string>();
//             foreach (var parsedPackage in parsedPackages) {
//                 foreach (StaticMeshComponent staticMeshComponent in parsedPackage.Value.staticMeshComponents) {
//                     string meshPackageName = staticMeshComponent.packageName;
//                     extractPackageNames.Add(meshPackageName);
//                 }
//             }
//             string[] uniqueExtractPackageNames = new HashSet<string>(extractPackageNames).ToArray();
//             List<string> unextractedPackageNames = new List<string>();
//             foreach (string meshPackageName in uniqueExtractPackageNames) {
//                 try {
//                     string meshPackagePath = packagePaths[meshPackageName];
//                     string meshCacheFilePath = modelCachePath + meshPackagePath + ".gltf";
//                     if (meshPackagePath.StartsWith("/Game") && !System.IO.File.Exists(meshCacheFilePath)) {
//                         unextractedPackageNames.Add(meshPackageName);
//                     }
//                 } catch (Exception e) {
//                     GD.Print(e);
//                 }
//             }

//             foreach (string meshPackageName in unextractedPackageNames) {
//                 loadingStatusLabel.Text = "Extracting 3D Models...\n" + meshPackageName;
//                 try {
//                     using (Process ueExtract = new Process()) {
//                         ueExtract.StartInfo.FileName = ueViewerPath;
//                         ueExtract.StartInfo.Arguments = @" -path=" + "\"" + uAssetBasePath + "\"" + @" -out=" + "\"" + modelCachePath + "/Game/\"" + @" -game=ue4.18 -export -gltf " + meshPackageName;
//                         GD.Print(ueExtract.StartInfo.Arguments);
//                         ueExtract.StartInfo.UseShellExecute = false;
//                         ueExtract.StartInfo.RedirectStandardOutput = true;
//                         ueExtract.Start();
//                         string output = ueExtract.StandardOutput.ReadToEnd();
//                         ueExtract.WaitForExit();
//                     }
//                 } catch (Exception e) {
//                     GD.Print(e);
//                 }
//             }
//         } catch (Exception e) {
//             GD.Print("Error during ExtractModels");
//             GD.Print(e);
//         }
//     }

//     private void ImportModels() {
//         try {
//             DynamicGLTFLoader loader = new DynamicGLTFLoader();
//             Spatial umapContainer = (Spatial)umap3DPreview.GetNode("UMaps");
//             foreach (var parsedPackageSplit in parsedPackages) {
//                 ParsedPackage parsedPackage = parsedPackageSplit.Value;
//                 Spatial packageNode = new Spatial();
//                 packageNode.Name = parsedPackageSplit.Key;
//                 umapContainer.AddChild(packageNode);
//                 foreach (BlueprintGeneratedClass blueprintGeneratedClass in parsedPackage.blueprintGeneratedClasses) {
//                     Spatial blueprintNode = new Spatial();
//                     blueprintNode.Name = blueprintGeneratedClass.packageName;
//                     packageNode.AddChild(blueprintNode);
//                     SceneComponent rootComponent = default(SceneComponent);
//                     try {
//                         rootComponent = (SceneComponent)parsedPackage.GetParsedExportByIndex(blueprintGeneratedClass.rootComponent);
//                     } catch (Exception e) {}
//                     SceneComponent sharedRoot = default(SceneComponent);
//                     try {
//                         sharedRoot = (SceneComponent)parsedPackage.GetParsedExportByIndex(blueprintGeneratedClass.sharedRoot);
//                     } catch (Exception e) {}
//                     SceneComponent defaultSceneRoot = default(SceneComponent);
//                     try {
//                         defaultSceneRoot = (SceneComponent)parsedPackage.GetParsedExportByIndex(blueprintGeneratedClass.defaultSceneRoot);
//                     } catch (Exception e) {}
//                     Spatial blueprintComponentsNode = new Spatial();
//                     blueprintComponentsNode.Name = "BlueprintCreatedComponents";
//                     blueprintNode.AddChild(blueprintComponentsNode);
//                     if (rootComponent != default(SceneComponent)) {
//                         blueprintComponentsNode.Translation = new Vector3(
//                             (float) (rootComponent.relativeLocation[0] * 0.01),
//                             (float) (rootComponent.relativeLocation[2] * 0.01),
//                             (float) (rootComponent.relativeLocation[1] * 0.01)
//                         );
//                         blueprintComponentsNode.RotationDegrees = new Vector3(
//                             (float) (rootComponent.relativeRotation[2]),
//                             (float) (-rootComponent.relativeRotation[1]),
//                             (float) (rootComponent.relativeRotation[0])
//                         );
//                         blueprintComponentsNode.Scale = new Vector3(
//                             (float) (rootComponent.relativeScale3D[0]),
//                             (float) (rootComponent.relativeScale3D[2]),
//                             (float) (rootComponent.relativeScale3D[1])
//                         );
//                     }
//                     foreach (int exportRef in blueprintGeneratedClass.blueprintCreatedComponents) {
//                         System.Object export = parsedPackage.GetParsedExportByIndex(exportRef);
//                         if (export != default(System.Object)) {
//                             if (export is StaticMeshComponent staticMeshComponent) {
//                                 PlaceStaticMesh(loader, staticMeshComponent, blueprintComponentsNode);
//                             }
//                         }
//                     }
//                     Spatial instArrayNode = new Spatial();
//                     instArrayNode.Name = "InstArray";
//                     blueprintNode.AddChild(instArrayNode);
//                     if (defaultSceneRoot != default(SceneComponent)) {
//                         instArrayNode.Translation = new Vector3(
//                             (float) (defaultSceneRoot.relativeLocation[0] * 0.01),
//                             (float) (defaultSceneRoot.relativeLocation[2] * 0.01),
//                             (float) (defaultSceneRoot.relativeLocation[1] * 0.01)
//                         );
//                         instArrayNode.RotationDegrees = new Vector3(
//                             (float) (defaultSceneRoot.relativeRotation[2]),
//                             (float) (-defaultSceneRoot.relativeRotation[1]),
//                             (float) (defaultSceneRoot.relativeRotation[0])
//                         );
//                         instArrayNode.Scale = new Vector3(
//                             (float) (defaultSceneRoot.relativeScale3D[0]),
//                             (float) (defaultSceneRoot.relativeScale3D[2]),
//                             (float) (defaultSceneRoot.relativeScale3D[1])
//                         );
//                     }
//                     foreach (int exportRef in blueprintGeneratedClass.instArray) {
//                         System.Object export = parsedPackage.GetParsedExportByIndex(exportRef);
//                         if (export != default(System.Object)) {
//                             if (export is StaticMeshComponent staticMeshComponent) {
//                                 PlaceStaticMesh(loader, staticMeshComponent, instArrayNode);
//                             }
//                         }
//                     }

//                 }
//                 Spatial defaultNode = new Spatial();
//                 defaultNode.Name = "__DEFAULT__";
//                 packageNode.AddChild(defaultNode);
//                 foreach (StaticMeshComponent staticMeshComponent in parsedPackage.staticMeshComponents) {
//                     try {
//                         if (staticMeshComponent != default(StaticMeshComponent)) {
//                             if (!staticMeshComponent.isCreatedFromScript) {
//                                 PlaceStaticMesh(loader, staticMeshComponent, defaultNode);
//                             }
//                         }
//                     } catch (Exception e) {
//                         GD.Print(e);
//                     }
//                 }

//             }
//         } catch (Exception e) {
//             GD.Print("Error during ImportModels");
//             GD.Print(e);
//         }
//     }

//     private void PlaceStaticMesh(DynamicGLTFLoader loader, StaticMeshComponent staticMeshComponent, Node placeAtNode) {
//         try {
//             string modelCachePath = ProjectSettings.GlobalizePath(@"user://ModelCache");
//             string meshPackageName = staticMeshComponent.packageName;
//             string meshPackagePath = packagePaths[meshPackageName];
//             string meshCacheFilePath = modelCachePath + meshPackagePath + ".gltf";
//             Spatial loadedModel = (Spatial)loader.ImportScene(meshCacheFilePath, 1, 1);
//             if (loadedModel is Spatial model) {
//                 model.Name = meshPackageName;
//                 placeAtNode.AddChild(model);
//                 model.Translation = new Vector3(
//                     (float) (staticMeshComponent.relativeLocation[0] * 0.01),
//                     (float) (staticMeshComponent.relativeLocation[2] * 0.01),
//                     (float) (staticMeshComponent.relativeLocation[1] * 0.01)
//                 );
//                 model.RotationDegrees = new Vector3(
//                     (float) (staticMeshComponent.relativeRotation[2]),
//                     (float) (-staticMeshComponent.relativeRotation[1]),
//                     (float) (staticMeshComponent.relativeRotation[0])
//                 );
//                 model.Scale = new Vector3(
//                     (float) (staticMeshComponent.relativeScale3D[0]),
//                     (float) (staticMeshComponent.relativeScale3D[2]),
//                     (float) (staticMeshComponent.relativeScale3D[1])
//                 );
//                 staticMeshComponent.isPlaced = true;
//             } else {

//             }
//         } catch (Exception e) {
//             GD.Print("Error during PlaceStaticMesh");
//             GD.Print(e);
//         }
//     }
}

