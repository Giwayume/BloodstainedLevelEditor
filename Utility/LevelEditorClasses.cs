using System.Collections.Generic;

namespace LevelEditor {
    public class MapRoomDef {
        public string levelName = "";
        public string LevelName { get { return levelName; } set { levelName = value; } }
        public string enemyPatternSuffix = "";
        public string EnemyPatternSuffix { get { return enemyPatternSuffix; } set { enemyPatternSuffix = value; } }
        public int areaID = 0;
        public int AreaID { get { return areaID; } set { areaID = value; } }
        public string sameRoom = "";
        public string SameRoom { get { return sameRoom; } set { sameRoom = value; } }
        public List<string> adjacentRoomName = new List<string>();
        public List<string> AdjacentRoomName { get { return adjacentRoomName; } set { adjacentRoomName = value; } }
        public bool outOfMap = false;
        public bool OutOfMap { get { return outOfMap; } set { outOfMap = value; } }
        public string eventFlagNameForShowEventIfNotSeen = "None";
        public string EventFlagNameForShowEventIfNotSeen { get { return eventFlagNameForShowEventIfNotSeen; } set { eventFlagNameForShowEventIfNotSeen = value; } }
        public string eventFlagNameForMarkEventAsSeen = "None";
        public string EventFlagNameForMarkEventAsSeen { get { return eventFlagNameForMarkEventAsSeen; } set { eventFlagNameForMarkEventAsSeen = value; } }
        public float warpPositionX = 0;
        public float WarpPositionX { get { return warpPositionX; } set { warpPositionX = value; } }
        public float warpPositionY = 0;
        public float WarpPositionY { get { return warpPositionY; } set { warpPositionY = value; } }
        public float warpPositionZ = 0;
        public float WarpPositionZ { get { return warpPositionZ; } set { warpPositionZ = value; } }
        public int roomType = 0;
        public int RoomType { get { return roomType; } set { roomType = value; } }
        public int roomPath = 0;
        public int RoomPath { get { return roomPath; } set { roomPath = value; } }
        public bool considerLeft = false;
        public bool ConsiderLeft { get { return considerLeft; } set { considerLeft = value; } }
        public bool considerRight = false;
        public bool ConsiderRight { get { return considerRight; } set { considerRight = value; } }
        public bool considerTop = false;
        public bool ConsiderTop { get { return considerTop; } set { considerTop = value; } }
        public bool considerBottom = false;
        public bool ConsiderBottom { get { return considerBottom; } set { considerBottom = value; } }
        public int areaWidthSize = 0;
        public int AreaWidthSize { get { return areaWidthSize; } set { areaWidthSize = value; } }
        public int areaHeightSize = 0;
        public int AreaHeightSize { get { return areaHeightSize; } set { areaHeightSize = value; } }
        public float offsetX = 0;
        public float OffsetX { get { return offsetX; } set { offsetX = value; } }
        public float offsetZ = 0;
        public float OffsetZ { get { return offsetZ; } set { offsetZ = value; } }
        public List<int> doorFlag = new List<int>();
        public List<int> DoorFlag { get { return doorFlag; } set { doorFlag = value; } }
        public List<string> hiddenFlag = new List<string>();
        public List<string> HiddenFlag { get { return hiddenFlag; } set { hiddenFlag = value; } }
        public bool roomCollisionFromSplineOnly = false;
        public bool RoomCollisionFromSplineOnly { get { return roomCollisionFromSplineOnly; } set { roomCollisionFromSplineOnly = value; } }
        public bool roomCollisionFromGimmick = false;
        public bool RoomCollisionFromGimmick { get { return roomCollisionFromGimmick; } set { roomCollisionFromGimmick = value; } }
        public bool noRoomOutBlinder = false;
        public bool NoRoomOutBlinder { get { return noRoomOutBlinder; } set { noRoomOutBlinder = value; } }
        public float collision2DProjectionDistance = 0;
        public float Collision2DProjectionDistance { get { return collision2DProjectionDistance; } set { collision2DProjectionDistance = value; } }
        public float flyMaterialDistance = 0;
        public float FlyMaterialDistance { get { return flyMaterialDistance; } set { flyMaterialDistance = value; } }
        public List<int> noTraverse = new List<int>();
        public List<int> NoTraverse { get { return noTraverse; } set { noTraverse = value; } }
        public float magCameraFovScale = 0;
        public float MagCameraFovScale { get { return magCameraFovScale; } set { magCameraFovScale = value; } }
        public float magCameraVolumeScale = 0;
        public float MagCameraVolumeScale { get { return magCameraVolumeScale; } set { magCameraVolumeScale = value; } }
        public float demagCameraFovScale = 0;
        public float DemagCameraFovScale { get { return demagCameraFovScale; } set { demagCameraFovScale = value; } }
        public float demagCameraVolumeScale = 0;
        public float DemagCameraVolumeScale { get { return demagCameraVolumeScale; } set { demagCameraVolumeScale = value; } }
        public string bgmID = "";
        public string BgmID { get { return bgmID; } set { bgmID = value; } }
        public int bgmType = 0;
        public int BgmType { get { return bgmType; } set { bgmType = value; } }
        public string amb1 = "";
        public string Amb1 { get { return amb1; } set { amb1 = value; } }
        public int ambVol1 = 0;
        public int AmbVol1 { get { return ambVol1; } set { ambVol1 = value; } }
        public string amb2 = "";
        public string Amb2 { get { return amb2; } set { amb2 = value; } }
        public int ambVol2 = 0;
        public int AmbVol2 { get { return ambVol2; } set { ambVol2 = value; } }
        public string amb3 = "";
        public string Amb3 { get { return amb3; } set { amb3 = value; } }
        public int ambVol3 = 0;
        public int AmbVol3 { get { return ambVol3; } set { ambVol3 = value; } }
        public string amb4 = "";
        public string Amb4 { get { return amb4; } set { amb4 = value; } }
        public int ambVol4 = 0;
        public int AmbVol4 { get { return ambVol4; } set { ambVol4 = value; } }
        public float decay_Near = 0;
        public float Decay_Near { get { return decay_Near; } set { decay_Near = value; } }
        public float decay_Far = 0;
        public float Decay_Far { get { return decay_Far; } set { decay_Far = value; } }
        public float decay_Far_Volume = 0;
        public float Decay_Far_Volume { get { return decay_Far_Volume; } set { decay_Far_Volume = value; } }
        public bool useLava = false;
        public bool UseLava { get { return useLava; } set { useLava = value; } }
        public string frameType = "";
        public string FrameType { get { return frameType; } set { frameType = value; } }
        public int perfLevel = 0;
        public int PerfLevel { get { return perfLevel; } set { perfLevel = value; } }
    }
}
