using Godot;
using System;
using System.Collections.Generic;
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

public class UAssetSnippet {
    public class UAssetExportTreeItem {
        public int ExportIndex = -1; // 0 - indexed!
        public bool IsRoot = true;
        public List<UAssetExportTreeItem> AttachedChildren = new List<UAssetExportTreeItem>();
    }
    public class UAssetImportTreeItem {
        public int ImportIndex = -1; // 0 - indexed!
        public bool IsRoot = true;
        public List<int> ParentImports = new List<int>();
    }
    public class DetachedObjectPropertyData : PropertyData<int> {
        public List<int> UsedExports = default(List<int>);
        private static readonly FName CurrentPropertyType = new FName("DetachedObjectProperty");
        public override FName PropertyType { get { return CurrentPropertyType; } }
        public DetachedObjectPropertyData(FName name, List<int> usedExports) : base(name) {
            UsedExports = usedExports;
        }
        public DetachedObjectPropertyData() {}
    }

    public UAsset OriginalUAsset;
    public List<int> UsedImports = new List<int>();
    public HashSet<int> UsedImportSet = new HashSet<int>();
    public List<int> UsedExports = new List<int>();
    public HashSet<int> UsedExportSet = new HashSet<int>();
    public int RootExportIndex = -1; // 0 based list index! NOT the 1 based export number.
    public List<UAssetExportTreeItem> ExportTree = new List<UAssetExportTreeItem>();
    public List<UAssetImportTreeItem> ImportTree = new List<UAssetImportTreeItem>();

    public UAssetSnippet(UAsset originalUAsset, int rootExportIndex) {
        OriginalUAsset = originalUAsset;
        RootExportIndex = rootExportIndex;

        BuildImportTree();
        BuildExportTree();
        BuildUsedExports();
        BuildUsedImports();
    }

    private void BuildImportTree() {
        // Build dependency tree
        int importIndex = 0;
        foreach (Import import in OriginalUAsset.Imports) {
            // Set up class for dependency tree
            UAssetImportTreeItem importTreeItem = new UAssetImportTreeItem();
            importTreeItem.ImportIndex = importIndex;
            ImportTree.Add(
                importTreeItem
            );
            importIndex++;
        }

        // Populate tree based on imports that reference via outerIndex
        importIndex = 0;
        foreach (Import import in OriginalUAsset.Imports) {
            UAssetImportTreeItem importTreeItem = ImportTree[importIndex];
            if (import.OuterIndex.Index < 0) {
                int parentImportIndex = import.OuterIndex.Index;
                while (parentImportIndex != 0) {
                    int arrayParentIndex = Math.Abs(parentImportIndex) - 1;
                    if (arrayParentIndex >= 0 && arrayParentIndex < ImportTree.Count) {
                        importTreeItem.ParentImports.Add(arrayParentIndex);
                        parentImportIndex = OriginalUAsset.Imports[arrayParentIndex].OuterIndex.Index;
                    } else {
                        break;
                    }
                }
            }
            importIndex++;
        }
    }

    private void BuildExportTree() {
        // Build dependency tree
        int exportIndex = 0;
        foreach (Export baseExport in OriginalUAsset.Exports) {
            // Set up class for dependency tree
            UAssetExportTreeItem exportTreeItem = new UAssetExportTreeItem();
            exportTreeItem.ExportIndex = exportIndex;
            ExportTree.Add(
                exportTreeItem
            );
            exportIndex++;
        }

        // Populate attach parent for each exportTree item
        exportIndex = 0;
        foreach (Export baseExport in OriginalUAsset.Exports) {
            if (baseExport is NormalExport export) {
                foreach (PropertyData propertyData in export.Data) {
                    string propertyName = propertyData.Name.Value.ToString();
                    if (propertyData is ObjectPropertyData objectPropertyData) {
                        if (propertyName == "AttachParent") {
                            try {
                                ExportTree[exportIndex].IsRoot = false;
                                ExportTree[objectPropertyData.Value.Index - 1].AttachedChildren.Add(ExportTree[exportIndex]);
                            } catch (Exception e) {
                                GD.Print("Set up Attach Parent error ", e);
                            }
                        }
                    }
                }
            }
            exportIndex++;
        }
    }

    private void BuildUsedExports() {
        UsedExports.Add(RootExportIndex);
        UsedExportSet.Add(RootExportIndex);
        for (int i = 0; i < UsedExports.Count; i++) {
            Export checkExport = OriginalUAsset.Exports[UsedExports[i]];
            if (checkExport is NormalExport normalCheckExport) {
                List<int> referencedObjects = GetPropertyDataReferencedObjects(new List<PropertyData>(normalCheckExport.Data));
                foreach (int referencedObjectIndex in referencedObjects) {
                    if (referencedObjectIndex >= 0 && referencedObjectIndex < ExportTree.Count) {
                        if (!UsedExportSet.Contains(referencedObjectIndex)) {
                            UsedExportSet.Add(referencedObjectIndex);
                            UsedExports.Add(referencedObjectIndex);
                            List<int> attachedChildrenReferencedObjects = GetAttachedChildrenReferencedObjects(ExportTree[referencedObjectIndex]);
                            foreach (int attachedReferencedObjectIndex in attachedChildrenReferencedObjects) {
                                if (!UsedExportSet.Contains(attachedReferencedObjectIndex)) {
                                    UsedExportSet.Add(attachedReferencedObjectIndex);
                                    UsedExports.Add(attachedReferencedObjectIndex);
                                }
                            }
                        }
                    } else {
                        // Object referenced undefined index, ignore
                    }
                }
            }
        }
    }

    private void BuildUsedImports() {
        for (int i = 0; i < OriginalUAsset.Imports.Count; i++) {
            UsedImports.Add(i);
        }
        // for (int i = 0; i < UsedExports.Count; i++) {
        //     Export usedExport = OriginalUAsset.Exports[UsedExports[i]];
        //     int classIndex = usedExport.ReferenceData.ClassIndex;
        //     if (classIndex < 0) {
        //         int arrayClassIndex = Math.Abs(classIndex) - 1;
        //         if (!UsedImportSet.Contains(arrayClassIndex)) {
        //             UsedImportSet.Add(arrayClassIndex);
        //             UsedImports.Add(arrayClassIndex);
        //             List<int> parentImports = ImportTree[arrayClassIndex].ParentImports;
        //             foreach (int parentImportIndex in parentImports) {
        //                 if (!UsedImportSet.Contains(parentImportIndex)) {
        //                     UsedImportSet.Add(parentImportIndex);
        //                     UsedImports.Add(parentImportIndex);
        //                 }
        //             }
        //         }
        //     }
        // }
    }

    private List<int> GetAttachedChildrenReferencedObjects(UAssetExportTreeItem exportRoot) {
        List<int> referencedObjects = new List<int>();
        foreach (UAssetExportTreeItem exportChild in exportRoot.AttachedChildren) {
            referencedObjects.Add(exportChild.ExportIndex);
            referencedObjects = referencedObjects.Concat(GetAttachedChildrenReferencedObjects(exportChild)).ToList();
        }
        return referencedObjects;
    }

    private List<int> GetPropertyDataReferencedObjects(List<PropertyData> propertyDataList) {
        List<int> referencedObjects = new List<int>();
        foreach (PropertyData propertyData in propertyDataList) {
            if (propertyData is ObjectPropertyData objectPropertyData) {
                referencedObjects.Add(objectPropertyData.Value.Index - 1);
            } else if (propertyData is ArrayPropertyData arrayPropertyData) {
                referencedObjects = referencedObjects.Concat(GetPropertyDataReferencedObjects(arrayPropertyData.Value.ToList<PropertyData>())).ToList();
            }
        }
        return referencedObjects;
    }

    public void AddToUAsset(UAsset attachToAsset) {
        int importStartIndex = attachToAsset.Imports.Count;
        int exportStartIndex = attachToAsset.Exports.Count;

        // Add new imports to end of current asset's imports
        List<int> mappedImports = new List<int>();
        List<int> newlyAddedImports = new List<int>();
        foreach (int originalImportIndex in UsedImports) {
            Import originalImport = OriginalUAsset.Imports[originalImportIndex];
            int newImportIndex = GetExistingImportIndex(originalImport, attachToAsset);
            if (newImportIndex > -1) {
                mappedImports.Add(newImportIndex);
            } else {
                newlyAddedImports.Add(originalImportIndex);
                mappedImports.Add(attachToAsset.Imports.Count);
                Import clonedImport = CloneImport(originalImport, attachToAsset);
                attachToAsset.Imports.Add(clonedImport);
            }
        }
        // Modify outer index for each import (this equates to a noop if the import already exists in the file)
        for (int i = 0; i < UsedImports.Count; i++) {
            if (newlyAddedImports.IndexOf(i) > -1) {
                int mappedImportIndex = mappedImports[i];
                try {
                    int arrayOuterIndex = Math.Abs(attachToAsset.Imports[mappedImportIndex].OuterIndex.Index) - 1;
                    // Reassign outerIndex if it's not 0 (top level package)
                    if (arrayOuterIndex != -1) {
                        int usedImportIndex = UsedImports.IndexOf(arrayOuterIndex);
                        attachToAsset.Imports[mappedImportIndex].OuterIndex.Index = -(mappedImports[usedImportIndex] + 1);
                    }
                } catch (Exception e) {
                    GD.Print(e);
                }
            }
        }

        // Cloned used exports and add to end of current asset's exports
        foreach (int originalExportIndex in UsedExports) {
            Export clonedExport = CloneExport(OriginalUAsset.Exports[originalExportIndex], attachToAsset, exportStartIndex);
            try {
                int oldClassIndex = clonedExport.ClassIndex.Index;
                int oldClassIndexArrayIndex = Math.Abs(oldClassIndex) - 1;
                if (oldClassIndexArrayIndex >= 0) {
                    clonedExport.ClassIndex.Index = -(mappedImports[UsedImports.IndexOf(oldClassIndexArrayIndex)] + 1);
                }
            } catch (Exception e) {
                GD.Print(e);
            }
            attachToAsset.Exports.Add(clonedExport);
        }

        // Rename base export
        try {
            FString newName = new FString("TEST_ADD_SNIPPET");
            attachToAsset.AddNameReference(newName);
            attachToAsset.Exports[exportStartIndex].ObjectName = new FName("TEST_ADD_SNIPPET", 0);
        } catch (Exception e) {
            GD.Print(e);
        }
        
        // Add the base export (blueprint) to the level
        int exportNumber = 1;
        foreach (Export baseExport in attachToAsset.Exports) {
            if (baseExport is LevelExport levelExport) {
                levelExport.IndexData.Add(exportStartIndex + 1);
                attachToAsset.Exports[exportStartIndex].OuterIndex.Index = exportNumber;
                break;
            }
            exportNumber++;
        }
    }

    public int GetExistingImportIndex(Import checkImport, UAsset uAsset) {
        int importIndex = -1;
        string classPackageString = checkImport.ClassPackage.ToString();
        string classNameString = checkImport.ClassName.ToString();
        string objectNameString = checkImport.ObjectName.ToString();
        for (int i = 0; i < uAsset.Imports.Count; i++) {
            Import import = uAsset.Imports[i];
            if (import.ObjectName.ToString() == objectNameString && import.ClassName.ToString() == classNameString && import.ClassPackage.ToString() == classPackageString) {
                importIndex = i;
                break;
            }
        }
        return importIndex;
    }

    public Import CloneImport(Import originalImport, UAsset attachToAsset) {
        attachToAsset.AddNameReference(originalImport.ClassPackage.Value);
        attachToAsset.AddNameReference(originalImport.ClassName.Value);
        attachToAsset.AddNameReference(originalImport.ObjectName.Value);
        FName classPackage = new FName(originalImport.ClassPackage.Value, originalImport.ClassPackage.Number);
        FName className = new FName(originalImport.ClassName.Value, originalImport.ClassName.Number);
        FName objectName = new FName(originalImport.ObjectName.Value, originalImport.ObjectName.Number);
        Import clonedImport = new Import(classPackage, className, originalImport.OuterIndex, objectName);
        return clonedImport;
    }

    public Export CloneExport(Export export, UAsset attachToAsset, int exportStartIndex) {
        int newOuterIndex = UsedExports.IndexOf(export.OuterIndex.Index - 1);
        if (newOuterIndex != -1) {
            newOuterIndex += exportStartIndex + 1;
        } else {
            newOuterIndex = export.OuterIndex.Index;
        }
        byte[] extras = new byte[export.Extras.Length];
        export.Extras.CopyTo(extras, 0);
        Export newExport = new Export(
            attachToAsset,
            extras
        );
        newExport.ClassIndex = export.ClassIndex;
        newExport.SuperIndex = export.SuperIndex;
        newExport.TemplateIndex = export.TemplateIndex;
        newExport.OuterIndex = FPackageIndex.FromRawIndex(newOuterIndex);
        newExport.ObjectName = export.ObjectName;
        newExport.ObjectFlags = export.ObjectFlags;
        newExport.SerialSize = Convert.ToInt32(export.SerialSize);
        newExport.SerialOffset = Convert.ToInt32(export.SerialOffset);
        newExport.bForcedExport = export.bForcedExport;
        newExport.bNotForClient = export.bNotForClient;
        newExport.bNotForServer = export.bNotForServer;
        newExport.PackageGuid = export.PackageGuid;
        newExport.PackageFlags = export.PackageFlags;
        newExport.bNotAlwaysLoadedForEditorGame = export.bNotAlwaysLoadedForEditorGame;
        newExport.bIsAsset = export.bIsAsset;
        newExport.FirstExportDependency = export.FirstExportDependency;
        newExport.SerializationBeforeSerializationDependencies = export.SerializationBeforeSerializationDependencies;
        newExport.CreateBeforeSerializationDependencies = export.CreateBeforeSerializationDependencies;
        newExport.SerializationBeforeCreateDependencies = export.SerializationBeforeCreateDependencies;
        newExport.CreateBeforeCreateDependencies = export.CreateBeforeCreateDependencies;
        if (export is ClassExport classExport) {
            ClassExport newClassExport = new ClassExport(newExport);
            return newClassExport;
        } else if (export is NormalExport normalExport) {
            NormalExport newNormalExport = new NormalExport(newExport);
            newNormalExport.Data = ClonePropertyData(new List<PropertyData>(normalExport.Data), attachToAsset, exportStartIndex);
            return newNormalExport;
        } else {
            return newExport;
        }
    }

    public System.Object DeepClone(System.Object original) {
        MemoryStream stream = new MemoryStream();
        BinaryFormatter formatter = new BinaryFormatter();
        formatter.Context = new StreamingContext(StreamingContextStates.Clone);
        formatter.Serialize(stream, original);
        stream.Position = 0;
        return (formatter.Deserialize(stream));
    }

    public List<PropertyData> ClonePropertyData(List<PropertyData> propertyDataList, UAsset attachToAsset, int exportStartIndex) {
        List<PropertyData> newPropertyDataList = new List<PropertyData>();
        foreach (PropertyData propertyData in propertyDataList) {
            FName newPropertyName = new FName(propertyData.Name.Value.Value, propertyData.Name.Number);
            attachToAsset.AddNameReference(newPropertyName.Value);
            if (propertyData is ArrayPropertyData arrayPropertyData) {
                ArrayPropertyData newArrayPropertyData = new ArrayPropertyData(newPropertyName);
                newArrayPropertyData.Value = ClonePropertyData(arrayPropertyData.Value.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                newPropertyDataList.Add(newArrayPropertyData);
            }
            else if (propertyData is BoolPropertyData boolPropertyData) {
                BoolPropertyData newBoolPropertyData = new BoolPropertyData(newPropertyName);
                newBoolPropertyData.Value = boolPropertyData.Value;
                newPropertyDataList.Add(newBoolPropertyData);
            }
            else if (propertyData is BytePropertyData bytePropertyData) {
                BytePropertyData newBytePropertyData = new BytePropertyData(newPropertyName);
                newBytePropertyData.ByteType = bytePropertyData.ByteType;
                FString byteValueName = OriginalUAsset.GetNameReference(bytePropertyData.Value);
                attachToAsset.AddNameReference(byteValueName);
                newBytePropertyData.Value = attachToAsset.SearchNameReference(byteValueName);
                FString byteEnumTypeName = OriginalUAsset.GetNameReference(bytePropertyData.EnumType);
                attachToAsset.AddNameReference(byteEnumTypeName);
                newBytePropertyData.EnumType = attachToAsset.SearchNameReference(byteEnumTypeName);
                newPropertyDataList.Add(newBytePropertyData);
            }
            else if (propertyData is EnumPropertyData enumPropertyData) {
                EnumPropertyData newEnumPropertyData = new EnumPropertyData(newPropertyName);
                FName newEnumValue = new FName(enumPropertyData.Value.Value.Value, enumPropertyData.Value.Number);
                FName newEnumType = new FName(enumPropertyData.EnumType.Value.Value, enumPropertyData.EnumType.Number);
                attachToAsset.AddNameReference(newEnumValue.Value);
                attachToAsset.AddNameReference(newEnumType.Value);
                newEnumPropertyData.Value = newEnumValue;
                newEnumPropertyData.EnumType = newEnumType;
                newPropertyDataList.Add(newEnumPropertyData);
            }
            else if (propertyData is FloatPropertyData floatPropertyData) {
                FloatPropertyData newFloatPropertyData = new FloatPropertyData(newPropertyName);
                newFloatPropertyData.Value = floatPropertyData.Value;
                newPropertyDataList.Add(newFloatPropertyData);
            }
            else if (propertyData is Int8PropertyData int8PropertyData) {
                Int8PropertyData newInt8PropertyData = new Int8PropertyData(newPropertyName);
                newInt8PropertyData.Value = int8PropertyData.Value;
                newPropertyDataList.Add(newInt8PropertyData);
            }
            else if (propertyData is Int16PropertyData int16PropertyData) {
                Int16PropertyData newInt16PropertyData = new Int16PropertyData(newPropertyName);
                newInt16PropertyData.Value = int16PropertyData.Value;
                newPropertyDataList.Add(newInt16PropertyData);
            }
            else if (propertyData is Int64PropertyData int64PropertyData) {
                Int64PropertyData newInt64PropertyData = new Int64PropertyData(newPropertyName);
                newInt64PropertyData.Value = int64PropertyData.Value;
                newPropertyDataList.Add(newInt64PropertyData);
            }
            else if (propertyData is IntPropertyData intPropertyData) {
                IntPropertyData newIntPropertyData = new IntPropertyData(newPropertyName);
                newIntPropertyData.Value = intPropertyData.Value;
                newPropertyDataList.Add(newIntPropertyData);
            }
            else if (propertyData is MapPropertyData mapPropertyData) {
                newPropertyDataList.Add((MapPropertyData)mapPropertyData.Clone());
            }
            else if (propertyData is MulticastDelegatePropertyData multicastDelegatePropertyData) {
                MulticastDelegatePropertyData newMulticastDelegatePropertyData = new MulticastDelegatePropertyData(newPropertyName);
                FMulticastDelegate[] newValue = new FMulticastDelegate[multicastDelegatePropertyData.Value.Length];
                for (int i = 0; i < multicastDelegatePropertyData.Value.Length; i++) {
                    attachToAsset.AddNameReference(multicastDelegatePropertyData.Value[i].Delegate.Value);
                    newValue[i] = new FMulticastDelegate(
                        multicastDelegatePropertyData.Value[i].Number,
                        new FName(multicastDelegatePropertyData.Value[i].Delegate.Value.Value, multicastDelegatePropertyData.Value[i].Delegate.Number)
                    );
                }
                newMulticastDelegatePropertyData.Value = newValue;
                newPropertyDataList.Add(newMulticastDelegatePropertyData);
            }
            else if (propertyData is NamePropertyData namePropertyData) {
                NamePropertyData newNamePropertyData = new NamePropertyData(newPropertyName);
                attachToAsset.AddNameReference(namePropertyData.Value.Value);
                newNamePropertyData.Value = new FName(namePropertyData.Value.Value.Value, namePropertyData.Value.Number);
                newPropertyDataList.Add(newNamePropertyData);
            }
            else if (propertyData is ObjectPropertyData objectPropertyData) {
                ObjectPropertyData newObjectPropertyData = new ObjectPropertyData(newPropertyName);
                int newCurrentIndex = UsedExports.IndexOf(objectPropertyData.Value.Index - 1);
                if (newCurrentIndex != -1) {
                    newCurrentIndex += exportStartIndex + 1;
                } else {
                    newCurrentIndex = 0;
                }
                newObjectPropertyData.Value = FPackageIndex.FromRawIndex(newCurrentIndex);
                newPropertyDataList.Add(newObjectPropertyData);
            }
            else if (propertyData is SetPropertyData setPropertyData) {
                SetPropertyData newSetPropertyData = new SetPropertyData(newPropertyName);
                newSetPropertyData.Value = ClonePropertyData(setPropertyData.Value.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                newSetPropertyData.RemovedItems = ClonePropertyData(setPropertyData.RemovedItems.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                newSetPropertyData.RemovedItemsDummyStruct = setPropertyData.RemovedItemsDummyStruct; // TODO - Need new object?
                newPropertyDataList.Add(newSetPropertyData);
            }
            else if (propertyData is SoftAssetPathPropertyData softAssetPathPropertyData) {
                newPropertyDataList.Add((SoftAssetPathPropertyData)softAssetPathPropertyData.Clone());
            }
            else if (propertyData is SoftClassPathPropertyData softClassPathPropertyData) {
                newPropertyDataList.Add((SoftClassPathPropertyData)softClassPathPropertyData.Clone());
            }
            else if (propertyData is SoftObjectPropertyData softObjectPropertyData) {
                newPropertyDataList.Add((SoftObjectPropertyData)softObjectPropertyData.Clone());
            }
            else if (propertyData is StrPropertyData strPropertyData) {
                StrPropertyData newStrPropertyData = new StrPropertyData(newPropertyName);
                newStrPropertyData.Value = strPropertyData.Value;
                newPropertyDataList.Add(newStrPropertyData);
            }
            else if (propertyData is TextPropertyData textPropertyData) {
                TextPropertyData newTextPropertyData = new TextPropertyData(newPropertyName);
                newTextPropertyData.Value = new FString(textPropertyData.Value.Value, textPropertyData.Value.Encoding);
                newTextPropertyData.Flags = textPropertyData.Flags;
                newTextPropertyData.HistoryType = textPropertyData.HistoryType;
                if (textPropertyData.TableId != null) {
                    attachToAsset.AddNameReference(textPropertyData.TableId.Value);
                    newTextPropertyData.TableId = new FName(textPropertyData.TableId.Value.Value, textPropertyData.TableId.Number);
                }
                if (textPropertyData.Namespace != null) {
                    attachToAsset.AddNameReference(textPropertyData.Namespace);
                    newTextPropertyData.Namespace = new FString(textPropertyData.Namespace.Value, textPropertyData.Namespace.Encoding);
                }
                if (textPropertyData.CultureInvariantString != null) {
                    attachToAsset.AddNameReference(textPropertyData.CultureInvariantString);
                    newTextPropertyData.CultureInvariantString = new FString(textPropertyData.CultureInvariantString.Value, textPropertyData.CultureInvariantString.Encoding);
                }
                newPropertyDataList.Add(newTextPropertyData);
            }
            else if (propertyData is UInt16PropertyData uInt16PropertyData) {
                UInt16PropertyData newUInt16PropertyData = new UInt16PropertyData(newPropertyName);
                newUInt16PropertyData.Value = uInt16PropertyData.Value;
                newPropertyDataList.Add(newUInt16PropertyData);
            }
            else if (propertyData is UInt32PropertyData uInt32PropertyData) {
                UInt32PropertyData newUInt32PropertyData = new UInt32PropertyData(newPropertyName);
                newUInt32PropertyData.Value = uInt32PropertyData.Value;
                newPropertyDataList.Add(newUInt32PropertyData);
            }
            else if (propertyData is UInt64PropertyData uInt64PropertyData) {
                UInt64PropertyData newUInt64PropertyData = new UInt64PropertyData(newPropertyName);
                newUInt64PropertyData.Value = uInt64PropertyData.Value;
                newPropertyDataList.Add(newUInt64PropertyData);
            }
            else if (propertyData is UnknownPropertyData unknownPropertyData) {
                UnknownPropertyData newUnknownPropertyData = new UnknownPropertyData(newPropertyName);
                newUnknownPropertyData.Value = unknownPropertyData.Value;
                newPropertyDataList.Add(newUnknownPropertyData);
            }
            else if (propertyData is BoxPropertyData boxPropertyData) {
                BoxPropertyData newBoxPropertyData = new BoxPropertyData(newPropertyName);
                newBoxPropertyData.Value = (VectorPropertyData[])ClonePropertyData(boxPropertyData.Value.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                newBoxPropertyData.IsValid = boxPropertyData.IsValid;
                newPropertyDataList.Add(newBoxPropertyData);
            }
            else if (propertyData is ColorPropertyData colorPropertyData) {
                ColorPropertyData newColorPropertyData = new ColorPropertyData(newPropertyName);
                newColorPropertyData.Value = System.Drawing.Color.FromArgb(colorPropertyData.Value.A, colorPropertyData.Value.R, colorPropertyData.Value.G, colorPropertyData.Value.B);
                newPropertyDataList.Add(newColorPropertyData);
            }
            else if (propertyData is DateTimePropertyData dateTimePropertyData) {
                DateTimePropertyData newDateTimePropertyData = new DateTimePropertyData(newPropertyName);
                newDateTimePropertyData.Value = dateTimePropertyData.Value;
                newPropertyDataList.Add(newDateTimePropertyData);
            }
            else if (propertyData is GameplayTagContainerPropertyData gameplayTagContainerPropertyData) {
                GameplayTagContainerPropertyData newGameplayTagContainerPropertyData = new GameplayTagContainerPropertyData(newPropertyName);
                newGameplayTagContainerPropertyData.Value = (NamePropertyData[])ClonePropertyData(gameplayTagContainerPropertyData.Value.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                newPropertyDataList.Add(newGameplayTagContainerPropertyData);
            }
            else if (propertyData is GuidPropertyData guidPropertyData) {
                GuidPropertyData newGuidPropertyData = new GuidPropertyData(newPropertyName);
                newGuidPropertyData.Value = guidPropertyData.Value;
                newPropertyDataList.Add(newGuidPropertyData);
            }
            else if (propertyData is IntPointPropertyData intPointPropertyData) {
                IntPointPropertyData newIntPointPropertyData = new IntPointPropertyData(newPropertyName);
                int[] newValue = new int[intPointPropertyData.Value.Length];
                intPointPropertyData.Value.CopyTo(newValue, 0);
                newIntPointPropertyData.Value = newValue;
                newPropertyDataList.Add(newIntPointPropertyData);
            }
            else if (propertyData is LinearColorPropertyData linearColorPropertyData) {
                LinearColorPropertyData newLinearColorPropertyData = new LinearColorPropertyData(newPropertyName);
                newLinearColorPropertyData.Value = new LinearColor(linearColorPropertyData.Value.R, linearColorPropertyData.Value.G, linearColorPropertyData.Value.B, linearColorPropertyData.Value.A);
                newPropertyDataList.Add(newLinearColorPropertyData);
            }
            else if (propertyData is ExpressionInputPropertyData expressionInputPropertyData) {
                newPropertyDataList.Add((ExpressionInputPropertyData)expressionInputPropertyData.Clone());
            }
            else if (propertyData is MaterialAttributesInputPropertyData materialAttributesInputPropertyData) {
                newPropertyDataList.Add((MaterialAttributesInputPropertyData)materialAttributesInputPropertyData.Clone());
            }
            else if (propertyData is ColorMaterialInputPropertyData colorMaterialInputPropertyData) {
                newPropertyDataList.Add((ColorMaterialInputPropertyData)colorMaterialInputPropertyData.Clone());
            }
            else if (propertyData is ScalarMaterialInputPropertyData scalarMaterialInputPropertyData) {
                newPropertyDataList.Add((ScalarMaterialInputPropertyData)scalarMaterialInputPropertyData.Clone());
            }
            else if (propertyData is ShadingModelMaterialInputPropertyData shadingModelMaterialInputPropertyData) {
                newPropertyDataList.Add((ShadingModelMaterialInputPropertyData)shadingModelMaterialInputPropertyData.Clone());
            }
            else if (propertyData is VectorMaterialInputPropertyData vectorMaterialInputPropertyData) {
                newPropertyDataList.Add((VectorMaterialInputPropertyData)vectorMaterialInputPropertyData.Clone());
            }
            else if (propertyData is Vector2MaterialInputPropertyData vector2MaterialInputPropertyData) {
                newPropertyDataList.Add((Vector2MaterialInputPropertyData)vector2MaterialInputPropertyData.Clone());
            }
            else if (propertyData is PerPlatformBoolPropertyData perPlatformBoolPropertyData) {
                PerPlatformBoolPropertyData newPerPlatformBoolPropertyData = new PerPlatformBoolPropertyData(newPropertyName);
                bool[] newValue = new bool[perPlatformBoolPropertyData.Value.Length];
                perPlatformBoolPropertyData.Value.CopyTo(newValue, 0);
                newPerPlatformBoolPropertyData.Value = newValue;
                newPropertyDataList.Add(newPerPlatformBoolPropertyData);
            }
            else if (propertyData is PerPlatformFloatPropertyData perPlatformFloatPropertyData) {
                PerPlatformFloatPropertyData newPerPlatformFloatPropertyData = new PerPlatformFloatPropertyData(newPropertyName);
                float[] newValue = new float[perPlatformFloatPropertyData.Value.Length];
                perPlatformFloatPropertyData.Value.CopyTo(newValue, 0);
                newPerPlatformFloatPropertyData.Value = newValue;
                newPropertyDataList.Add(newPerPlatformFloatPropertyData);
            }
            else if (propertyData is QuatPropertyData quatPropertyData) {
                newPropertyDataList.Add((QuatPropertyData)quatPropertyData.Clone());
            }
            else if (propertyData is RichCurveKeyPropertyData richCurveKeyPropertyData) {
                newPropertyDataList.Add((RichCurveKeyPropertyData)richCurveKeyPropertyData.Clone());
            }
            else if (propertyData is RotatorPropertyData rotatorPropertyData) {
                newPropertyDataList.Add((RotatorPropertyData)rotatorPropertyData.Clone());
            }
            else if (propertyData is StructPropertyData structPropertyData) {
                newPropertyDataList.Add((StructPropertyData)structPropertyData.Clone());
            }
            else if (propertyData is TimespanPropertyData timespanPropertyData) {
                TimespanPropertyData newTimespanPropertyData = new TimespanPropertyData(newPropertyName);
                newTimespanPropertyData.Value = timespanPropertyData.Value;
                newPropertyDataList.Add(newTimespanPropertyData);
            }
            else if (propertyData is Vector2DPropertyData vector2DPropertyData) {
                newPropertyDataList.Add((Vector2DPropertyData)vector2DPropertyData.Clone());
            }
            else if (propertyData is Vector4PropertyData vector4PropertyData) {
                newPropertyDataList.Add((Vector4PropertyData)vector4PropertyData.Clone());
            }
            else if (propertyData is VectorPropertyData vectorPropertyData) {
                newPropertyDataList.Add((VectorPropertyData)vectorPropertyData.Clone());
            }
            else if (propertyData is ViewTargetBlendParamsPropertyData viewTargetBlendParamsPropertyData) {
                ViewTargetBlendParamsPropertyData newViewTargetBlendParamsPropertyData = new ViewTargetBlendParamsPropertyData(newPropertyName);
                newViewTargetBlendParamsPropertyData.BlendTime = viewTargetBlendParamsPropertyData.BlendTime;
                newViewTargetBlendParamsPropertyData.BlendFunction = viewTargetBlendParamsPropertyData.BlendFunction;
                newViewTargetBlendParamsPropertyData.BlendExp = viewTargetBlendParamsPropertyData.BlendExp;
                newViewTargetBlendParamsPropertyData.bLockOutgoing = viewTargetBlendParamsPropertyData.bLockOutgoing;
                newPropertyDataList.Add(newViewTargetBlendParamsPropertyData);
            }
        }
        return newPropertyDataList;
    }

}