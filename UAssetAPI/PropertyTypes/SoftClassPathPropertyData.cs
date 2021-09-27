﻿using System.IO;

namespace UAssetAPI.PropertyTypes
{
    public class SoftClassPathPropertyData : PropertyData<FName>
    {
        public uint ID = 0;

        public SoftClassPathPropertyData(FName name, UAsset asset) : base(name, asset)
        {
            Type = new FName("SoftClassPath");
        }

        public SoftClassPathPropertyData()
        {
            Type = new FName("SoftClassPath");
        }

        public override void Read(BinaryReader reader, bool includeHeader, long leng1, long leng2 = 0)
        {
            if (includeHeader)
            {
                reader.ReadByte();
            }

            Value = reader.ReadFName(Asset);
            ID = reader.ReadUInt32();
        }

        public override int Write(BinaryWriter writer, bool includeHeader)
        {
            if (includeHeader)
            {
                writer.Write((byte)0);
            }

            writer.WriteFName(Value, Asset);
            writer.Write(ID);
            return sizeof(int) * 3;
        }

        public override string ToString()
        {
            return "(" + Value.ToString() + ", " + ID + ")";
        }

        public override void FromString(string[] d)
        {
            FName output = FName.FromString(d[0]);
            Asset.AddNameReference(output.Value);
            Value = output;

            if (uint.TryParse(d[1], out uint res2))
            {
                ID = res2;
            }
            else
            {
                ID = 0;
            }
        }
    }
}
