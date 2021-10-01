﻿using System;
using System.IO;

namespace UAssetAPI.PropertyTypes
{
    /// <summary>
    /// Describes a 32-bit signed integer variable (<see cref="int"/>).
    /// </summary>
    public class IntPropertyData : PropertyData<int>
    {
        public IntPropertyData(FName name) : base(name)
        {

        }

        public IntPropertyData()
        {

        }

        private static readonly FName CurrentPropertyType = new FName("IntProperty");
        public override FName PropertyType { get { return CurrentPropertyType; } }

        public override void Read(AssetBinaryReader reader, bool includeHeader, long leng1, long leng2 = 0)
        {
            if (includeHeader)
            {
                reader.ReadByte();
            }

            Value = reader.ReadInt32();
        }

        public override int Write(AssetBinaryWriter writer, bool includeHeader)
        {
            if (includeHeader)
            {
                writer.Write((byte)0);
            }

            writer.Write(Value);
            return sizeof(int);
        }

        public override string ToString()
        {
            return Convert.ToString(Value);
        }

        public override void FromString(string[] d, UAsset asset)
        {
            Value = 0;
            if (int.TryParse(d[0], out int res)) Value = res;
        }
    }
}
