﻿using System;
using System.IO;

namespace UAssetAPI.PropertyTypes
{
    /// <summary>
    /// Describes a property which UAssetAPI has no specific serialization for, and is instead represented as an array of bytes as a fallback.
    /// </summary>
    public class UnknownPropertyData : PropertyData<byte[]>
    {
        public FName SerializingPropertyType = CurrentPropertyType;

        public UnknownPropertyData(FName name, UAsset asset) : base(name, asset)
        {

        }

        public UnknownPropertyData()
        {

        }

        private static readonly FName CurrentPropertyType = new FName("UnknownProperty");
        public override FName PropertyType { get { return CurrentPropertyType; } }

        public void SetSerializingPropertyType(FName newType)
        {
            SerializingPropertyType = newType;
        }

        public override void Read(BinaryReader reader, bool includeHeader, long leng1, long leng2 = 0)
        {
            if (includeHeader)
            {
                reader.ReadByte();
            }

            Value = reader.ReadBytes((int)leng1);
        }

        public override int Write(BinaryWriter writer, bool includeHeader)
        {
            if (includeHeader)
            {
                writer.Write((byte)0);
            }

            writer.Write(Value);
            return Value.Length;
        }

        public override string ToString()
        {
            return Convert.ToString(Value);
        }

        protected override void HandleCloned(PropertyData res)
        {
            UnknownPropertyData cloningProperty = (UnknownPropertyData)res;

            cloningProperty.SerializingPropertyType = (FName)SerializingPropertyType.Clone();
        }
    }
}
