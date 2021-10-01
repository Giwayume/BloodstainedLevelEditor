﻿using System;
using System.IO;

namespace UAssetAPI.PropertyTypes
{
    /// <summary>
    /// Describes a 64-bit unsigned integer variable (<see cref="ulong"/>).
    /// </summary>
    public class UInt64PropertyData : PropertyData<ulong>
    {
        public UInt64PropertyData(FName name) : base(name)
        {

        }

        public UInt64PropertyData()
        {

        }

        private static readonly FName CurrentPropertyType = new FName("UInt64Property");
        public override FName PropertyType { get { return CurrentPropertyType; } }

        public override void Read(AssetBinaryReader reader, bool includeHeader, long leng1, long leng2 = 0)
        {
            if (includeHeader)
            {
                reader.ReadByte();
            }

            Value = reader.ReadUInt64();
        }

        public override int Write(AssetBinaryWriter writer, bool includeHeader)
        {
            if (includeHeader)
            {
                writer.Write((byte)0);
            }

            writer.Write(Value);
            return sizeof(ulong);
        }

        public override string ToString()
        {
            return Convert.ToString(Value);
        }

        public override void FromString(string[] d, UAsset asset)
        {
            Value = 0;
            if (ulong.TryParse(d[0], out ulong res)) Value = res;
        }
    }
}