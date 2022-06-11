# We can load BlueprintGeneratedClass automatically for the most part.
# But nativized blueprints in the form of "DynamicClass" are generally missing a lot of
# information that's stored in the executable. These are a list of assumptions
# based on observations in-game of how these missing properties work.

const blueprint_profiles: Dictionary = {
	"BloodstainedRotN/Content/Core/Environment/Common/Blueprint/B_COM_Light_LineSpot.uasset": {
		"light_defaults": {
			"mobility": "static"
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Common/Blueprint/B_COM_Light_XYZSpot.uasset": {
		"light_defaults": {
			"mobility": "static"
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNum/Mr_MultiBlock_New.uasset": {
		"meshes": [
			{
				"object_name": "StaticMesh",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "WorldCollisionCubeMesh.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNum/Mr_MultiBlock_New2.uasset": {
		"meshes": [
			{
				"object_name": "StaticMesh",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "WorldCollisionCubeMesh.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNum/Mr_MultiBlock_New2_half.uasset": {
		"meshes": [
			{
				"object_name": "StaticMesh",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "WorldCollisionCubeMesh.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrSlope/PB_Slope_1.uasset": {
		"class_edits": {
			"PB_Slope_1_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBSlope_1_1.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrSlope/PB_Slope_2.uasset": {
		"class_edits": {
			"PB_Slope_2_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBSlope_2_1.tscn"
					}
				]
			},
			"PB_Slope_2_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBSlope_2_2.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrSlope/PB_Slope_3.uasset": {
		"class_edits": {
			"PB_Slope_3_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBSlope_3_1.tscn"
					}
				]
			},
			"PB_Slope_3_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBSlope_3_2.tscn"
					}
				]
			},
			"PB_Slope_3_3_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBSlope_3_3.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrSlope/PB_Slope_4.uasset": {
		"class_edits": {
			"PB_Slope_4_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBSlope_4_1.tscn"
					}
				]
			},
			"PB_Slope_4_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBSlope_4_2.tscn"
					}
				]
			},
			"PB_Slope_4_3_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBSlope_4_3.tscn"
					}
				]
			},
			"PB_Slope_4_4_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBSlope_4_4.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Common/Blueprint/CPratform.uasset": {
		"meshes": [
			{
				"object_name": "StaticMeshComponent0",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "CPratform.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/B_SIP_2ndFloor01.uasset": {
		"meshes": [
			{
				"object_name": "Floor",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/ACT01_SIP/Mesh/SIP_Rope11.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/B_SIP_2ndFloor02.uasset": {
		"meshes": [
			{
				"object_name": "StaticMeshComponent0",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/ACT01_SIP/Mesh/SIP_Scaffolding01.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/01SIP/Gm_SIP_03/Gimmick/Gm_SIP_03/SIP_Break_Window.uasset": {
		"meshes": [
			{
				"object_name": "BeforeWall",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/ACT01_SIP/Mesh/SIP_WallBreak01_before.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/03ENT/Chandelier/ChandelierBase_ENT04.uasset": {
		"meshes": [
			{
				"object_name": "Chain1",
				"object_type": "StaticMeshComponent",
				"mesh": ""
			},
			{
				"object_name": "Chain2",
				"object_type": "StaticMeshComponent",
				"mesh": ""
			},
			{
				"object_name": "Chain3",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/ACT03_ENT/Mesh/ENT_Chandelier00_01.uasset"
			},
			{
				"object_name": "StaticMeshComponent01",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/ACT03_ENT/Mesh/ENT_Chandelier01.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/03ENT/PiercedWolfman/PiercedWolfman.uasset": {
		"meshes": [
			{
				"object_name": "StaticMeshWolfMan",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/03ENT/PiercedWolfman/StaticMeshWolfMan.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/04GDN/CarriageStatue/GrabbableGoddessStatue_GDN006.uasset": {
		"meshes": [
			{
				"object_name": "COM_HandBlock_01",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/Common/Mesh/HandBlock/COM_HandBlock_01.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/04GDN/DestructibleWall/GDN006_ItemWall_BP.uasset": {
		"meshes": [
			{
				"object_name": "AfterWall",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/ACT04_GDN/Mesh/GDN_BrkWall01_after.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/BossDoorBase/PBBakkerDoor_BP.uasset": {
		"meshes": [
			{
				"object_name": "EventSkeletalMesh",
				"object_type": "SkeletalMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/Gimmick/OldGimmicks/Gimmick_Boss_Door/Model/COM_BossDoor00.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/Common/IronMaiden/BP_IronMaiden.uasset": {
		"meshes": [
			{
				"object_name": "IronMaiden_Body",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/ACT14_TAR/Meshes/TAR_IronMaiden00.uasset"
			},
			{
				"object_name": "IronMaiden_Left",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/ACT14_TAR/Meshes/TAR_IronMaiden01.uasset"
			},
			{
				"object_name": "IronMaiden_Right",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/ACT14_TAR/Meshes/TAR_IronMaiden02.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/Diary/Data/ReadableBookShelf.uasset": {
		"meshes": [
			{
				"object_name": "StaticMesh",
				"object_type": "StaticMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/Common/Mesh/Props/SM_ReadableBookcase_01.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/Mitem_BulletMaxUp/Data/BulletMaxUp.uasset": {
		"meshes": [
			{
				"object_name": "EventSkeletalMesh",
				"object_type": "SkeletalMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/Mitem_BulletMaxUp/Mesh/SK_BulletMaxUp.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/Mitem_HpMaxUp/Data/HPMaxUp.uasset": {
		"meshes": [
			{
				"object_name": "EventSkeletalMesh",
				"object_type": "SkeletalMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/Mitem_HpMaxUp/Mesh/Sk_Mitem_HpMaxUp.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/Mitem_MpMaxUp/Data/MPMaxUp.uasset": {
		"meshes": [
			{
				"object_name": "EventSkeletalMesh",
				"object_type": "SkeletalMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/Mitem_MpMaxUp/Mesh/Mitem_MpMaxUp.uasset"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/TreasureBox/PBEasyTreasureBox_BP.uasset": {
		"meshes": [
			{
				"object_name": "SkeletalMesh",
				"object_type": "SkeletalMeshComponent",
				"mesh": "BloodstainedRotN/Content/Core/Environment/Gimmick/NewGimmicks/TreasureBox/Mesh/Sk_TreasureBox.uasset"
			}
		]
	},
}
