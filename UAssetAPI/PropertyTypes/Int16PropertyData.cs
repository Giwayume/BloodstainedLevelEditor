﻿using System;
using System.IO;

namespace UAssetAPI.PropertyTypes
{
    /// <summary>
    /// Describes a 16-bit signed integer variable (<see cref="short"/>).
    /// </summary>
    public class Int16PropertyData : PropertyData<short>
    {
        public Int16PropertyData(FName name) : base(name)
        {

        }

        public Int16PropertyData()
        {

        }

        private static readonly FName CurrentPropertyType = new FName("Int16Property");
        public override FName PropertyType { get { return CurrentPropertyType; } }

        public override void Read(AssetBinaryReader reader, bool includeHeader, long leng1, long leng2 = 0)
        {
            if (includeHeader)
            {
                reader.ReadByte();
            }

            Value = reader.ReadInt16();
        }

        public override int Write(AssetBinaryWriter writer, bool includeHeader)
        {
            if (includeHeader)
            {
                writer.Write((byte)0);
            }

            writer.Write(Value);
            return sizeof(short);
        }

        public override string ToString()
        {
            return Convert.ToString(Value);
        }

        public override void FromString(string[] d, UAsset asset)
        {
            Value = 0;
            if (short.TryParse(d[0], out short res)) Value = res;
        }
    }
}