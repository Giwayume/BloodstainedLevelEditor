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
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_a1.uasset": {
		"meshes": [
				{
					"object_name": "StaticMeshComponent0",
					"object_type": "StaticMeshComponent",
					"custom_mesh": "PBSlope_1_1.tscn"
				}
			]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_b2.uasset": {
		"meshes": [
			{
				"object_name": "StaticMeshComponent0",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "PBWhite_b2.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_b3.uasset": {
		"class_edits": {
			"PB_white_b3_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_b3_1.tscn"
					}
				]
			},
			"PB_white_b3_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_b3_2.tscn"
					}
				]
			},
			"PB_white_b3_3_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_b3_3.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_b4.uasset": {
		"class_edits": {
			"PB_white_b4_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_b4_1.tscn"
					}
				]
			},
			"PB_white_b4_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_b4_2.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_c2.uasset": {
		"meshes": [
			{
				"object_name": "StaticMeshComponent0",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "PBWhite_c2.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_c3.uasset": {
		"class_edits": {
			"PB_white_c3_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_c3_1.tscn"
					}
				]
			},
			"PB_white_c3_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_c3_2.tscn"
					}
				]
			},
			"PB_white_c3_3_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_c3_3.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_c4.uasset": {
		"class_edits": {
			"PB_white_c4_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_c4_1.tscn"
					}
				]
			},
			"PB_white_c4_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_c4_2.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_d2.uasset": {
		"meshes": [
			{
				"object_name": "StaticMeshComponent0",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "PBWhite_d2.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_d3.uasset": {
		"class_edits": {
			"PB_white_d3_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_d3_1.tscn"
					}
				]
			},
			"PB_white_d3_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_d3_2.tscn"
					}
				]
			},
			"PB_white_d3_3_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_d3_3.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_d4.uasset": {
		"class_edits": {
			"PB_white_d4_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_d4_1.tscn"
					}
				]
			},
			"PB_white_d4_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_d4_2.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_e2.uasset": {
		"meshes": [
			{
				"object_name": "StaticMeshComponent0",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "PBWhite_e2.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_e3.uasset": {
		"class_edits": {
			"PB_white_e3_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_e3_1.tscn"
					}
				]
			},
			"PB_white_e3_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_e3_2.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_e4.uasset": {
		"class_edits": {
			"PB_white_e4_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_e4_1.tscn"
					}
				]
			},
			"PB_white_e4_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_e4_2.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_f2.uasset": {
		"meshes": [
			{
				"object_name": "StaticMeshComponent0",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "PBWhite_f2.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_f3.uasset": {
		"class_edits": {
			"PB_white_f3_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_f3_1.tscn"
					}
				]
			},
			"PB_white_f3_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_f3_2.tscn"
					}
				]
			},
			"PB_white_f3_3_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_f3_3.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_f4.uasset": {
		"meshes": [
			{
				"object_name": "StaticMeshComponent0",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "PBWhite_f4_1.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_g2.uasset": {
		"meshes": [
			{
				"object_name": "StaticMeshComponent0",
				"object_type": "StaticMeshComponent",
				"custom_mesh": "PBWhite_g2.tscn"
			}
		]
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_g3.uasset": {
		"class_edits": {
			"PB_white_g3_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_g3_1.tscn"
					}
				]
			},
			"PB_white_g3_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_g3_2.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/MrWhiteBox/PB_white_g4.uasset": {
		"class_edits": {
			"PB_white_g4_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_g4_1.tscn"
					}
				]
			},
			"PB_white_g4_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBWhite_g4_2.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/PBMrBlockNature_1.uasset": {
		"class_edits": {
			"PBMrBlockNature_1_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBMrBlockNature_1_1.tscn"
					}
				]
			},
			"PBMrBlockNature_1_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBMrBlockNature_1_2.tscn"
					}
				]
			},
			"PBMrBlockNature_1_3_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBMrBlockNature_1_3.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/PBMrBlockNature_2.uasset": {
		"class_edits": {
			"PBMrBlockNature_2_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBMrBlockNature_2_1.tscn"
					}
				]
			},
			"PBMrBlockNature_2_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBMrBlockNature_2_2.tscn"
					}
				]
			},
			"PBMrBlockNature_2_3_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBMrBlockNature_2_3.tscn"
					}
				]
			}
		}
	},
	"BloodstainedRotN/Content/Core/Environment/Tool/MrBlockNature/PBMrBlockNature_3.uasset": {
		"class_edits": {
			"PBMrBlockNature_3_1_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBMrBlockNature_3_1.tscn"
					}
				]
			},
			"PBMrBlockNature_3_2_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBMrBlockNature_3_2.tscn"
					}
				]
			},
			"PBMrBlockNature_3_3_C": {
				"meshes": [
					{
						"object_name": "StaticMeshComponent0",
						"object_type": "StaticMeshComponent",
						"custom_mesh": "PBMrBlockNature_3_3.tscn"
					}
				]
			}
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
