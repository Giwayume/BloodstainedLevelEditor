﻿using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using UAssetAPI.FieldTypes;

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

    /// <summary>
    /// Holds basic Unreal version numbers.
    /// </summary>
    public struct FEngineVersion
    {
        /// <summary>Major version number.</summary>
        public ushort Major;
        /// <summary>Minor version number.</summary>
        public ushort Minor;
        /// <summary>Patch version number.</summary>
        public ushort Patch;
        /// <summary>Changelist number. This is used by the engine to arbitrate when Major/Minor/Patch version numbers match.</summary>
        public uint Changelist;
        /// <summary>Branch name.</summary>
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

    /// <summary>
    /// Revision data for an Unreal package file.
    /// </summary>
    public class FGenerationInfo
    {
        /// <summary>Number of exports in the export map for this generation.</summary>
        public int ExportCount;
        /// <summary>Number of names in the name map for this generation.</summary>
        public int NameCount;

        public FGenerationInfo(int exportCount, int nameCount)
        {
            ExportCount = exportCount;
            NameCount = nameCount;
        }
    }

    public class UAsset
    {
        /// <summary>
        /// The path of the file on disk that this asset represents. This does not need to be specified for regular parsing.
        /// </summary>
        public string FilePath;

        /// <summary>
        /// Should the asset be split into separate .uasset, .uexp, and .ubulk files, as opposed to one single .uasset file?
        /// </summary>
        public bool UseSeparateBulkDataFiles = false;

        /// <summary>
        /// The version of the Unreal Engine that will be used to parse this asset.
        /// </summary>
        public UE4Version EngineVersion = UE4Version.UNKNOWN;

        /// <summary>
        /// Checks whether or not this asset maintains binary equality when seralized without any changes.
        /// </summary>
        /// <returns>Whether or not the asset verified parsing.</returns>
        public bool VerifyParsing()
        {
            MemoryStream f = this.PathToStream(FilePath);
            f.Seek(0, SeekOrigin.Begin);
            MemoryStream newDataStream = WriteData();
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

        /// <summary>
        /// Returns the name map as a read-only list of FStrings.
        /// </summary>
        /// <returns>The name map as a read-only list of FStrings.</returns>
        public IReadOnlyList<FString> GetNameMapIndexList()
        {
            return nameMapIndexList.AsReadOnly();
        }

        /// <summary>
        /// Clears the name map. This method should be used with extreme caution, as it may break unparsed references to the name map.
        /// </summary>
        public void ClearNameIndexList()
        {
            nameMapIndexList = new List<FString>();
            nameMapLookup = new Dictionary<int, int>();
        }

        /// <summary>
        /// Replaces a value in the name map at a particular index.
        /// </summary>
        /// <param name="index">The index to overwrite in the name map.</param>
        /// <param name="value">The value that will be replaced in the name map.</param>
        public void SetNameReference(int index, FString value)
        {
            nameMapIndexList[index] = value;
            nameMapLookup[value.GetHashCode()] = index;
        }

        /// <summary>
        /// Gets a value in the name map at a particular index.
        /// </summary>
        /// <param name="index">The index to return the value at.</param>
        /// <returns>The value at the index provided.</returns>
        public FString GetNameReference(int index)
        {
            if (index < 0) return new FString(Convert.ToString(-index));
            if (index > nameMapIndexList.Count) return new FString(Convert.ToString(index));
            return nameMapIndexList[index];
        }

        /// <summary>
        /// Gets a value in the name map at a particular index, but with the index zero being treated as if it is not valid.
        /// </summary>
        /// <param name="index">The index to return the value at.</param>
        /// <returns>The value at the index provided.</returns>
        public FString GetNameReferenceWithoutZero(int index)
        {
            if (index <= 0) return new FString(Convert.ToString(-index));
            if (index > nameMapIndexList.Count) return new FString(Convert.ToString(index));
            return nameMapIndexList[index];
        }

        /// <summary>
        /// Checks whether or not the value exists in the name map.
        /// </summary>
        /// <param name="search">The value to search the name map for.</param>
        /// <returns>true if the value appears in the name map, otherwise false.</returns>
        public bool NameReferenceContains(FString search)
        {
            return nameMapLookup.ContainsKey(search.GetHashCode());
        }

        /// <summary>
        /// Searches the name map for a particular value.
        /// </summary>
        /// <param name="search">The value to search the name map for.</param>
        /// <returns>The index at which the value appears in the name map.</returns>
        /// <exception cref="UAssetAPI.NameMapOutOfRangeException">Thrown when the value provided does not appear in the name map.</exception>
        public int SearchNameReference(FString search)
        {
            if (NameReferenceContains(search)) return nameMapLookup[search.GetHashCode()];
            throw new NameMapOutOfRangeException(search);
        }

        /// <summary>
        /// Adds a new value to the name map.
        /// </summary>
        /// <param name="name">The value to add to the name map.</param>
        /// <param name="forceAddDuplicates">Whether or not to add a new entry if the value provided already exists in the name map.</param>
        /// <returns>The index of the new value in the name map. If the value already existed in the name map beforehand, that index will be returned instead.</returns>
        public int AddNameReference(FString name, bool forceAddDuplicates = false)
        {
            if (!forceAddDuplicates && NameReferenceContains(name)) return SearchNameReference(name);
            nameMapIndexList.Add(name);
            nameMapLookup[name.GetHashCode()] = nameMapIndexList.Count - 1;
            return nameMapIndexList.Count - 1;
        }

        /// <summary>
        /// Adds a new import to the import map. You can also add directly to the <see cref="Imports"/> list.
        /// </summary>
        /// <param name="classPackage">The ClassPackage that the new import will have.</param>
        /// <param name="className">The ClassName that the new import will have.</param>
        /// <param name="outerIndex">The CuterIndex that the new import will have.</param>
        /// <param name="objectName">The ObjectName that the new import will have.</param>
        /// <returns>The new import that was added to the import map.</returns>
        public Import AddImport(string classPackage, string className, int outerIndex, string objectName)
        {
            Import nuevo = new Import(classPackage, className, outerIndex, objectName);
            Imports.Add(nuevo);
            return nuevo;
        }

        /// <summary>
        /// Adds a new import to the import map. You can also add directly to the <see cref="Imports"/> list.
        /// </summary>
        /// <param name="li">The new import to add to the import map.</param>
        /// <returns>The FPackageIndex corresponding to the newly-added import.</returns>
        public FPackageIndex AddImport(Import li)
        {
            Imports.Add(li);
            return FPackageIndex.FromImport(Imports.Count - 1);
        }

        /// <summary>
        /// Searches for and returns a ClassExport in this asset.
        /// </summary>
        /// <returns>A ClassExport if one exists, otherwise null.</returns>
        public ClassExport GetClassExport()
        {
            foreach (Export cat in Exports)
            {
                if (cat is ClassExport bgcCat) return bgcCat;
            }
            return null;
        }

        /// <summary>
        /// Finds the class path and export name of the SuperStruct of this asset, if it exists.
        /// </summary>
        /// <param name="parentClassPath">The class path of the SuperStruct of this asset, if it exists.</param>
        /// <param name="parentClassExportName">The export name of the SuperStruct of this asset, if it exists.</param>
        public void GetParentClass(out FName parentClassPath, out FName parentClassExportName)
        {
            parentClassPath = null;
            parentClassExportName = null;

            var bgcCat = GetClassExport();
            if (bgcCat == null) return;

            Import parentClassLink = bgcCat.SuperStruct.ToImport(this);
            if (parentClassLink == null) return;
            if (parentClassLink.OuterIndex >= 0) return;

            parentClassExportName = parentClassLink.ObjectName;
            parentClassPath = new FPackageIndex((int)parentClassLink.OuterIndex).ToImport(this).ObjectName;
        }

        /// <summary>
        /// Fetches the version of a custom version in this asset.
        /// </summary>
        /// <param name="key">The GUID of the custom version to retrieve.</param>
        /// <returns>The version of the retrieved custom version.</returns>
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

        /// <summary>
        /// Fetches the version of a custom version in this asset.
        /// </summary>
        /// <param name="friendlyName">The friendly name of the custom version to retrieve.</param>
        /// <returns>The version of the retrieved custom version.</returns>
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

        /// <summary>
        /// Fetches a custom version's enum value based off of its type.
        /// </summary>
        /// <typeparam name="T">The enum type of the custom version to retrieve.</typeparam>
        /// <returns>The enum value of the requested custom version.</returns>
        /// <exception cref="ArgumentException">Thrown when T is not an enumerated type.</exception>
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

        /// <summary>
        /// Searches for an import in the import map based off of certain parameters.
        /// </summary>
        /// <param name="classPackage">The ClassPackage that the requested import will have.</param>
        /// <param name="className">The ClassName that the requested import will have.</param>
        /// <param name="outerIndex">The CuterIndex that the requested import will have.</param>
        /// <param name="objectName">The ObjectName that the requested import will have.</param>
        /// <returns>The index of the requested import in the name map, or zero if one could not be found.</returns>
        public int SearchForImport(FName classPackage, FName className, int outerIndex, FName objectName)
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

        /// <summary>
        /// Searches for an import in the import map based off of certain parameters.
        /// </summary>
        /// <param name="classPackage">The ClassPackage that the requested import will have.</param>
        /// <param name="className">The ClassName that the requested import will have.</param>
        /// <param name="objectName">The ObjectName that the requested import will have.</param>
        /// <returns>The index of the requested import in the name map, or zero if one could not be found.</returns>
        public int SearchForImport(FName classPackage, FName className, FName objectName)
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

        /// <summary>
        /// Searches for an import in the import map based off of certain parameters.
        /// </summary>
        /// <param name="objectName">The ObjectName that the requested import will have.</param>
        /// <returns>The index of the requested import in the name map, or zero if one could not be found.</returns>
        public int SearchForImport(FName objectName)
        {
            int currentPos = 0;
            for (int i = 0; i < Imports.Count; i++)
            {
                currentPos--;
                if (objectName == Imports[i].ObjectName) return currentPos;
            }

            return 0;
        }

        /// <summary>
        /// The package file version number when this package was saved.
        /// </summary>
        /// <remarks>
        ///     The lower 16 bits stores the UE3 engine version, while the upper 16 bits stores the UE4/licensee version. For newer packages this is -7.
        ///     <list type="table">
        ///         <listheader>
        ///             <version>Version</version>
        ///             <description>Description</description>
        ///         </listheader>
        ///         <item>
        ///             <version>-2</version>
        ///             <description>indicates presence of enum-based custom versions</description>
        ///         </item>
        ///         <item>
        ///             <version>-3</version>
        ///             <description>indicates guid-based custom versions</description>
        ///         </item>
        ///         <item>
        ///             <version>-4</version>
        ///             <description>indicates removal of the UE3 version. Packages saved with this ID cannot be loaded in older engine versions</description>
        ///         </item>
        ///         <item>
        ///             <version>-5</version>
        ///             <description>indicates the replacement of writing out the "UE3 version" so older versions of engine can gracefully fail to open newer packages</description>
        ///         </item>
        ///         <item>
        ///             <version>-6</version>
        ///             <description>indicates optimizations to how custom versions are being serialized</description>
        ///         </item>
        ///         <item>
        ///             <version>-7</version>
        ///             <description>indicates the texture allocation info has been removed from the summary</description>
        ///         </item>
        ///     </list>
        /// </remarks>
        public int LegacyFileVersion;

        /// <summary>
        /// Should this asset not serialize its engine and custom versions?
        /// </summary>
        public bool IsUnversioned;

        /// <summary>
        /// The licensee file version. Used by some games to add their own Engine-level versioning.
        /// </summary>
        public int FileVersionLicenseeUE4;

        /// <summary>
        /// All the custom versions stored in the archive.
        /// </summary>
        public List<CustomVersion> CustomVersionContainer = null;

        /// <summary>
        /// Map of object imports. UAssetAPI used to call these "links."
        /// </summary>
        public List<Import> Imports;

        /// <summary>
        /// Map of object exports. UAssetAPI used to call these "categories."
        /// </summary>
        public List<Export> Exports;

        /// <summary>
        /// List of dependency lists for each export.
        /// </summary>
        public List<int[]> DependsMap;

        /// <summary>
        /// List of packages that are soft referenced by this package.
        /// </summary>
        public List<string> SoftPackageReferenceList;

        /// <summary>
        /// Uncertain
        /// </summary>
        public List<int> AssetRegistryData;

        /// <summary>
        /// Tile information used by WorldComposition.
        /// Defines properties necessary for tile positioning in the world.
        /// </summary>
        public FWorldTileInfo WorldTileInfo;

        /// <summary>
        /// List of imports and exports that must be serialized before other exports...all packed together, see <see cref="Export.FirstExportDependency"/>.
        /// </summary>
        public List<FPackageIndex> PreloadDependencies;

        /// <summary>
        /// Data about previous versions of this package.
        /// </summary>
        public List<FGenerationInfo> Generations;

        /// <summary>
        /// Current ID for this package. Effectively unused.
        /// </summary>
        public Guid PackageGuid;

        /// <summary>
        /// Engine version this package was saved with. This may differ from CompatibleWithEngineVersion for assets saved with a hotfix release.
        /// </summary>
        public FEngineVersion RecordedEngineVersion;

        /// <summary>
        /// Engine version this package is compatible with. Assets saved by Hotfix releases and engine versions that maintain binary compatibility will have
        /// a CompatibleWithEngineVersion.Patch that matches the original release (as opposed to SavedByEngineVersion which will have a patch version of the new release).
        /// </summary>
        public FEngineVersion RecordedCompatibleWithEngineVersion;

        /// <summary>
        /// Streaming install ChunkIDs
        /// </summary>
        public int[] ChunkIDs;

        /// <summary>
        /// The flags for this package.
        /// </summary>
        public EPackageFlags PackageFlags;

        /// <summary>
        /// Value that is used by the Unreal Engine to determine if the package was saved by Epic, a licensee, modder, etc.
        /// </summary>
        public uint PackageSource;

        /// <summary>
        /// The Generic Browser folder name that this package lives in. Usually "None" in cooked assets.
        /// </summary>
        public FString FolderName;

        /// <summary>
        /// In MapProperties that have StructProperties as their keys or values, there is no universal, context-free way to determine the type of the struct. To that end, this dictionary maps MapProperty names to the type of the structs within them (tuple of key struct type and value struct type) if they are not None-terminated property lists.
        /// </summary>
        public Dictionary<string, Tuple<FName, FName>> MapStructTypeOverride = new Dictionary<string, Tuple<FName, FName>>()
        {
            { "ColorDatabase", new Tuple<FName, FName>(null, new FName("LinearColor")) },
            { "PlayerCharacterIDs", new Tuple<FName, FName>(new FName("Guid"), null) }
        };

        /// <summary>
        /// External programs often improperly specify name map hashes, so in this map we can preserve those changes to avoid confusion.
        /// </summary>
        public Dictionary<FString, uint> OverrideNameMapHashes;

        /// <summary>This is called "TotalHeaderSize" in UE4 where header refers to the whole summary, whereas in UAssetAPI "header" refers to just the data before the start of the name map</summary>
        internal int SectionSixOffset = 0;

        /// <summary>Number of names used in this package</summary>
        internal int NameCount = 0;

        /// <summary>Location into the file on disk for the name data</summary>
        internal int NameOffset;

        /// <summary>Number of gatherable text data items in this package</summary>
        internal int GatherableTextDataCount;

        /// <summary>Location into the file on disk for the gatherable text data items</summary>
        internal int GatherableTextDataOffset;

        /// <summary>Number of exports contained in this package</summary>
        internal int ExportCount = 0;

        /// <summary>Location into the file on disk for the "Export Details" data</summary>
        internal int ExportOffset = 0;

        /// <summary>Number of imports contained in this package</summary>
        internal int ImportCount = 0;

        /// <summary>Location into the file on disk for the ImportMap data</summary>
        internal int ImportOffset = 0;

        /// <summary>Location into the file on disk for the DependsMap data</summary>
        internal int DependsOffset = 0;

        /// <summary>Number of soft package references contained in this package</summary>
        internal int SoftPackageReferencesCount = 0;

        /// <summary>Location into the file on disk for the soft package reference list</summary>
        internal int SoftPackageReferencesOffset = 0;

        /// <summary>Location into the file on disk for the SearchableNamesMap data</summary>
        internal int SearchableNamesOffset;

        /// <summary>Thumbnail table offset</summary>
        internal int ThumbnailTableOffset;

        /// <summary>Should be zero</summary>
        internal uint CompressionFlags;

        /// <summary>Location into the file on disk for the asset registry tag data</summary>
        internal int AssetRegistryDataOffset;

        /// <summary>Offset to the location in the file where the bulkdata starts</summary>
        internal long BulkDataStartOffset;

        /// <summary>Offset to the location in the file where the FWorldTileInfo data start</summary>
        internal int WorldTileInfoDataOffset;

        /// <summary>Number of preload dependencies contained in this package</summary>
        internal int PreloadDependencyCount;

        /// <summary>Location into the file on disk for the preload dependency data</summary>
        internal int PreloadDependencyOffset;

        internal bool doWeHaveDependsMap = true;
        internal bool doWeHaveSoftPackageReferences = true;
        internal bool doWeHaveAssetRegistryData = true;
        internal bool doWeHaveWorldTileInfo = true;

        /// <summary>
        /// Internal list of name map entries. Do not directly add values to here under any circumstances; use <see cref="AddNameReference"/> instead
        /// </summary>
        private List<FString> nameMapIndexList;

        /// <summary>
        /// Internal lookup for name map entries. Do not directly add values to here under any circumstances; use <see cref="AddNameReference"/> instead
        /// </summary>
        private Dictionary<int, int> nameMapLookup = new Dictionary<int, int>();

        /// <summary>
        /// Copies a portion of a stream to another stream.
        /// </summary>
        /// <param name="input">The input stream.</param>
        /// <param name="output">The output stream.</param>
        /// <param name="start">The offset in the input stream to start copying from.</param>
        /// <param name="leng">The length in bytes of the data to be copied.</param>
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

        /// <summary>
        /// Magic number for the .uasset format
        /// </summary>
        private static readonly uint UASSET_MAGIC = 2653586369;

        /// <summary>
        /// Reads the initial portion of the asset (everything before the name map).
        /// </summary>
        /// <param name="reader"></param>
        /// <exception cref="UnknownEngineVersionException">Thrown when this is an unversioned asset and <see cref="EngineVersion"/> is unspecified.</exception>
        /// <exception cref="FormatException">Throw when the asset cannot be parsed correctly.</exception>
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

        /// <summary>
        /// Reads an asset into memory.
        /// </summary>
        /// <param name="reader">The input reader.</param>
        /// <param name="manualSkips">An array of export indexes to skip parsing. For most applications, this should be left blank.</param>
        /// <param name="forceReads">An array of export indexes that must be read, overriding entries in the manualSkips parameter. For most applications, this should be left blank.</param>
        /// <exception cref="UnknownEngineVersionException">Thrown when this is an unversioned asset and <see cref="EngineVersion"/> is unspecified.</exception>
        /// <exception cref="FormatException">Throw when the asset cannot be parsed correctly.</exception>

        public void Read(BinaryReader reader, int[] manualSkips = null, int[] forceReads = null)
        {
            // Header
            ReadHeader(reader);

            // Name map
            reader.BaseStream.Seek(NameOffset, SeekOrigin.Begin);

            OverrideNameMapHashes = new Dictionary<FString, uint>();
            ClearNameIndexList();
            for (int i = 0; i < NameCount; i++)
            {
                FString nameInMap = reader.ReadNameMapString(out uint hashes);
                if (hashes == 0) OverrideNameMapHashes[nameInMap] = 0;
                AddNameReference(nameInMap, true);
            }

            // Imports
            Imports = new List<Import>();
            if (ImportOffset > 0)
            {
                reader.BaseStream.Seek(ImportOffset, SeekOrigin.Begin);
                for (int i = 0; i < ImportCount; i++)
                {
                    Imports.Add(new Import(reader.ReadFName(this), reader.ReadFName(this), reader.ReadInt32(), reader.ReadFName(this)));
                }
            }

            // Export details
            Exports = new List<Export>();
            if (ExportOffset > 0)
            {
                reader.BaseStream.Seek(ExportOffset, SeekOrigin.Begin);
                for (int i = 0; i < ExportCount; i++)
                {
                    var newExport = new Export(this, new byte[0]);
                    newExport.ClassIndex = new FPackageIndex(reader.ReadInt32());
                    newExport.SuperIndex = new FPackageIndex(reader.ReadInt32());
                    if (EngineVersion >= UE4Version.VER_UE4_TemplateIndex_IN_COOKED_EXPORTS)
                    {
                        newExport.TemplateIndex = new FPackageIndex(reader.ReadInt32());
                    }
                    newExport.OuterIndex = reader.ReadInt32();
                    newExport.ObjectName = reader.ReadFName(this);
                    newExport.ObjectFlags = (EObjectFlags)reader.ReadUInt32();
                    if (EngineVersion < UE4Version.VER_UE4_64BIT_EXPORTMAP_SERIALSIZES)
                    {
                        newExport.SerialSize = reader.ReadInt32();
                        newExport.SerialOffset = reader.ReadInt32();
                    }
                    else
                    {
                        newExport.SerialSize = reader.ReadInt64();
                        newExport.SerialOffset = reader.ReadInt64();
                    }
                    newExport.bForcedExport = reader.ReadInt32() == 1;
                    newExport.bNotForClient = reader.ReadInt32() == 1;
                    newExport.bNotForServer = reader.ReadInt32() == 1;
                    newExport.PackageGuid = new Guid(reader.ReadBytes(16));
                    newExport.PackageFlags = (EPackageFlags)reader.ReadUInt32();
                    if (EngineVersion >= UE4Version.VER_UE4_LOAD_FOR_EDITOR_GAME)
                    {
                        newExport.bNotAlwaysLoadedForEditorGame = reader.ReadInt32() == 1;
                    }
                    if (EngineVersion >= UE4Version.VER_UE4_COOKED_ASSETS_IN_EDITOR_SUPPORT)
                    {
                        newExport.bIsAsset = reader.ReadInt32() == 1;
                    }
                    if (EngineVersion >= UE4Version.VER_UE4_PRELOAD_DEPENDENCIES_IN_COOKED_EXPORTS)
                    {
                        newExport.FirstExportDependency = reader.ReadInt32();
                        newExport.SerializationBeforeSerializationDependencies = reader.ReadInt32();
                        newExport.CreateBeforeSerializationDependencies = reader.ReadInt32();
                        newExport.SerializationBeforeCreateDependencies = reader.ReadInt32();
                        newExport.CreateBeforeCreateDependencies = reader.ReadInt32();
                    }

                    Exports.Add(newExport);
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
                //reader.BaseStream.Seek(WorldTileInfoDataOffset, SeekOrigin.Begin);
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
                PreloadDependencies = new List<FPackageIndex>();
                for (int i = 0; i < PreloadDependencyCount; i++)
                {
                    PreloadDependencies.Add(new FPackageIndex(reader.ReadInt32()));
                }
            }

            // Export data
            if (SectionSixOffset > 0 && Exports.Count > 0)
            {
                for (int i = 0; i < Exports.Count; i++)
                {
                    reader.BaseStream.Seek(Exports[i].SerialOffset, SeekOrigin.Begin);
                    if (manualSkips != null && manualSkips.Contains(i))
                    {
                        if (forceReads == null || !forceReads.Contains(i))
                        {
                            Exports[i] = Exports[i].ConvertToChildExport<RawExport>();
                            ((RawExport)Exports[i]).Data = reader.ReadBytes((int)Exports[i].SerialSize);
                            continue;
                        }
                    }

                    try
                    {
                        long nextStarting = reader.BaseStream.Length - 4;
                        if ((Exports.Count - 1) > i) nextStarting = Exports[i + 1].SerialOffset;

                        switch (Exports[i].ClassIndex.IsImport() ? Exports[i].ClassIndex.ToImport(this).ObjectName.Value.Value : Exports[i].ClassIndex.Index.ToString())
                        {
                            case "BlueprintGeneratedClass":
                            case "WidgetBlueprintGeneratedClass":
                            case "AnimBlueprintGeneratedClass":
                                var bgc = Exports[i].ConvertToChildExport<ClassExport>();
                                Exports[i] = bgc;
                                Exports[i].Read(reader, (int)nextStarting);

                                // Check to see if we can add some new map type overrides
                                if (bgc.LoadedProperties != null)
                                {
                                    foreach (FProperty entry in bgc.LoadedProperties)
                                    {
                                        if (entry is FMapProperty fMapEntry)
                                        {
                                            FName keyOverride = null;
                                            FName valueOverride = null;
                                            if (fMapEntry.KeyProp is FStructProperty keyPropStruc && keyPropStruc.Struct.IsImport()) keyOverride = keyPropStruc.Struct.ToImport(this).ObjectName;
                                            if (fMapEntry.ValueProp is FStructProperty valuePropStruc && valuePropStruc.Struct.IsImport()) valueOverride = valuePropStruc.Struct.ToImport(this).ObjectName;

                                            this.MapStructTypeOverride.Add(fMapEntry.Name.Value.Value, new Tuple<FName, FName>(keyOverride, valueOverride));
                                        }
                                    }
                                }
                                break;
                            case "Level":
                                Exports[i] = Exports[i].ConvertToChildExport<LevelExport>();
                                Exports[i].Read(reader, (int)nextStarting);
                                break;
                            case "StringTable":
                                Exports[i] = Exports[i].ConvertToChildExport<StringTableExport>();
                                Exports[i].Read(reader, (int)nextStarting);
                                break;
                            case "DataTable":
                                Exports[i] = Exports[i].ConvertToChildExport<DataTableExport>();
                                Exports[i].Read(reader, (int)nextStarting);
                                break;
                            case "Enum":
                            case "UserDefinedEnum":
                                Exports[i] = Exports[i].ConvertToChildExport<EnumExport>();
                                Exports[i].Read(reader, (int)nextStarting);
                                break;
                            case "Function":
                                Exports[i] = Exports[i].ConvertToChildExport<FunctionExport>();
                                Exports[i].Read(reader, (int)nextStarting);
                                break;
                            default:
                                Exports[i] = Exports[i].ConvertToChildExport<NormalExport>();
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
                        reader.BaseStream.Seek(Exports[i].SerialOffset, SeekOrigin.Begin);
                        Exports[i] = Exports[i].ConvertToChildExport<RawExport>();
                        ((RawExport)Exports[i]).Data = reader.ReadBytes((int)Exports[i].SerialSize);
                    }
                }
            }
        }

        /// <summary>
        /// Serializes the initial portion of the asset from memory.
        /// </summary>
        /// <returns>A byte array which represents the serialized binary data of the initial portion of the asset.</returns>
        private byte[] MakeHeader()
        {
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

        /// <summary>
        /// Serializes an asset from memory.
        /// </summary>
        /// <returns>A stream that the asset has been serialized to.</returns>
        public MemoryStream WriteData()
        {
            var stre = new MemoryStream();
            BinaryWriter writer = new BinaryWriter(stre);

            // Header
            writer.Seek(0, SeekOrigin.Begin);
            writer.Write(MakeHeader());

            // Name map
            this.NameOffset = (int)writer.BaseStream.Position;
            this.NameCount = this.nameMapIndexList.Count;
            for (int i = 0; i < this.nameMapIndexList.Count; i++)
            {
                writer.WriteFString(nameMapIndexList[i]);
                if (OverrideNameMapHashes.ContainsKey(nameMapIndexList[i]))
                {
                    writer.Write(OverrideNameMapHashes[nameMapIndexList[i]]);
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
                for (int i = 0; i < this.Imports.Count; i++)
                {
                    writer.WriteFName(this.Imports[i].ClassPackage, this);
                    writer.WriteFName(this.Imports[i].ClassName, this);
                    writer.Write(this.Imports[i].OuterIndex);
                    writer.WriteFName(this.Imports[i].ObjectName, this);
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
                    Export us = this.Exports[i];
                    writer.Write(us.ClassIndex.Index);
                    writer.Write(us.SuperIndex.Index);
                    if (EngineVersion >= UE4Version.VER_UE4_TemplateIndex_IN_COOKED_EXPORTS)
                    {
                        writer.Write(us.TemplateIndex.Index);
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
                    writer.Write(this.PreloadDependencies[i].Index);
                }
            }

            // Export data
            int oldOffset = this.SectionSixOffset;
            this.SectionSixOffset = (int)writer.BaseStream.Position;
            long[] categoryStarts = new long[this.Exports.Count];
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

            this.BulkDataStartOffset = (int)stre.Length - 4;

            // Rewrite Section 3
            if (this.Exports.Count > 0)
            {
                writer.Seek(this.ExportOffset, SeekOrigin.Begin);
                for (int i = 0; i < this.Exports.Count; i++)
                {
                    Export us = this.Exports[i];
                    long nextLoc = this.BulkDataStartOffset;
                    if ((this.Exports.Count - 1) > i) nextLoc = categoryStarts[i + 1];

                    us.SerialOffset = categoryStarts[i];
                    us.SerialSize = nextLoc - categoryStarts[i];

                    writer.Write(us.ClassIndex.Index);
                    writer.Write(us.SuperIndex.Index);
                    if (EngineVersion >= UE4Version.VER_UE4_TemplateIndex_IN_COOKED_EXPORTS)
                    {
                        writer.Write(us.TemplateIndex.Index);
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

            // Rewrite Header
            writer.Seek(0, SeekOrigin.Begin);
            writer.Write(MakeHeader());

            writer.Seek(0, SeekOrigin.Begin);
            return stre;
        }

        /// <summary>
        /// Creates a MemoryStream from an asset path.
        /// </summary>
        /// <param name="p">The path to the input file.</param>
        /// <returns>A new MemoryStream that stores the binary data of the input file.</returns>
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

        /// <summary>
        /// Creates a BinaryReader from an asset path.
        /// </summary>
        /// <param name="p">The path to the input file.</param>
        /// <returns>A new BinaryReader that stores the binary data of the input file.</returns>
        public BinaryReader PathToReader(string p)
        {
            return new BinaryReader(PathToStream(p));
        }

        /// <summary>
        /// Serializes and writes an asset to disk from memory.
        /// </summary>
        /// <param name="outputPath">The path on disk to write the asset to.</param>
        /// <exception cref="UnknownEngineVersionException">Thrown when <see cref="EngineVersion"/> is unspecified.</exception>
        public void Write(string outputPath)
        {
            if (EngineVersion == UE4Version.UNKNOWN) throw new UnknownEngineVersionException("Cannot begin serialization before an engine version is specified");

            MemoryStream newData = WriteData();

            if (this.UseSeparateBulkDataFiles && this.Exports.Count > 0)
            {
                long breakingOffPoint = this.Exports[0].SerialOffset;
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

        /// <summary>
        /// Reads an asset from disk and initializes a new instance of the <see cref="UAsset"/> class to store its data in memory.
        /// </summary>
        /// <param name="path">The path of the asset file on disk that this instance will read from.</param>
        /// <param name="engineVersion">The version of the Unreal Engine that will be used to parse this asset. If the asset is versioned, this can be left unspecified.</param>
        /// <param name="defaultCustomVersionContainer">A list of custom versions to parse this asset with. A list of custom versions will automatically be derived from the engine version while parsing if necessary, but you may manually specify them anyways if you wish. If the asset is versioned, this can be left unspecified.</param>
        /// <exception cref="UnknownEngineVersionException">Thrown when this is an unversioned asset and <see cref="EngineVersion"/> is unspecified.</exception>
        /// <exception cref="FormatException">Throw when the asset cannot be parsed correctly.</exception>
        public UAsset(string path, UE4Version engineVersion = UE4Version.UNKNOWN, List<CustomVersion> defaultCustomVersionContainer = null)
        {
            this.FilePath = path;
            EngineVersion = engineVersion;
            CustomVersionContainer = defaultCustomVersionContainer;

            Read(PathToReader(path));
        }

        /// <summary>
        /// Reads an asset from a BinaryReader and initializes a new instance of the <see cref="UAsset"/> class to store its data in memory.
        /// </summary>
        /// <param name="reader">The asset's BinaryReader that this instance will read from.</param>
        /// <param name="engineVersion">The version of the Unreal Engine that will be used to parse this asset. If the asset is versioned, this can be left unspecified.</param>
        /// <param name="defaultCustomVersionContainer">A list of custom versions to parse this asset with. A list of custom versions will automatically be derived from the engine version while parsing if necessary, but you may manually specify them anyways if you wish. If the asset is versioned, this can be left unspecified.</param>
        /// <exception cref="UnknownEngineVersionException">Thrown when this is an unversioned asset and <see cref="EngineVersion"/> is unspecified.</exception>
        /// <exception cref="FormatException">Throw when the asset cannot be parsed correctly.</exception>
        public UAsset(BinaryReader reader, UE4Version engineVersion = UE4Version.UNKNOWN, List<CustomVersion> defaultCustomVersionContainer = null)
        {
            EngineVersion = engineVersion;
            CustomVersionContainer = defaultCustomVersionContainer;
            Read(reader);
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="UAsset"/> class. This instance will store no asset data and does not represent any asset in particular until the <see cref="Read"/> method is manually called.
        /// </summary>
        /// <param name="engineVersion">The version of the Unreal Engine that will be used to parse this asset. If the asset is versioned, this can be left unspecified.</param>
        /// <param name="defaultCustomVersionContainer">A list of custom versions to parse this asset with. A list of custom versions will automatically be derived from the engine version while parsing if necessary, but you may manually specify them anyways if you wish. If the asset is versioned, this can be left unspecified.</param>
        public UAsset(UE4Version engineVersion = UE4Version.UNKNOWN, List<CustomVersion> defaultCustomVersionContainer = null)
        {
            EngineVersion = engineVersion;
            CustomVersionContainer = defaultCustomVersionContainer;
        }
    }
}
