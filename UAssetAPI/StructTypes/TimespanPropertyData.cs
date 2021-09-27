﻿using System;
using System.IO;
using UAssetAPI.PropertyTypes;

namespace UAssetAPI.StructTypes
{
    public class TimespanPropertyData : PropertyData<TimeSpan>
    {
        public TimespanPropertyData(FName name, UAsset asset) : base(name, asset)
        {
            Type = new FName("Timespan");
        }

        public TimespanPropertyData()
        {
            Type = new FName("Timespan");
        }

        public override void Read(BinaryReader reader, bool includeHeader, long leng1, long leng2 = 0)
        {
            if (includeHeader)
            {
                reader.ReadByte();
            }

            Value = new TimeSpan(reader.ReadInt64()); // number of ticks
        }

        public override int Write(BinaryWriter writer, bool includeHeader)
        {
            if (includeHeader)
            {
                writer.Write((byte)0);
            }

            writer.Write(Value.Ticks);
            return sizeof(long);
        }

        public override void FromString(string[] d)
        {
            Value = TimeSpan.Parse(d[0]);
        }

        public override string ToString()
        {
            return Value.ToString();
        }
    }
}