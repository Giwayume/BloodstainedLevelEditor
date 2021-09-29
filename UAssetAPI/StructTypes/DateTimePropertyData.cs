﻿using System;
using System.IO;
using UAssetAPI.PropertyTypes;

namespace UAssetAPI.StructTypes
{
    public class DateTimePropertyData : PropertyData<DateTime>
    {
        public DateTimePropertyData(FName name, UAsset asset) : base(name, asset)
        {

        }

        public DateTimePropertyData()
        {

        }

        private static readonly FName CurrentPropertyType = new FName("DateTime");
        public override bool HasCustomStructSerialization { get { return true; } }
        public override FName PropertyType { get { return CurrentPropertyType; } }

        public override void Read(BinaryReader reader, bool includeHeader, long leng1, long leng2 = 0)
        {
            if (includeHeader)
            {
                reader.ReadByte();
            }

            Value = new DateTime(reader.ReadInt64()); // number of ticks since January 1, 0001
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
            Value = DateTime.Parse(d[0]);
        }

        public override string ToString()
        {
            return Value.ToString();
        }

        protected override void HandleCloned(PropertyData res)
        {
            DateTimePropertyData cloningProperty = (DateTimePropertyData)res;
            cloningProperty.Value = new DateTime(cloningProperty.Value.Ticks);
        }
    }
}