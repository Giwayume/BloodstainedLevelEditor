﻿using System;
using System.IO;

namespace UAssetAPI.PropertyTypes
{
    /// <summary>
    /// Describes an 8-bit signed integer variable.
    /// </summary>
    public class Int8PropertyData : PropertyData<sbyte>
    {
        public Int8PropertyData(FName name, UAsset asset) : base(name, asset)
        {

        }

        public Int8PropertyData()
        {

        }

        private static readonly FName CurrentPropertyType = new FName("Int8Property");
        public override FName PropertyType { get { return CurrentPropertyType; } }

        public override void Read(BinaryReader reader, bool includeHeader, long leng1, long leng2 = 0)
        {
            if (includeHeader)
            {
                reader.ReadByte();
            }

            Value = reader.ReadSByte();
        }

        public override int Write(BinaryWriter writer, bool includeHeader)
        {
            if (includeHeader)
            {
                writer.Write((byte)0);
            }

            writer.Write(Value);
            return sizeof(sbyte);
        }

        public override string ToString()
        {
            return Convert.ToString(Value);
        }

        public override void FromString(string[] d)
        {
            Value = 0;
            if (sbyte.TryParse(d[0], out sbyte res)) Value = res;
        }
    }
}