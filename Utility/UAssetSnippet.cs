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
        public DetachedObjectPropertyData(FName name, UAsset asset, List<int> usedExports) : base(name, asset) {
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
            if (import.OuterIndex < 0) {
                int parentImportIndex = import.OuterIndex;
                while (parentImportIndex != 0) {
                    int arrayParentIndex = Math.Abs(parentImportIndex) - 1;
                    if (arrayParentIndex >= 0 && arrayParentIndex < ImportTree.Count) {
                        importTreeItem.ParentImports.Add(arrayParentIndex);
                        parentImportIndex = OriginalUAsset.Imports[arrayParentIndex].OuterIndex;
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
                    int arrayOuterIndex = Math.Abs(attachToAsset.Imports[mappedImportIndex].OuterIndex) - 1;
                    // Reassign outerIndex if it's not 0 (top level package)
                    if (arrayOuterIndex != -1) {
                        int usedImportIndex = UsedImports.IndexOf(arrayOuterIndex);
                        attachToAsset.Imports[mappedImportIndex].OuterIndex = -(mappedImports[usedImportIndex] + 1);
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
                attachToAsset.Exports[exportStartIndex].OuterIndex = exportNumber;
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
        int newOuterIndex = UsedExports.IndexOf(export.OuterIndex - 1);
        if (newOuterIndex != -1) {
            newOuterIndex += exportStartIndex + 1;
        } else {
            newOuterIndex = export.OuterIndex;
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
        newExport.OuterIndex = newOuterIndex;
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
                ArrayPropertyData newArrayPropertyData = new ArrayPropertyData(newPropertyName, attachToAsset);
                newArrayPropertyData.Value = ClonePropertyData(arrayPropertyData.Value.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                newPropertyDataList.Add(newArrayPropertyData);
            }
            else if (propertyData is BoolPropertyData boolPropertyData) {
                BoolPropertyData newBoolPropertyData = new BoolPropertyData(newPropertyName, attachToAsset);
                newBoolPropertyData.Value = boolPropertyData.Value;
                newPropertyDataList.Add(newBoolPropertyData);
            }
            else if (propertyData is BytePropertyData bytePropertyData) {
                BytePropertyData newBytePropertyData = new BytePropertyData(newPropertyName, attachToAsset);
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
                EnumPropertyData newEnumPropertyData = new EnumPropertyData(newPropertyName, attachToAsset);
                FName newEnumValue = new FName(enumPropertyData.Value.Value.Value, enumPropertyData.Value.Number);
                FName newEnumType = new FName(enumPropertyData.EnumType.Value.Value, enumPropertyData.EnumType.Number);
                attachToAsset.AddNameReference(newEnumValue.Value);
                attachToAsset.AddNameReference(newEnumType.Value);
                newEnumPropertyData.Value = newEnumValue;
                newEnumPropertyData.EnumType = newEnumType;
                newPropertyDataList.Add(newEnumPropertyData);
            }
            else if (propertyData is FloatPropertyData floatPropertyData) {
                FloatPropertyData newFloatPropertyData = new FloatPropertyData(newPropertyName, attachToAsset);
                newFloatPropertyData.Value = floatPropertyData.Value;
                newPropertyDataList.Add(newFloatPropertyData);
            }
            else if (propertyData is Int8PropertyData int8PropertyData) {
                Int8PropertyData newInt8PropertyData = new Int8PropertyData(newPropertyName, attachToAsset);
                newInt8PropertyData.Value = int8PropertyData.Value;
                newPropertyDataList.Add(newInt8PropertyData);
            }
            else if (propertyData is Int16PropertyData int16PropertyData) {
                Int16PropertyData newInt16PropertyData = new Int16PropertyData(newPropertyName, attachToAsset);
                newInt16PropertyData.Value = int16PropertyData.Value;
                newPropertyDataList.Add(newInt16PropertyData);
            }
            else if (propertyData is Int64PropertyData int64PropertyData) {
                Int64PropertyData newInt64PropertyData = new Int64PropertyData(newPropertyName, attachToAsset);
                newInt64PropertyData.Value = int64PropertyData.Value;
                newPropertyDataList.Add(newInt64PropertyData);
            }
            else if (propertyData is IntPropertyData intPropertyData) {
                IntPropertyData newIntPropertyData = new IntPropertyData(newPropertyName, attachToAsset);
                newIntPropertyData.Value = intPropertyData.Value;
                newPropertyDataList.Add(newIntPropertyData);
            }
            else if (propertyData is MapPropertyData mapPropertyData) {
                MapPropertyData newMapPropertyData = new MapPropertyData(newPropertyName, attachToAsset);
                newMapPropertyData.Value = (OrderedDictionary)DeepClone(mapPropertyData.Value);
                FName[] newDummyEntry = new FName[mapPropertyData.dummyEntry.Length];
                for (int i = 0; i < mapPropertyData.dummyEntry.Length; i++) {
                    FName dummyEntry = mapPropertyData.dummyEntry[i];
                    attachToAsset.AddNameReference(dummyEntry.Value);
                    newDummyEntry[i] = new FName(dummyEntry.Value.Value);
                }
                newMapPropertyData.dummyEntry = mapPropertyData.dummyEntry; // TODO - Need new object?
                if (newMapPropertyData.KeysToRemove != null) {
                    newMapPropertyData.KeysToRemove = (OrderedDictionary)DeepClone(mapPropertyData.Value);
                }
                newPropertyDataList.Add(newMapPropertyData);
            }
            else if (propertyData is MulticastDelegatePropertyData multicastDelegatePropertyData) {
                MulticastDelegatePropertyData newMulticastDelegatePropertyData = new MulticastDelegatePropertyData(newPropertyName, attachToAsset);
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
                NamePropertyData newNamePropertyData = new NamePropertyData(newPropertyName, attachToAsset);
                attachToAsset.AddNameReference(namePropertyData.Value.Value);
                newNamePropertyData.Value = new FName(namePropertyData.Value.Value.Value, namePropertyData.Value.Number);
                newPropertyDataList.Add(newNamePropertyData);
            }
            else if (propertyData is ObjectPropertyData objectPropertyData) {
                ObjectPropertyData newObjectPropertyData = new ObjectPropertyData(newPropertyName, attachToAsset);
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
                SetPropertyData newSetPropertyData = new SetPropertyData(newPropertyName, attachToAsset);
                newSetPropertyData.Value = ClonePropertyData(setPropertyData.Value.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                newSetPropertyData.RemovedItems = ClonePropertyData(setPropertyData.RemovedItems.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                newSetPropertyData.RemovedItemsDummyStruct = setPropertyData.RemovedItemsDummyStruct; // TODO - Need new object?
                newPropertyDataList.Add(newSetPropertyData);
            }
            else if (propertyData is SoftAssetPathPropertyData softAssetPathPropertyData) {
                SoftAssetPathPropertyData newSoftAssetPathPropertyData = new SoftAssetPathPropertyData(newPropertyName, attachToAsset);
                attachToAsset.AddNameReference(softAssetPathPropertyData.Value.Value);
                newSoftAssetPathPropertyData.Value = new FName(softAssetPathPropertyData.Value.Value.Value, softAssetPathPropertyData.Value.Number);
                newSoftAssetPathPropertyData.ID = softAssetPathPropertyData.ID;
                newPropertyDataList.Add(newSoftAssetPathPropertyData);
            }
            else if (propertyData is SoftClassPathPropertyData softClassPathPropertyData) {
                SoftClassPathPropertyData newSoftClassPathPropertyData = new SoftClassPathPropertyData(newPropertyName, attachToAsset);
                attachToAsset.AddNameReference(softClassPathPropertyData.Value.Value);
                newSoftClassPathPropertyData.Value = new FName(softClassPathPropertyData.Value.Value.Value, softClassPathPropertyData.Value.Number);
                newSoftClassPathPropertyData.ID = softClassPathPropertyData.ID;
                newPropertyDataList.Add(newSoftClassPathPropertyData);
            }
            else if (propertyData is SoftObjectPropertyData softObjectPropertyData) {
                SoftObjectPropertyData newSoftObjectPropertyData = new SoftObjectPropertyData(newPropertyName, attachToAsset);
                attachToAsset.AddNameReference(softObjectPropertyData.Value.Value);
                newSoftObjectPropertyData.Value = new FName(softObjectPropertyData.Value.Value.Value, softObjectPropertyData.Value.Number);
                newSoftObjectPropertyData.ID = softObjectPropertyData.ID;
                newPropertyDataList.Add(newSoftObjectPropertyData);
            }
            else if (propertyData is StrPropertyData strPropertyData) {
                StrPropertyData newStrPropertyData = new StrPropertyData(newPropertyName, attachToAsset);
                newStrPropertyData.Value = strPropertyData.Value;
                newPropertyDataList.Add(newStrPropertyData);
            }
            else if (propertyData is TextPropertyData textPropertyData) {
                TextPropertyData newTextPropertyData = new TextPropertyData(newPropertyName, attachToAsset);
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
                UInt16PropertyData newUInt16PropertyData = new UInt16PropertyData(newPropertyName, attachToAsset);
                newUInt16PropertyData.Value = uInt16PropertyData.Value;
                newPropertyDataList.Add(newUInt16PropertyData);
            }
            else if (propertyData is UInt32PropertyData uInt32PropertyData) {
                UInt32PropertyData newUInt32PropertyData = new UInt32PropertyData(newPropertyName, attachToAsset);
                newUInt32PropertyData.Value = uInt32PropertyData.Value;
                newPropertyDataList.Add(newUInt32PropertyData);
            }
            else if (propertyData is UInt64PropertyData uInt64PropertyData) {
                UInt64PropertyData newUInt64PropertyData = new UInt64PropertyData(newPropertyName, attachToAsset);
                newUInt64PropertyData.Value = uInt64PropertyData.Value;
                newPropertyDataList.Add(newUInt64PropertyData);
            }
            else if (propertyData is UnknownPropertyData unknownPropertyData) {
                UnknownPropertyData newUnknownPropertyData = new UnknownPropertyData(newPropertyName, attachToAsset);
                newUnknownPropertyData.Value = unknownPropertyData.Value;
                newPropertyDataList.Add(newUnknownPropertyData);
            }
            else if (propertyData is BoxPropertyData boxPropertyData) {
                BoxPropertyData newBoxPropertyData = new BoxPropertyData(newPropertyName, attachToAsset);
                newBoxPropertyData.Value = (VectorPropertyData[])ClonePropertyData(boxPropertyData.Value.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                newBoxPropertyData.IsValid = boxPropertyData.IsValid;
                newPropertyDataList.Add(newBoxPropertyData);
            }
            else if (propertyData is ColorPropertyData colorPropertyData) {
                ColorPropertyData newColorPropertyData = new ColorPropertyData(newPropertyName, attachToAsset);
                newColorPropertyData.Value = System.Drawing.Color.FromArgb(colorPropertyData.Value.A, colorPropertyData.Value.R, colorPropertyData.Value.G, colorPropertyData.Value.B);
                newPropertyDataList.Add(newColorPropertyData);
            }
            else if (propertyData is DateTimePropertyData dateTimePropertyData) {
                DateTimePropertyData newDateTimePropertyData = new DateTimePropertyData(newPropertyName, attachToAsset);
                newDateTimePropertyData.Value = dateTimePropertyData.Value;
                newPropertyDataList.Add(newDateTimePropertyData);
            }
            else if (propertyData is GameplayTagContainerPropertyData gameplayTagContainerPropertyData) {
                GameplayTagContainerPropertyData newGameplayTagContainerPropertyData = new GameplayTagContainerPropertyData(newPropertyName, attachToAsset);
                newGameplayTagContainerPropertyData.Value = (NamePropertyData[])ClonePropertyData(gameplayTagContainerPropertyData.Value.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                newPropertyDataList.Add(newGameplayTagContainerPropertyData);
            }
            else if (propertyData is GuidPropertyData guidPropertyData) {
                GuidPropertyData newGuidPropertyData = new GuidPropertyData(newPropertyName, attachToAsset);
                newGuidPropertyData.Value = guidPropertyData.Value;
                newPropertyDataList.Add(newGuidPropertyData);
            }
            else if (propertyData is IntPointPropertyData intPointPropertyData) {
                IntPointPropertyData newIntPointPropertyData = new IntPointPropertyData(newPropertyName, attachToAsset);
                int[] newValue = new int[intPointPropertyData.Value.Length];
                intPointPropertyData.Value.CopyTo(newValue, 0);
                newIntPointPropertyData.Value = newValue;
                newPropertyDataList.Add(newIntPointPropertyData);
            }
            else if (propertyData is LinearColorPropertyData linearColorPropertyData) {
                LinearColorPropertyData newLinearColorPropertyData = new LinearColorPropertyData(newPropertyName, attachToAsset);
                newLinearColorPropertyData.Value = new LinearColor(linearColorPropertyData.Value.R, linearColorPropertyData.Value.G, linearColorPropertyData.Value.B, linearColorPropertyData.Value.A);
                newPropertyDataList.Add(newLinearColorPropertyData);
            }
            else if (propertyData is ExpressionInputPropertyData expressionInputPropertyData) {
                ExpressionInputPropertyData newExpressionInputPropertyData = new ExpressionInputPropertyData(newPropertyName, attachToAsset);
                newExpressionInputPropertyData.OutputIndex = expressionInputPropertyData.OutputIndex;
                newExpressionInputPropertyData.InputName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{expressionInputPropertyData.InputName}, attachToAsset, exportStartIndex).ToArray()[0];
                newExpressionInputPropertyData.ExpressionName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{expressionInputPropertyData.ExpressionName}, attachToAsset, exportStartIndex).ToArray()[0];
                newExpressionInputPropertyData.Value = expressionInputPropertyData.Value;
                newPropertyDataList.Add(newExpressionInputPropertyData);
            }
            else if (propertyData is MaterialAttributesInputPropertyData materialAttributesInputPropertyData) {
                MaterialAttributesInputPropertyData newMaterialAttributesInputPropertyData = new MaterialAttributesInputPropertyData(newPropertyName, attachToAsset);
                newMaterialAttributesInputPropertyData.OutputIndex = materialAttributesInputPropertyData.OutputIndex;
                newMaterialAttributesInputPropertyData.InputName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{materialAttributesInputPropertyData.InputName}, attachToAsset, exportStartIndex).ToArray()[0];
                newMaterialAttributesInputPropertyData.ExpressionName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{materialAttributesInputPropertyData.ExpressionName}, attachToAsset, exportStartIndex).ToArray()[0];
                newMaterialAttributesInputPropertyData.Value = materialAttributesInputPropertyData.Value;
                newPropertyDataList.Add(newMaterialAttributesInputPropertyData);
            }
            else if (propertyData is ColorMaterialInputPropertyData colorMaterialInputPropertyData) {
                ColorMaterialInputPropertyData newColorMaterialInputPropertyData = new ColorMaterialInputPropertyData(newPropertyName, attachToAsset);
                newColorMaterialInputPropertyData.OutputIndex = colorMaterialInputPropertyData.OutputIndex;
                newColorMaterialInputPropertyData.InputName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{colorMaterialInputPropertyData.InputName}, attachToAsset, exportStartIndex).ToArray()[0];
                newColorMaterialInputPropertyData.ExpressionName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{colorMaterialInputPropertyData.ExpressionName}, attachToAsset, exportStartIndex).ToArray()[0];
                newColorMaterialInputPropertyData.Value = (ColorPropertyData)ClonePropertyData(new List<PropertyData>{colorMaterialInputPropertyData.Value}, attachToAsset, exportStartIndex).ToArray()[0];
                newPropertyDataList.Add(newColorMaterialInputPropertyData);
            }
            else if (propertyData is ScalarMaterialInputPropertyData scalarMaterialInputPropertyData) {
                ScalarMaterialInputPropertyData newScalarMaterialInputPropertyData = new ScalarMaterialInputPropertyData(newPropertyName, attachToAsset);
                newScalarMaterialInputPropertyData.OutputIndex = scalarMaterialInputPropertyData.OutputIndex;
                newScalarMaterialInputPropertyData.InputName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{scalarMaterialInputPropertyData.InputName}, attachToAsset, exportStartIndex).ToArray()[0];
                newScalarMaterialInputPropertyData.ExpressionName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{scalarMaterialInputPropertyData.ExpressionName}, attachToAsset, exportStartIndex).ToArray()[0];
                newScalarMaterialInputPropertyData.Value = scalarMaterialInputPropertyData.Value;
                newPropertyDataList.Add(newScalarMaterialInputPropertyData);
            }
            else if (propertyData is ShadingModelMaterialInputPropertyData shadingModelMaterialInputPropertyData) {
                ShadingModelMaterialInputPropertyData newShadingModelMaterialInputPropertyData = new ShadingModelMaterialInputPropertyData(newPropertyName, attachToAsset);
                newShadingModelMaterialInputPropertyData.OutputIndex = shadingModelMaterialInputPropertyData.OutputIndex;
                newShadingModelMaterialInputPropertyData.InputName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{shadingModelMaterialInputPropertyData.InputName}, attachToAsset, exportStartIndex).ToArray()[0];
                newShadingModelMaterialInputPropertyData.ExpressionName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{shadingModelMaterialInputPropertyData.ExpressionName}, attachToAsset, exportStartIndex).ToArray()[0];
                newShadingModelMaterialInputPropertyData.Value = shadingModelMaterialInputPropertyData.Value;
                newPropertyDataList.Add(newShadingModelMaterialInputPropertyData);
            }
            else if (propertyData is VectorMaterialInputPropertyData vectorMaterialInputPropertyData) {
                VectorMaterialInputPropertyData newVectorMaterialInputPropertyData = new VectorMaterialInputPropertyData(newPropertyName, attachToAsset);
                newVectorMaterialInputPropertyData.OutputIndex = vectorMaterialInputPropertyData.OutputIndex;
                newVectorMaterialInputPropertyData.InputName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{vectorMaterialInputPropertyData.InputName}, attachToAsset, exportStartIndex).ToArray()[0];
                newVectorMaterialInputPropertyData.ExpressionName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{vectorMaterialInputPropertyData.ExpressionName}, attachToAsset, exportStartIndex).ToArray()[0];
                newVectorMaterialInputPropertyData.Value = (VectorPropertyData)ClonePropertyData(new List<PropertyData>{vectorMaterialInputPropertyData.Value}, attachToAsset, exportStartIndex).ToArray()[0];
                newPropertyDataList.Add(newVectorMaterialInputPropertyData);
            }
            else if (propertyData is Vector2MaterialInputPropertyData vector2MaterialInputPropertyData) {
                Vector2MaterialInputPropertyData newVector2MaterialInputPropertyData = new Vector2MaterialInputPropertyData(newPropertyName, attachToAsset);
                newVector2MaterialInputPropertyData.OutputIndex = vector2MaterialInputPropertyData.OutputIndex;
                newVector2MaterialInputPropertyData.InputName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{vector2MaterialInputPropertyData.InputName}, attachToAsset, exportStartIndex).ToArray()[0];
                newVector2MaterialInputPropertyData.ExpressionName = (NamePropertyData)ClonePropertyData(new List<PropertyData>{vector2MaterialInputPropertyData.ExpressionName}, attachToAsset, exportStartIndex).ToArray()[0];
                newVector2MaterialInputPropertyData.Value = (Vector2DPropertyData)ClonePropertyData(new List<PropertyData>{vector2MaterialInputPropertyData.Value}, attachToAsset, exportStartIndex).ToArray()[0];
                newPropertyDataList.Add(newVector2MaterialInputPropertyData);
            }
            else if (propertyData is PerPlatformBoolPropertyData perPlatformBoolPropertyData) {
                PerPlatformBoolPropertyData newPerPlatformBoolPropertyData = new PerPlatformBoolPropertyData(newPropertyName, attachToAsset);
                bool[] newValue = new bool[perPlatformBoolPropertyData.Value.Length];
                perPlatformBoolPropertyData.Value.CopyTo(newValue, 0);
                newPerPlatformBoolPropertyData.Value = newValue;
                newPropertyDataList.Add(newPerPlatformBoolPropertyData);
            }
            else if (propertyData is PerPlatformFloatPropertyData perPlatformFloatPropertyData) {
                PerPlatformFloatPropertyData newPerPlatformFloatPropertyData = new PerPlatformFloatPropertyData(newPropertyName, attachToAsset);
                float[] newValue = new float[perPlatformFloatPropertyData.Value.Length];
                perPlatformFloatPropertyData.Value.CopyTo(newValue, 0);
                newPerPlatformFloatPropertyData.Value = newValue;
                newPropertyDataList.Add(newPerPlatformFloatPropertyData);
            }
            else if (propertyData is QuatPropertyData quatPropertyData) {
                QuatPropertyData newQuatPropertyData = new QuatPropertyData(newPropertyName, attachToAsset);
                float[] newValue = new float[quatPropertyData.Value.Length];
                quatPropertyData.Value.CopyTo(newValue, 0);
                newQuatPropertyData.Value = newValue;
                newPropertyDataList.Add(newQuatPropertyData);
            }
            else if (propertyData is RichCurveKeyProperty richCurveKeyProperty) {
                RichCurveKeyProperty newRichCurveKeyProperty = new RichCurveKeyProperty(newPropertyName, attachToAsset);
                newRichCurveKeyProperty.InterpMode = richCurveKeyProperty.InterpMode;
                newRichCurveKeyProperty.TangentMode = richCurveKeyProperty.TangentMode;
                newRichCurveKeyProperty.TangentWeightMode = richCurveKeyProperty.TangentWeightMode;
                newRichCurveKeyProperty.Time = richCurveKeyProperty.Time;
                newRichCurveKeyProperty.Value = richCurveKeyProperty.Value;
                newRichCurveKeyProperty.ArriveTangent = richCurveKeyProperty.ArriveTangent;
                newRichCurveKeyProperty.ArriveTangentWeight = richCurveKeyProperty.ArriveTangentWeight;
                newRichCurveKeyProperty.LeaveTangent = richCurveKeyProperty.LeaveTangent;
                newRichCurveKeyProperty.LeaveTangentWeight = richCurveKeyProperty.LeaveTangentWeight;
                newPropertyDataList.Add(newRichCurveKeyProperty);
            }
            else if (propertyData is RotatorPropertyData rotatorPropertyData) {
                RotatorPropertyData newRotatorPropertyData = new RotatorPropertyData(newPropertyName, attachToAsset);
                float[] newValue = new float[rotatorPropertyData.Value.Length];
                rotatorPropertyData.Value.CopyTo(newValue, 0);
                newRotatorPropertyData.Value = newValue;
                newPropertyDataList.Add(newRotatorPropertyData);
            }
            else if (propertyData is StructPropertyData structPropertyData) {
                StructPropertyData newStructPropertyData = new StructPropertyData(newPropertyName, attachToAsset);
                newStructPropertyData.Value = ClonePropertyData(structPropertyData.Value.ToList<PropertyData>(), attachToAsset, exportStartIndex).ToArray();
                if (structPropertyData != null) {
                    attachToAsset.AddNameReference(structPropertyData.StructType.Value);
                    newStructPropertyData.StructType = new FName(structPropertyData.StructType.Value.Value, structPropertyData.StructType.Number);
                }
                newStructPropertyData.StructGUID = structPropertyData.StructGUID;
                newPropertyDataList.Add(newStructPropertyData);
            }
            else if (propertyData is TimespanPropertyData timespanPropertyData) {
                TimespanPropertyData newTimespanPropertyData = new TimespanPropertyData(newPropertyName, attachToAsset);
                newTimespanPropertyData.Value = timespanPropertyData.Value;
                newPropertyDataList.Add(newTimespanPropertyData);
            }
            else if (propertyData is Vector2DPropertyData vector2DPropertyData) {
                Vector2DPropertyData newVector2DPropertyData = new Vector2DPropertyData(newPropertyName, attachToAsset);
                float[] newValue = new float[vector2DPropertyData.Value.Length];
                vector2DPropertyData.Value.CopyTo(newValue, 0);
                newVector2DPropertyData.Value = newValue;
                newPropertyDataList.Add(newVector2DPropertyData);
            }
            else if (propertyData is Vector4PropertyData vector4PropertyData) {
                Vector4PropertyData newVector4PropertyData = new Vector4PropertyData(newPropertyName, attachToAsset);
                float[] newValue = new float[vector4PropertyData.Value.Length];
                vector4PropertyData.Value.CopyTo(newValue, 0);
                newVector4PropertyData.Value = newValue;
                newPropertyDataList.Add(newVector4PropertyData);
            }
            else if (propertyData is VectorPropertyData vectorPropertyData) {
                VectorPropertyData newVectorPropertyData = new VectorPropertyData(newPropertyName, attachToAsset);
                float[] newValue = new float[vectorPropertyData.Value.Length];
                vectorPropertyData.Value.CopyTo(newValue, 0);
                newVectorPropertyData.Value = newValue;
                newPropertyDataList.Add(newVectorPropertyData);
            }
            else if (propertyData is ViewTargetBlendParamsPropertyData viewTargetBlendParamsPropertyData) {
                ViewTargetBlendParamsPropertyData newViewTargetBlendParamsPropertyData = new ViewTargetBlendParamsPropertyData(newPropertyName, attachToAsset);
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