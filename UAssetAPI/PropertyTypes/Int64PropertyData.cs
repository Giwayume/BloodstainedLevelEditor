﻿using System;
using System.IO;

namespace UAssetAPI.PropertyTypes
{
    public class Int64PropertyData : PropertyData<long>
    {
        public Int64PropertyData(FName name, UAsset asset) : base(name, asset)
        {
            Type = new FName("Int64Property");
        }

        public Int64PropertyData()
        {
            Type = new FName("Int64Property");
        }

        public override void Read(BinaryReader reader, bool includeHeader, long leng1, long leng2 = 0)
        {
            if (includeHeader)
            {
                reader.ReadByte();
            }

            Value = reader.ReadInt64();
        }

        public override int Write(BinaryWriter writer, bool includeHeader)
        {
            if (includeHeader)
            {
                writer.Write((byte)0);
            }

            writer.Write(Value);
            return sizeof(long);
        }

        public override string ToString()
        {
            return Convert.ToString(Value);
        }

        public override void FromString(string[] d)
        {
            Value = 0;
            if (long.TryParse(d[0], out long res)) Value = res;
        }
    }
}