﻿using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace UAssetAPI
{
    public class NameMapOutOfRangeException : FormatException
    {
        public FString RequiredName;

        public NameMapOutOfRangeException(FString requiredName) : base("Requested name \"" + requiredName + "\" not found in name map")
        {
            RequiredName = requiredName;
        }
    }

    public class UnknownEngineVersionException : InvalidOperationException
    {
        public UnknownEngineVersionException(string message) : base(message)
        {

        }
    }

    public struct FEngineVersion
    {
        public ushort Major;
        public ushort Minor;
        public ushort Patch;
        public uint Changelist;
        public FString Branch;

        public void Write(BinaryWriter writer)
        {
            writer.Write(Major);
            writer.Write(Minor);
            writer.Write(Patch);
            writer.Write(Changelist);
            writer.WriteFString(Branch);
        }

        public FEngineVersion(BinaryReader reader)
        {
            Major = reader.ReadUInt16();
            Minor = reader.ReadUInt16();
            Patch = reader.ReadUInt16();
            Changelist = reader.ReadUInt32();
            Branch = reader.ReadFStringWithEncoding();
        }

        public FEngineVersion(ushort major, ushort minor, ushort patch, uint changelist, FString branch)
        {
            Major = major;
            Minor = minor;
            Patch = patch;
            Changelist = changelist;
            Branch = branch;
        }
    }

    public class FGenerationInfo
    {
        public int ExportCount;
        public int NameCount;

        public FGenerationInfo(int exportCount, int nameCount)
        {
            ExportCount = exportCount;
            NameCount = nameCount;
        }
    }

    public class UAsset
    {
        /**
         * The path of the file on disk that this asset represents. This does not need to be specified for regular parsing.
         */
        public string FilePath;

        /**
         * Will export data be serialized?
         */
        public bool WillWriteExportData = true;

        /**
         * Should the original copy of this asset be stored in memory as a byte array for reference when serializing, as opposed to accessing the file from disk?
         */
        public bool WillStoreOriginalCopyInMemory = false;

        /**
         * Should the asset be separated into .uasset, .uexp, and .ubulk files, as opposed to one single .uasset file?
         */
        public bool UseSeparateBulkDataFiles = false;

        /**
         * The original copy in memory to use as reference if WillStoreOriginalCopyInMemory is set to true.
         */
        public byte[] OriginalCopy;

        /**
         * The version of the Unreal Engine that will be used to parse this asset if it is unversioned.
         */
        public UE4Version EngineVersion = UE4Version.UNKNOWN;

        public bool VerifyParsing()
        {
            MemoryStream f = this.PathToStream(FilePath);
            f.Seek(0, SeekOrigin.Begin);
            MemoryStream newDataStream = WriteData(new BinaryReader(f));
            f.Seek(0, SeekOrigin.Begin);

            if (f.Length != newDataStream.Length) return false;

            const int CHUNK_SIZE = 1024;
            byte[] buffer = new byte[CHUNK_SIZE];
            byte[] buffer2 = new byte[CHUNK_SIZE];
            int lastRead1;
            while ((lastRead1 = f.Read(buffer, 0, buffer.Length)) > 0)
            {
                int lastRead2 = newDataStream.Read(buffer2, 0, buffer2.Length);
                if (lastRead1 != lastRead2) return false;
                if (!buffer.SequenceEqual(buffer2)) return false;
            }

            return true;
        }

        public IReadOnlyList<FString> GetNameMapIndexList()
        {
            return nameMapIndexList.AsReadOnly();
        }

        public void ClearNameIndexList()
        {
            nameMapIndexList = new List<FString>();
            nameMapLookup = new Dictionary<int, int>();
        }

        public void SetNameReference(int index, FString value)
        {
            nameMapIndexList[index] = value;
            nameMapLookup[value.GetHashCode()] = index;
        }

        public FString GetNameReference(int index)
        {
            if (index < 0) return new FString(Convert.ToString(-index));
            if (index > nameMapIndexList.Count) return new FString(Convert.ToString(index));
            return nameMapIndexList[index];
        }

        public FString GetNameReferenceWithoutZero(int index)
        {
            if (index <= 0) return new FString(Convert.ToString(-index));
            if (index > nameMapIndexList.Count) return new FString(Convert.ToString(index));
            return nameMapIndexList[index];
        }

        public bool NameReferenceContains(FString search)
        {
            return nameMapLookup.ContainsKey(search.GetHashCode());
        }

        public int SearchNameReference(FString search)
        {
            if (NameReferenceContains(search)) return nameMapLookup[search.GetHashCode()];
            throw new NameMapOutOfRangeException(search);
        }

        public int AddNameReference(FString name, bool forceAddDuplicates = false)
        {
            if (!forceAddDuplicates && NameReferenceContains(name)) return SearchNameReference(name);
            nameMapIndexList.Add(name);
            nameMapLookup[name.GetHashCode()] = nameMapIndexList.Count - 1;
            return nameMapIndexList.Count - 1;
        }

        public FName GetImportObjectName(int index)
        {
            return index < 0 ? GetImportAt(index).ObjectName : new FName(Convert.ToString(index));
        }

        public Import GetImportAt(int index)
        {
            int normalIndex = UAPUtils.GetNormalIndex(index);
            if (normalIndex < 0 || normalIndex >= Imports.Count) return null;
            return Imports[normalIndex];
        }

        public Import AddImport(string bbase, string bclass, int link, string property)
        {
            Import nuevo = new Import(bbase, bclass, link, property, UAPUtils.GetImportIndex(Imports.Count));
            Imports.Add(nuevo);
            return nuevo;
        }

        public int AddLink(Import li)
        {
            li.Index = UAPUtils.GetImportIndex(Imports.Count);
            Imports.Add(li);
            return li.Index;
        }

        public ClassExport GetClassExport()
        {
            foreach (Export cat in Exports)
            {
                if (cat is ClassExport bgcCat) return bgcCat;
            }
            return null;
        }
        
        public FName GetClassExportName()
        {
            var classExport = GetClassExport();
            if (classExport == null || classExport.ReferenceData == null) return null;

            return classExport.ReferenceData.ObjectName;
        }

        public void GetParentClass(out FName parentClassPath, out FName parentClassExportName)
        {
            parentClassPath = null;
            parentClassExportName = null;

            var bgcCat = GetClassExport();
            if (bgcCat == null) return;

            Import parentClassLink = GetImportAt(bgcCat.SuperStruct);
            if (parentClassLink == null) return;
            if (parentClassLink.OuterIndex >= 0) return;

            parentClassExportName = parentClassLink.ObjectName;
            parentClassPath = GetImportAt((int)parentClassLink.OuterIndex).ObjectName;
        }

        public int GetCustomVersion(Guid key)
        {
            for (int i = 0; i < CustomVersionContainer.Count; i++)
            {
                CustomVersion custVer = CustomVersionContainer[i];
                if (custVer.Key == key)
                {
                    return custVer.Version;
                }
            }

            return -1; // https://github.com/EpicGames/UnrealEngine/blob/99b6e203a15d04fc7bbbf554c421a985c1ccb8f1/Engine/Source/Runtime/Core/Private/Serialization/Archive.cpp#L578
        }

        public int GetCustomVersion(string friendlyName)
        {
            for (int i = 0; i < CustomVersionContainer.Count; i++)
            {
                CustomVersion custVer = CustomVersionContainer[i];
                if (custVer.FriendlyName == friendlyName)
                {
                    return custVer.Version;
                }
            }

            return -1;
        }

        public T GetCustomVersion<T>()
        {
            Type customVersionEnumType = typeof(T);
            if (!customVersionEnumType.IsEnum) throw new ArgumentException("T must be an enumerated type");

            for (int i = 0; i < CustomVersionContainer.Count; i++)
            {
                CustomVersion custVer = CustomVersionContainer[i];
                if (custVer.FriendlyName == customVersionEnumType.Name)
                {
                    return (T)(object)custVer.Version;
                }
            }

            // Try and guess the custom version based off the engine version
            T[] allVals = (T[])Enum.GetValues(customVersionEnumType);
            for (int i = allVals.Length - 1; i >= 0; i--)
            {
                T val = allVals[i];
                var attributes = customVersionEnumType.GetMember(val.ToString())[0].GetCustomAttributes(typeof(IntroducedAttribute), false);
                if (attributes.Length <= 0) continue;
                if (EngineVersion >= ((IntroducedAttribute)attributes[0]).IntroducedVersion) return val;
            }

            return (T)(object)-1;
        }

        public int SearchForLink(FName classPackage, FName className, int outerIndex, FName objectName)
        {
            int currentPos = 0;
            for (int i = 0; i < Imports.Count; i++)
            {
                currentPos--;
                if (classPackage == Imports[i].ClassPackage
                    && className == Imports[i].ClassName
                    && outerIndex == Imports[i].OuterIndex
                    && objectName == Imports[i].ObjectName)
                {
                    return currentPos;
                }

            }

            return 0;
        }

        public int SearchForLink(FName classPackage, FName className, FName objectName)
        {
            int currentPos = 0;
            for (int i = 0; i < Imports.Count; i++)
            {
                currentPos--;
                if (classPackage == Imports[i].ClassPackage
                    && className == Imports[i].ClassName
                    && objectName == Imports[i].ObjectName)
                {
                    return currentPos;
                }

            }

            return 0;
        }

        public int SearchForLink(FName objectName)
        {
            int currentPos = 0;
            for (int i = 0; i < Imports.Count; i++)
            {
                currentPos--;
                if (objectName == Imports[i].ObjectName) return currentPos;
            }

            return 0;
        }

        /**
         * The package file version number when this package was saved.
         *
         * Lower 16 bits stores the UE3 engine version
         * Upper 16 bits stores the UE4/licensee version
         * For newer packages this is -7
         *		-2 indicates presence of enum-based custom versions
         *		-3 indicates guid-based custom versions
         *		-4 indicates removal of the UE3 version. Packages saved with this ID cannot be loaded in older engine versions
         *		-5 indicates the replacement of writing out the "UE3 version" so older versions of engine can gracefully fail to open newer packages
         *		-6 indicates optimizations to how custom versions are being serialized
         *		-7 indicates the texture allocation info has been removed from the summary
         */
        public int LegacyFileVersion;

        /**
         * Should this asset not serialize its engine and custom versions?
         */
        public bool IsUnversioned;

        /**
         * The licensee file version. Used by some games to add their own Engine-level versioning.
         */
        public int FileVersionLicenseeUE4;

        /**
         * All the custom versions stored in the archive.
         */
        public List<CustomVersion> CustomVersionContainer = null;

        /**
         * List of object imports. UAssetAPI used to call these "links."
         */
        public List<Import> Imports;

        /**
         * List of object exports. UAssetAPI used to call these "categories."
         */
        public List<Export> Exports;

        /**
         * List of dependency lists for each export.
         */
        public List<int[]> DependsMap;

        /**
         * List of packages that are soft referenced by this package.
         */
        public List<string> SoftPackageReferenceList;

        /**
         * Uncertain
         */
        public List<int> AssetRegistryData;

        /**
         * Tile information used by WorldComposition.
         * Defines properties necessary for tile positioning in the world.
         */
        public FWorldTileInfo WorldTileInfo;

        /**
	     * List of imports and exports that must be serialized before other exports...all packed together, see FirstExportDependency.
	     */
        public List<int> PreloadDependencies;

        /**
	     * Data about previous versions of this package.
	     */
        public List<FGenerationInfo> Generations;

        /**
	     * Current ID for this package. Effectively unused.
	     */
        public Guid PackageGuid;

        /**
	     * Engine version this package was saved with. This may differ from CompatibleWithEngineVersion for assets saved with a hotfix release.
	     */
        public FEngineVersion RecordedEngineVersion;

        /**
	     * Engine version this package is compatible with. Assets saved by Hotfix releases and engine versions that maintain binary compatibility will have
	     * a CompatibleWithEngineVersion.Patch that matches the original release (as opposed to SavedByEngineVersion which will have a patch version of the new release).
	     */
        public FEngineVersion RecordedCompatibleWithEngineVersion;

        /**
         * Streaming install ChunkIDs
         */
        public int[] ChunkIDs;

        /**
         * The flags for this package.
         */
        public EPackageFlags PackageFlags;

        /**
         * Value that is used to determine if the package was saved by Epic, a licensee, modder, etc.
         */
        public uint PackageSource;

        /**
         * The Generic Browser folder name that this package lives in. Usually "None" in cooked assets.
         */
        public FString FolderName;

        /**
         * In MapProperties that have StructProperties as their keys or values, there is no deterministic, universal, context-free way to determine the type of the struct. To that end, this dictionary maps MapProperty names to the type of the structs within them (tuple of key struct type and value struct type) if they are not None-terminated property lists
         */
        public Dictionary<string, Tuple<FName, FName>> MapStructTypeOverride = new Dictionary<string, Tuple<FName, FName>>()
        {
            { "ColorDatabase", new Tuple<FName, FName>(null, new FName("LinearColor")) },
            { "PlayerCharacterIDs", new Tuple<FName, FName>(new FName("Guid"), null) }
        };

        /**
         * External programs often leave name map hashes blank, so in this map we preserve those changes to avoid confusion.
         */
        public Dictionary<FString, uint> OverrideGuids;

        /* This is called "TotalHeaderSize" in UE4 where header refers to the whole summary, whereas in UAssetAPI header refers to just the data before the start of the name map */
        internal int SectionSixOffset = 0;

        /* Number of names used in this package */
        internal int NameCount = 0;

        /* Location into the file on disk for the name data */
        internal int NameOffset;

        /* Number of gatherable text data items in this package */
        internal int GatherableTextDataCount;

        /* Location into the file on disk for the gatherable text data items */
        internal int GatherableTextDataOffset;

        /* Number of exports contained in this package */
        internal int ExportCount = 0;

        /* Location into the file on disk for the "Export Details" data */
        internal int ExportOffset = 0;

        /* Number of imports contained in this package */
        internal int ImportCount = 0;

        /* Location into the file on disk for the ImportMap data */
        internal int ImportOffset = 0;

        /* Location into the file on disk for the DependsMap data */
        internal int DependsOffset = 0;

        /* Number of soft package references contained in this package */
        internal int SoftPackageReferencesCount = 0;

        /* Location into the file on disk for the soft package reference list */
        internal int SoftPackageReferencesOffset = 0;

        /* Location into the file on disk for the SearchableNamesMap data */
        internal int SearchableNamesOffset;

        /* Thumbnail table offset */
        internal int ThumbnailTableOffset;

        /* Should be zero */
        internal uint CompressionFlags;

        /* Location into the file on disk for the asset registry tag data */
        internal int AssetRegistryDataOffset;

        /* Offset to the location in the file where the bulkdata starts */
        internal long BulkDataStartOffset;

        /* Offset to the location in the file where the FWorldTileInfo data start */
        internal int WorldTileInfoDataOffset;

        /* Number of preload dependencies contained in this package */
        internal int PreloadDependencyCount;

        /* Location into the file on disk for the preload dependency data */
        internal int PreloadDependencyOffset;

        internal bool doWeHaveDependsMap = true;
        internal bool doWeHaveSoftPackageReferences = true;
        internal bool doWeHaveAssetRegistryData = true;
        internal bool doWeHaveWorldTileInfo = true;

        // Do not directly add values to here under any circumstances; use AddNameReference instead
        private List<FString> nameMapIndexList;
        private Dictionary<int, int> nameMapLookup = new Dictionary<int, int>();

        private void Assert(bool v)
        {
            if (!v) throw new FormatException("Failed assertion while reading asset summary");
        }

        public static uint UASSET_MAGIC = 2653586369;
        private void ReadHeader(BinaryReader reader)
        {
            reader.BaseStream.Seek(0, SeekOrigin.Begin);
            if (reader.ReadUInt32() != UASSET_MAGIC) throw new FormatException("File signature mismatch");

            LegacyFileVersion = reader.ReadInt32();
            if (LegacyFileVersion != -4)
            {
                reader.ReadInt32(); // LegacyUE3Version for backwards-compatibility with UE3 games: always 864 in versioned assets, always 0 in unversioned assets
            }

            UE4Version fileVersionUE4 = (UE4Version)reader.ReadInt32();
            if (fileVersionUE4 > UE4Version.UNKNOWN)
            {
                IsUnversioned = false;
                EngineVersion = fileVersionUE4;
            }
            else
            {
                IsUnversioned = true;
                if (EngineVersion == UE4Version.UNKNOWN) throw new UnknownEngineVersionException("Cannot begin serialization of an unversioned asset before an engine version is manually specified");
            }

            FileVersionLicenseeUE4 = reader.ReadInt32();

            // Custom versions container
            int numCustomVersions = 0;
            if (LegacyFileVersion <= -2)
            {
                // TODO: support for enum-based custom versions
                if (CustomVersionContainer == null) CustomVersionContainer = new List<CustomVersion>();

                numCustomVersions = reader.ReadInt32();
                for (int i = 0; i < numCustomVersions; i++)
                {
                    var customVersionID = new Guid(reader.ReadBytes(16));
                    var customVersionNumber = reader.ReadInt32();
                    CustomVersionContainer.Add(new CustomVersion(customVersionID, customVersionNumber));
                }
            }

            SectionSixOffset = reader.ReadInt32(); // 24
            FolderName = reader.ReadFStringWithEncoding();
            PackageFlags = (EPackageFlags)reader.ReadUInt32();
            NameCount = reader.ReadInt32();
            NameOffset = reader.ReadInt32();
            if (EngineVersion >= UE4Version.VER_UE4_SERIALIZE_TEXT_IN_PACKAGES)
            {
                GatherableTextDataCount = reader.ReadInt32();
                GatherableTextDataOffset = reader.ReadInt32();
            }

            ExportCount = reader.ReadInt32();
            ExportOffset = reader.ReadInt32(); // 61
            ImportCount = reader.ReadInt32(); // 65
            ImportOffset = reader.ReadInt32(); // 69 (haha funny)
            DependsOffset = reader.ReadInt32(); // 73
            if (EngineVersion >= UE4Version.VER_UE4_ADD_STRING_ASSET_REFERENCES_MAP)
            {
                SoftPackageReferencesCount = reader.ReadInt32(); // 77
                SoftPackageReferencesOffset = reader.ReadInt32(); // 81
            }
            if (EngineVersion >= UE4Version.VER_UE4_ADDED_SEARCHABLE_NAMES)
            {
                SearchableNamesOffset = reader.ReadInt32();
            }
            ThumbnailTableOffset = reader.ReadInt32();

            PackageGuid = new Guid(reader.ReadBytes(16));

            Generations = new List<FGenerationInfo>();
            int generationCount = reader.ReadInt32();
            for (int i = 0; i < generationCount; i++)
            {
                int genNumExports = reader.ReadInt32();
                int genNumNames = reader.ReadInt32();
                Generations.Add(new FGenerationInfo(genNumExports, genNumNames));
            }

            if (EngineVersion >= UE4Version.VER_UE4_ENGINE_VERSION_OBJECT)
            {
                RecordedEngineVersion = new FEngineVersion(reader);
            }
            else
            {
                RecordedEngineVersion = new FEngineVersion(4, 0, 0, reader.ReadUInt32(), new FString(""));
            }

            if (EngineVersion >= UE4Version.VER_UE4_PACKAGE_SUMMARY_HAS_COMPATIBLE_ENGINE_VERSION)
            {
                RecordedCompatibleWithEngineVersion = new FEngineVersion(reader);
            }
            else
            {
                RecordedCompatibleWithEngineVersion = RecordedEngineVersion;
            }

            CompressionFlags = reader.ReadUInt32();
            int numCompressedChunks = reader.ReadInt32();
            if (numCompressedChunks > 0) throw new FormatException("Asset has package-level compression and is likely too old to be parsed");

            PackageSource = reader.ReadUInt32();

            int numAdditionalPackagesToCook = reader.ReadInt32(); // unused
            if (numAdditionalPackagesToCook > 0) throw new FormatException("Asset has AdditionalPackagesToCook and is likely too old to be parsed");

            if (LegacyFileVersion > -7)
            {
                int numTextureAllocations = reader.ReadInt32(); // unused
                if (numTextureAllocations > 0) throw new FormatException("Asset has texture allocation info and is likely too old to be parsed");
            }

            AssetRegistryDataOffset = reader.ReadInt32();
            BulkDataStartOffset = reader.ReadInt64();

            if (EngineVersion >= UE4Version.VER_UE4_WORLD_LEVEL_INFO)
            {
                WorldTileInfoDataOffset = reader.ReadInt32();
            }

            if (EngineVersion >= UE4Version.VER_UE4_CHANGED_CHUNKID_TO_BE_AN_ARRAY_OF_CHUNKIDS)
            {
                int numChunkIDs = reader.ReadInt32();
                ChunkIDs = new int[numChunkIDs];
                for (int i = 0; i < numChunkIDs; i++)
                {
                    ChunkIDs[i] = reader.ReadInt32();
                }
            }
            else if (EngineVersion >= UE4Version.VER_UE4_ADDED_CHUNKID_TO_ASSETDATA_AND_UPACKAGE)
            {
                ChunkIDs = new int[1];
                ChunkIDs[0] = reader.ReadInt32();
            }

            if (EngineVersion >= UE4Version.VER_UE4_PRELOAD_DEPENDENCIES_IN_COOKED_EXPORTS)
            {
                PreloadDependencyCount = reader.ReadInt32();
                PreloadDependencyOffset = reader.ReadInt32();
            }
        }

        public void Read(BinaryReader reader, int[] manualSkips = null, int[] forceReads = null)
        {
            // Header
            ReadHeader(reader);

            // Name map
            reader.BaseStream.Seek(NameOffset, SeekOrigin.Begin);

            OverrideGuids = new Dictionary<FString, uint>();
            ClearNameIndexList();
            for (int i = 0; i < NameCount; i++)
            {
                var str = reader.ReadFStringWithGUIDAndEncoding(out uint guid);
                if (guid == 0) OverrideGuids.Add(str, 0);
                AddNameReference(str, true);
            }

            // Imports
            Imports = new List<Import>();
            if (ImportOffset > 0)
            {
                reader.BaseStream.Seek(ImportOffset, SeekOrigin.Begin);
                for (int i = 0; i < ImportCount; i++)
                {
                    Imports.Add(new Import(reader.ReadFName(this), reader.ReadFName(this), reader.ReadInt32(), reader.ReadFName(this), UAPUtils.GetImportIndex(i)));
                }
            }

            // Export details
            Exports = new List<Export>();
            if (ExportOffset > 0)
            {
                reader.BaseStream.Seek(ExportOffset, SeekOrigin.Begin);
                for (int i = 0; i < ExportCount; i++)
                {
                    var newRef = new ExportDetails();
                    newRef.ClassIndex = reader.ReadInt32();
                    newRef.SuperIndex = reader.ReadInt32();
                    if (EngineVersion >= UE4Version.VER_UE4_TemplateIndex_IN_COOKED_EXPORTS)
                    {
                        newRef.TemplateIndex = reader.ReadInt32();
                    }
                    newRef.OuterIndex = reader.ReadInt32();
                    newRef.ObjectName = reader.ReadFName(this);
                    newRef.ObjectFlags = (EObjectFlags)reader.ReadUInt32();
                    if (EngineVersion < UE4Version.VER_UE4_64BIT_EXPORTMAP_SERIALSIZES)
                    {
                        newRef.SerialSize = reader.ReadInt32();
                        newRef.SerialOffset = reader.ReadInt32();
                    }
                    else
                    {
                        newRef.SerialSize = reader.ReadInt64();
                        newRef.SerialOffset = reader.ReadInt64();
                    }
                    newRef.bForcedExport = reader.ReadInt32() == 1;
                    newRef.bNotForClient = reader.ReadInt32() == 1;
                    newRef.bNotForServer = reader.ReadInt32() == 1;
                    newRef.PackageGuid = new Guid(reader.ReadBytes(16));
                    newRef.PackageFlags = (EPackageFlags)reader.ReadUInt32();
                    if (EngineVersion >= UE4Version.VER_UE4_LOAD_FOR_EDITOR_GAME)
                    {
                        newRef.bNotAlwaysLoadedForEditorGame = reader.ReadInt32() == 1;
                    }
                    if (EngineVersion >= UE4Version.VER_UE4_COOKED_ASSETS_IN_EDITOR_SUPPORT)
                    {
                        newRef.bIsAsset = reader.ReadInt32() == 1;
                    }
                    if (EngineVersion >= UE4Version.VER_UE4_PRELOAD_DEPENDENCIES_IN_COOKED_EXPORTS)
                    {
                        newRef.FirstExportDependency = reader.ReadInt32();
                        newRef.SerializationBeforeSerializationDependencies = reader.ReadInt32();
                        newRef.CreateBeforeSerializationDependencies = reader.ReadInt32();
                        newRef.SerializationBeforeCreateDependencies = reader.ReadInt32();
                        newRef.CreateBeforeCreateDependencies = reader.ReadInt32();
                    }

                    Exports.Add(new Export(newRef, this, new byte[0]));
                }
            }

            // DependsMap
            DependsMap = new List<int[]>();
            if (DependsOffset > 0)
            {
                reader.BaseStream.Seek(DependsOffset, SeekOrigin.Begin);
                for (int i = 0; i < ExportCount; i++)
                {
                    int size = reader.ReadInt32();
                    int[] data = new int[size];
                    for (int j = 0; j < size; j++)
                    {
                        data[j] = reader.ReadInt32();
                    }
                    DependsMap.Add(data);
                }
            }
            else
            {
                doWeHaveDependsMap = false;
            }

            // SoftPackageReferenceList
            SoftPackageReferenceList = new List<string>();
            if (SoftPackageReferencesOffset > 0)
            {
                reader.BaseStream.Seek(SoftPackageReferencesOffset, SeekOrigin.Begin);
                for (int i = 0; i < SoftPackageReferencesCount; i++)
                {
                    SoftPackageReferenceList.Add(reader.ReadFString());
                }
            }
            else
            {
                doWeHaveSoftPackageReferences = false;
            }

            // AssetRegistryData
            AssetRegistryData = new List<int>();
            if (AssetRegistryDataOffset > 0)
            {
                reader.BaseStream.Seek(AssetRegistryDataOffset, SeekOrigin.Begin);
                int numAssets = reader.ReadInt32();
#pragma warning disable CS0162 // Unreachable code detected
                for (int i = 0; i < numAssets; i++)
                {
                    throw new NotImplementedException("Asset registry data is not yet supported. Please let me know if you see this error message");
                }
#pragma warning restore CS0162 // Unreachable code detected
            }
            else
            {
                doWeHaveAssetRegistryData = false;
            }

            // WorldTileInfoDataOffset
            WorldTileInfo = null;
            if (WorldTileInfoDataOffset > 0)
            {
                reader.BaseStream.Seek(WorldTileInfoDataOffset, SeekOrigin.Begin);
                WorldTileInfo = new FWorldTileInfo();
                WorldTileInfo.Read(reader, this);
            }
            else
            {
                doWeHaveWorldTileInfo = false;
            }

            // PreloadDependencies
            if (this.UseSeparateBulkDataFiles)
            {
                reader.BaseStream.Seek(PreloadDependencyOffset, SeekOrigin.Begin);
                PreloadDependencies = new List<int>();
                for (int i = 0; i < PreloadDependencyCount; i++)
                {
                    PreloadDependencies.Add(reader.ReadInt32());
                }
            }

            // Export data
            if (SectionSixOffset > 0 && Exports.Count > 0)
            {
                for (int i = 0; i < Exports.Count; i++)
                {
                    ExportDetails refData = Exports[i].ReferenceData;
                    reader.BaseStream.Seek(refData.SerialOffset, SeekOrigin.Begin);
                    if (manualSkips != null && manualSkips.Contains(i))
                    {
                        if (forceReads == null || !forceReads.Contains(i))
                        {
                            Exports[i] = new RawExport(Exports[i]);
                            ((RawExport)Exports[i]).Data = reader.ReadBytes((int)refData.SerialSize);
                            continue;
                        }
                    }

                    //Debug.WriteLine(refData.type + " " + GetNameReference(GetImportObjectName(refData.connection)));
                    try
                    {
                        long nextStarting = reader.BaseStream.Length - 4;
                        if ((Exports.Count - 1) > i) nextStarting = Exports[i + 1].ReferenceData.SerialOffset;

                        switch (GetImportObjectName(refData.ClassIndex).Value.Value)
                        {
                            case "BlueprintGeneratedClass":
                            case "WidgetBlueprintGeneratedClass":
                            case "AnimBlueprintGeneratedClass":
                                Exports[i] = new ClassExport(Exports[i]);
                                Exports[i].Read(reader, (int)nextStarting);
                                break;
                            case "Level":
                                Exports[i] = new LevelExport(Exports[i]);
                                Exports[i].Read(reader, (int)nextStarting);
                                break;
                            case "StringTable":
                                Exports[i] = new StringTableExport(Exports[i]);
                                Exports[i].Read(reader, (int)nextStarting);
                                break;
                            case "DataTable":
                                Exports[i] = new DataTableExport(Exports[i]);
                                Exports[i].Read(reader, (int)nextStarting);
                                break;
                            default:
                                Exports[i] = new NormalExport(Exports[i]);
                                Exports[i].Read(reader, (int)nextStarting);
                                break;
                        }

                        long extrasLen = nextStarting - reader.BaseStream.Position;
                        if (extrasLen < 0)
                        {
                            throw new FormatException("Invalid padding at end of export " + (i + 1) + ": " + extrasLen + " bytes");
                        }
                        else
                        {
                            Exports[i].Extras = reader.ReadBytes((int)extrasLen);
                        }
                    }
                    catch (Exception ex)
                    {
#if DEBUG
                        Debug.WriteLine("\nFailed to parse export " + (i + 1) + ": " + ex.ToString());
#endif
                        reader.BaseStream.Seek(refData.SerialOffset, SeekOrigin.Begin);
                        Exports[i] = new RawExport(Exports[i]);
                        ((RawExport)Exports[i]).Data = reader.ReadBytes((int)refData.SerialSize);
                    }
                }
            }
        }

        private byte[] MakeHeader(BinaryReader reader)
        {
            reader.BaseStream.Seek(0, SeekOrigin.Begin);
            var stre = new MemoryStream(this.NameOffset);
            BinaryWriter writer = new BinaryWriter(stre);

            writer.Write(UAsset.UASSET_MAGIC);
            writer.Write(LegacyFileVersion);
            if (LegacyFileVersion != 4)
            {
                writer.Write(IsUnversioned ? 0 : 864);
            }

            if (IsUnversioned)
            {
                writer.Write(0);
            }
            else
            {
                writer.Write((int)EngineVersion);
            }

            writer.Write(FileVersionLicenseeUE4);
            if (LegacyFileVersion <= -2)
            {
                if (IsUnversioned)
                {
                    writer.Write(0);
                }
                else
                { 
                    // TODO: support for enum-based custom versions
                    writer.Write(CustomVersionContainer.Count);
                    for (int i = 0; i < CustomVersionContainer.Count; i++)
                    {
                        writer.Write(CustomVersionContainer[i].Key.ToByteArray());
                        writer.Write(CustomVersionContainer[i].Version);
                    }
                }
            }

            writer.Write(SectionSixOffset);
            writer.WriteFString(FolderName);
            writer.Write((uint)PackageFlags);
            writer.Write(NameCount);
            writer.Write(NameOffset);
            if (EngineVersion >= UE4Version.VER_UE4_SERIALIZE_TEXT_IN_PACKAGES)
            {
                writer.Write(GatherableTextDataCount);
                writer.Write(GatherableTextDataOffset);
            }
            writer.Write(ExportCount);
            writer.Write(ExportOffset); // 61
            writer.Write(ImportCount); // 65
            writer.Write(ImportOffset); // 69 (haha funny)
            writer.Write(DependsOffset); // 73
            if (EngineVersion >= UE4Version.VER_UE4_ADD_STRING_ASSET_REFERENCES_MAP)
            {
                writer.Write(SoftPackageReferencesCount); // 77
                writer.Write(SoftPackageReferencesOffset); // 81
            }
            if (EngineVersion >= UE4Version.VER_UE4_ADDED_SEARCHABLE_NAMES)
            {
                writer.Write(SearchableNamesOffset);
            }
            writer.Write(ThumbnailTableOffset);

            writer.Write(PackageGuid.ToByteArray());
            writer.Write(Generations.Count);
            for (int i = 0; i < Generations.Count; i++)
            {
                Generations[i].ExportCount = ExportCount;
                Generations[i].NameCount = NameCount;
                writer.Write(Generations[i].ExportCount);
                writer.Write(Generations[i].NameCount);
            }

            if (EngineVersion >= UE4Version.VER_UE4_ENGINE_VERSION_OBJECT)
            {
                RecordedEngineVersion.Write(writer);
            }
            else
            {
                writer.Write(RecordedEngineVersion.Changelist);
            }

            if (EngineVersion >= UE4Version.VER_UE4_PACKAGE_SUMMARY_HAS_COMPATIBLE_ENGINE_VERSION)
            {
                RecordedCompatibleWithEngineVersion.Write(writer);
            }

            writer.Write(CompressionFlags);
            writer.Write((int)0); // numCompressedChunks
            writer.Write(PackageSource);
            writer.Write((int)0); // numAdditionalPackagesToCook

            if (LegacyFileVersion > -7)
            {
                writer.Write((int)0); // numTextureAllocations
            }

            writer.Write(AssetRegistryDataOffset);
            writer.Write(BulkDataStartOffset);

            if (EngineVersion >= UE4Version.VER_UE4_WORLD_LEVEL_INFO)
            {
                writer.Write(WorldTileInfoDataOffset);
            }

            if (EngineVersion >= UE4Version.VER_UE4_CHANGED_CHUNKID_TO_BE_AN_ARRAY_OF_CHUNKIDS)
            {
                writer.Write(ChunkIDs.Length);
                for (int i = 0; i < ChunkIDs.Length; i++)
                {
                    writer.Write(ChunkIDs[i]);
                }
            }
            else if (EngineVersion >= UE4Version.VER_UE4_ADDED_CHUNKID_TO_ASSETDATA_AND_UPACKAGE)
            {
                writer.Write(ChunkIDs[0]);
            }

            if (EngineVersion >= UE4Version.VER_UE4_PRELOAD_DEPENDENCIES_IN_COOKED_EXPORTS)
            {
                writer.Write(PreloadDependencyCount);
                writer.Write(PreloadDependencyOffset);
            }

            return stre.ToArray();
        }

        public MemoryStream WriteData(BinaryReader reader)
        {
            var stre = new MemoryStream();
            BinaryWriter writer = new BinaryWriter(stre);

            // Header
            writer.Seek(0, SeekOrigin.Begin);
            writer.Write(MakeHeader(reader));

            // Name map
            this.NameOffset = (int)writer.BaseStream.Position;
            this.NameCount = this.nameMapIndexList.Count;
            for (int i = 0; i < this.nameMapIndexList.Count; i++)
            {
                writer.WriteFString(nameMapIndexList[i]);
                if (OverrideGuids.ContainsKey(nameMapIndexList[i]))
                {
                    writer.Write(OverrideGuids[nameMapIndexList[i]]);
                }
                else
                {
                    writer.Write(CRCGenerator.GenerateHash(nameMapIndexList[i]));
                }
            }

            // Imports
            if (this.Imports.Count > 0)
            {
                this.ImportOffset = (int)writer.BaseStream.Position;
                this.ImportCount = this.Imports.Count;
                int newIndex = 0;
                for (int i = 0; i < this.Imports.Count; i++)
                {
                    //Debug.WriteLine("l " + writer.BaseStream.Position);
                    writer.WriteFName(this.Imports[i].ClassPackage, this);
                    writer.WriteFName(this.Imports[i].ClassName, this);
                    writer.Write(this.Imports[i].OuterIndex);
                    writer.WriteFName(this.Imports[i].ObjectName, this);
                    this.Imports[i].Index = --newIndex;
                }
            }
            else
            {
                this.ImportOffset = 0;
            }

            // Export details
            if (this.Exports.Count > 0)
            {
                this.ExportOffset = (int)writer.BaseStream.Position;
                this.ExportCount = this.Exports.Count;
                for (int i = 0; i < this.Exports.Count; i++)
                {
                    ExportDetails us = this.Exports[i].ReferenceData;
                    //Debug.WriteLine("d " + writer.BaseStream.Position);
                    writer.Write(us.ClassIndex);
                    writer.Write(us.SuperIndex);
                    if (EngineVersion >= UE4Version.VER_UE4_TemplateIndex_IN_COOKED_EXPORTS)
                    {
                        writer.Write(us.TemplateIndex);
                    }
                    writer.Write(us.OuterIndex);
                    writer.WriteFName(us.ObjectName, this);
                    writer.Write((uint)us.ObjectFlags);
                    if (EngineVersion < UE4Version.VER_UE4_64BIT_EXPORTMAP_SERIALSIZES)
                    {
                        writer.Write((int)us.SerialSize);
                        writer.Write((int)us.SerialOffset);
                    }
                    else
                    {
                        writer.Write(us.SerialSize);
                        writer.Write(us.SerialOffset);
                    }
                    writer.Write(us.bForcedExport ? 1 : 0);
                    writer.Write(us.bNotForClient ? 1 : 0);
                    writer.Write(us.bNotForServer ? 1 : 0);
                    writer.Write(us.PackageGuid.ToByteArray());
                    writer.Write((uint)us.PackageFlags);
                    if (EngineVersion >= UE4Version.VER_UE4_LOAD_FOR_EDITOR_GAME)
                    {
                        writer.Write(us.bNotAlwaysLoadedForEditorGame ? 1 : 0);
                    }
                    if (EngineVersion >= UE4Version.VER_UE4_COOKED_ASSETS_IN_EDITOR_SUPPORT)
                    {
                        writer.Write(us.bIsAsset ? 1 : 0);
                    }
                    if (EngineVersion >= UE4Version.VER_UE4_PRELOAD_DEPENDENCIES_IN_COOKED_EXPORTS)
                    {
                        writer.Write(us.FirstExportDependency);
                        writer.Write(us.SerializationBeforeSerializationDependencies);
                        writer.Write(us.CreateBeforeSerializationDependencies);
                        writer.Write(us.SerializationBeforeCreateDependencies);
                        writer.Write(us.CreateBeforeCreateDependencies);
                    }
                }
            }
            else
            {
                this.ExportOffset = 0;
            }

            // DependsMap
            if (this.doWeHaveDependsMap)
            {
                this.DependsOffset = (int)writer.BaseStream.Position;
                for (int i = 0; i < this.Exports.Count; i++)
                {
                    if (i >= this.DependsMap.Count) this.DependsMap.Add(new int[0]);

                    int[] currentData = this.DependsMap[i];
                    writer.Write(currentData.Length);
                    for (int j = 0; j < currentData.Length; j++)
                    {
                        writer.Write(currentData[j]);
                    }
                }
            }
            else
            {
                this.DependsOffset = 0;
            }

            // SoftPackageReferenceList
            if (this.doWeHaveSoftPackageReferences)
            {
                this.SoftPackageReferencesOffset = (int)writer.BaseStream.Position;
                this.SoftPackageReferencesCount = this.SoftPackageReferenceList.Count;
                for (int i = 0; i < this.SoftPackageReferenceList.Count; i++)
                {
                    writer.WriteFString(this.SoftPackageReferenceList[i]);
                }
            }
            else
            {
                this.SoftPackageReferencesOffset = 0;
            }

            // AssetRegistryData
            if (this.doWeHaveAssetRegistryData)
            {
                this.AssetRegistryDataOffset = (int)writer.BaseStream.Position;
                writer.Write(this.AssetRegistryData.Count);
#pragma warning disable CS0162 // Unreachable code detected
                for (int i = 0; i < this.AssetRegistryData.Count; i++)
                {
                    throw new NotImplementedException("Asset registry data is not yet supported. Please let me know if you see this error message");
                }
#pragma warning restore CS0162 // Unreachable code detected
            }
            else
            {
                this.AssetRegistryDataOffset = 0;
            }

            // WorldTileInfo
            if (this.doWeHaveWorldTileInfo)
            {
                this.WorldTileInfoDataOffset = (int)writer.BaseStream.Position;
                WorldTileInfo.Write(writer, this);
            }
            else
            {
                this.WorldTileInfoDataOffset = 0;
            }

            // PreloadDependencies
            this.PreloadDependencyOffset = (int)writer.BaseStream.Position;
            if (this.UseSeparateBulkDataFiles)
            {
                this.PreloadDependencyCount = this.PreloadDependencies.Count;
                for (int i = 0; i < this.PreloadDependencies.Count; i++)
                {
                    writer.Write(this.PreloadDependencies[i]);
                }
            }

            // Export data
            int oldOffset = this.SectionSixOffset;
            this.SectionSixOffset = (int)writer.BaseStream.Position;
            long[] categoryStarts = new long[this.Exports.Count];
            if (WillWriteExportData)
            {
                if (this.Exports.Count > 0)
                {
                    for (int i = 0; i < this.Exports.Count; i++)
                    {
                        categoryStarts[i] = writer.BaseStream.Position;
                        Export us = this.Exports[i];
                        us.Write(writer);
                        writer.Write(us.Extras);
                    }
                }
                writer.Write(new byte[] { 0xC1, 0x83, 0x2A, 0x9E });
            }
            else // Old behavior
            {
                reader.BaseStream.Seek(oldOffset, SeekOrigin.Begin);
                writer.Write(reader.ReadBytes((int)reader.BaseStream.Length - oldOffset));

                int additionalOffset = this.SectionSixOffset - oldOffset;
                for (int i = 0; i < this.Exports.Count; i++)
                {
                    ExportDetails us = this.Exports[i].ReferenceData;
                    categoryStarts[i] = us.SerialOffset + additionalOffset;
                }
            }

            this.BulkDataStartOffset = (int)stre.Length - 4;

            // Rewrite Section 3
            if (this.Exports.Count > 0)
            {
                writer.Seek(this.ExportOffset, SeekOrigin.Begin);
                for (int i = 0; i < this.Exports.Count; i++)
                {
                    ExportDetails us = this.Exports[i].ReferenceData;
                    long nextLoc = this.BulkDataStartOffset;
                    if ((this.Exports.Count - 1) > i) nextLoc = categoryStarts[i + 1];

                    us.SerialOffset = categoryStarts[i];
                    us.SerialSize = nextLoc - categoryStarts[i];

                    writer.Write(us.ClassIndex);
                    writer.Write(us.SuperIndex);
                    if (EngineVersion >= UE4Version.VER_UE4_TemplateIndex_IN_COOKED_EXPORTS)
                    {
                        writer.Write(us.TemplateIndex);
                    }
                    writer.Write(us.OuterIndex);
                    writer.WriteFName(us.ObjectName, this);
                    writer.Write((uint)us.ObjectFlags);
                    if (EngineVersion < UE4Version.VER_UE4_64BIT_EXPORTMAP_SERIALSIZES)
                    {
                        writer.Write((int)us.SerialSize);
                        writer.Write((int)us.SerialOffset);
                    }
                    else
                    {
                        writer.Write(us.SerialSize);
                        writer.Write(us.SerialOffset);
                    }
                    writer.Write(us.bForcedExport ? 1 : 0);
                    writer.Write(us.bNotForClient ? 1 : 0);
                    writer.Write(us.bNotForServer ? 1 : 0);
                    writer.Write(us.PackageGuid.ToByteArray());
                    writer.Write((uint)us.PackageFlags);
                    if (EngineVersion >= UE4Version.VER_UE4_LOAD_FOR_EDITOR_GAME)
                    {
                        writer.Write(us.bNotAlwaysLoadedForEditorGame ? 1 : 0);
                    }
                    if (EngineVersion >= UE4Version.VER_UE4_COOKED_ASSETS_IN_EDITOR_SUPPORT)
                    {
                        writer.Write(us.bIsAsset ? 1 : 0);
                    }
                    if (EngineVersion >= UE4Version.VER_UE4_PRELOAD_DEPENDENCIES_IN_COOKED_EXPORTS)
                    {
                        writer.Write(us.FirstExportDependency);
                        writer.Write(us.SerializationBeforeSerializationDependencies);
                        writer.Write(us.CreateBeforeSerializationDependencies);
                        writer.Write(us.SerializationBeforeCreateDependencies);
                        writer.Write(us.CreateBeforeCreateDependencies);
                    }
                }
            }

            /*Debug.WriteLine(this.NameOffset);
            Debug.WriteLine(this.ImportOffset);
            Debug.WriteLine(this.ExportOffset);
            Debug.WriteLine(this.DependsOffset);
            Debug.WriteLine(this.SoftPackageReferencesOffset);
            Debug.WriteLine(this.AssetRegistryDataOffset);
            Debug.WriteLine(this.PreloadDependencyOffset);*/

            // Rewrite Header
            writer.Seek(0, SeekOrigin.Begin);
            writer.Write(MakeHeader(reader));

            writer.Seek(0, SeekOrigin.Begin);
            return stre;
        }

        private static void CopySplitUp(Stream input, Stream output, int start, int leng)
        {
            input.Seek(start, SeekOrigin.Begin);
            output.Seek(0, SeekOrigin.Begin);

            byte[] buffer = new byte[32768];
            int read;
            while (leng > 0 && (read = input.Read(buffer, 0, Math.Min(buffer.Length, leng))) > 0)
            {
                output.Write(buffer, 0, read);
                leng -= read;
            }
        }

        public void Write(string outputPath)
        {
            if (EngineVersion == UE4Version.UNKNOWN) throw new UnknownEngineVersionException("Cannot begin serialization before an engine version is specified");

            MemoryStream newData;
            if (WillStoreOriginalCopyInMemory)
            {
                newData = WriteData(new BinaryReader(new MemoryStream(OriginalCopy)));
            }
            else
            {
                using (FileStream f = File.Open(FilePath, FileMode.Open, FileAccess.Read))
                {
                    f.Seek(0, SeekOrigin.Begin);
                    newData = WriteData(new BinaryReader(f));
                }
            }

            if (this.UseSeparateBulkDataFiles && this.Exports.Count > 0)
            {
                long breakingOffPoint = this.Exports[0].ReferenceData.SerialOffset;
                using (FileStream f = File.Open(outputPath, FileMode.Create, FileAccess.Write))
                {
                    CopySplitUp(newData, f, 0, (int)breakingOffPoint);
                }

                using (FileStream f = File.Open(Path.ChangeExtension(outputPath, "uexp"), FileMode.Create, FileAccess.Write))
                {
                    CopySplitUp(newData, f, (int)breakingOffPoint, (int)(newData.Length - breakingOffPoint));
                }
            }
            else
            {
                using (FileStream f = File.Open(outputPath, FileMode.Create, FileAccess.Write))
                {
                    newData.CopyTo(f);
                }
            }

        }

        public MemoryStream PathToStream(string p)
        {
            using (FileStream origStream = File.Open(p, FileMode.Open))
            {
                MemoryStream completeStream = new MemoryStream();
                origStream.CopyTo(completeStream);

                UseSeparateBulkDataFiles = false;
                try
                {
                    var targetFile = Path.ChangeExtension(p, "uexp");
                    if (File.Exists(targetFile))
                    {
                        using (FileStream newStream = File.Open(targetFile, FileMode.Open))
                        {
                            completeStream.Seek(0, SeekOrigin.End);
                            newStream.CopyTo(completeStream);
                            UseSeparateBulkDataFiles = true;
                        }
                    }
                }
                catch (FileNotFoundException) { }

                completeStream.Seek(0, SeekOrigin.Begin);
                return completeStream;
            }
        }

        public BinaryReader PathToReader(string p)
        {
            return new BinaryReader(PathToStream(p));
        }

        public UAsset(string path, UE4Version engineVersion = UE4Version.UNKNOWN, bool willStoreOriginalCopyInMemory = false, bool willWriteExportData = true)
        {
            this.FilePath = path;
            EngineVersion = engineVersion;
            WillStoreOriginalCopyInMemory = willStoreOriginalCopyInMemory;
            WillWriteExportData = willWriteExportData;

            var ourReader = PathToReader(path);
            Read(ourReader);

            if (WillStoreOriginalCopyInMemory)
            {
                ourReader.BaseStream.Seek(0, SeekOrigin.Begin);
                OriginalCopy = ourReader.ReadBytes((int)ourReader.BaseStream.Length);
            }
        }

        public UAsset(string path, UE4Version engineVersion = UE4Version.UNKNOWN, List<CustomVersion> defaultCustomVersionContainer = null, bool willStoreOriginalCopyInMemory = false, bool willWriteExportData = true)
        {
            this.FilePath = path;
            EngineVersion = engineVersion;
            CustomVersionContainer = defaultCustomVersionContainer;
            WillStoreOriginalCopyInMemory = willStoreOriginalCopyInMemory;
            WillWriteExportData = willWriteExportData;

            var ourReader = PathToReader(path);
            Read(ourReader);

            if (WillStoreOriginalCopyInMemory)
            {
                ourReader.BaseStream.Seek(0, SeekOrigin.Begin);
                OriginalCopy = ourReader.ReadBytes((int)ourReader.BaseStream.Length);
            }
        }

        public UAsset()
        {

        }

        // If willStoreOriginalCopyInMemory is true when calling the following constructors, then you must set OriginalCopy yourself
        public UAsset(UE4Version engineVersion = UE4Version.UNKNOWN, bool willStoreOriginalCopyInMemory = false, bool willWriteExportData = true)
        {
            EngineVersion = engineVersion;
            WillStoreOriginalCopyInMemory = willStoreOriginalCopyInMemory;
            WillWriteExportData = willWriteExportData;
        }

        public UAsset(UE4Version engineVersion = UE4Version.UNKNOWN, List<CustomVersion> defaultCustomVersionContainer = null, bool willStoreOriginalCopyInMemory = false, bool willWriteExportData = true)
        {
            EngineVersion = engineVersion;
            CustomVersionContainer = defaultCustomVersionContainer;
            WillStoreOriginalCopyInMemory = willStoreOriginalCopyInMemory;
            WillWriteExportData = willWriteExportData;
        }

        public UAsset(BinaryReader reader, UE4Version engineVersion = UE4Version.UNKNOWN, bool willStoreOriginalCopyInMemory = false, bool willWriteExportData = true)
        {
            EngineVersion = engineVersion;
            WillStoreOriginalCopyInMemory = willStoreOriginalCopyInMemory;
            WillWriteExportData = willWriteExportData;
            Read(reader);
        }

        public UAsset(BinaryReader reader, UE4Version engineVersion = UE4Version.UNKNOWN, List<CustomVersion> defaultCustomVersionContainer = null, bool willStoreOriginalCopyInMemory = false, bool willWriteExportData = true)
        {
            EngineVersion = engineVersion;
            CustomVersionContainer = defaultCustomVersionContainer;
            WillStoreOriginalCopyInMemory = willStoreOriginalCopyInMemory;
            WillWriteExportData = willWriteExportData;
            Read(reader);
        }
    }
}
