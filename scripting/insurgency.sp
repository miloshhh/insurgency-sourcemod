#include <sourcemod>
#include <regex>
#include <sdktools>
#include <insurgency>
#undef REQUIRE_PLUGIN
#include <updater>

#pragma unused cvarVersion

#define MAX_DEFINABLE_WEAPONS 100
#define MAX_WEAPON_LEN 32
#define MAX_CONTROLPOINTS 32
#define PREFIX_LEN 7
#define MAX_SQUADS 8
#define SQUAD_SIZE 8

#define INS
new Handle:cvarVersion = INVALID_HANDLE; // version cvar!
new Handle:cvarEnabled = INVALID_HANDLE; // are we enabled?
new NumWeaponsDefined = 0;
new Handle:g_weap_array = INVALID_HANDLE;
new Handle:g_role_array = INVALID_HANDLE;
new Handle:hGameConf = INVALID_HANDLE;
new g_iObjResEntity, g_iLogicEntity, g_iPlayerManagerEntity;
//============================================================================================================
#define PLUGIN_VERSION "0.0.2"
#define PLUGIN_DESCRIPTION "Provides functions to support Insurgency"
#define UPDATE_URL    "http://ins.jballou.com/sourcemod/update-insurgency.txt"

public Plugin:myinfo =
{
	name = "[INS] Insurgency Support Library",
	author = "Jared Ballou",
	version = PLUGIN_VERSION,
	description = PLUGIN_DESCRIPTION,
	url = "http://jballou.com"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("insurgency");	
	CreateNative("Ins_GetWeaponGetMaxClip1", Native_Weapon_GetMaxClip1);
        CreateNative("Ins_ObjectiveResource_GetProp", Native_ObjectiveResource_GetProp);
        CreateNative("Ins_ObjectiveResource_GetPropFloat", Native_ObjectiveResource_GetPropFloat);
        CreateNative("Ins_ObjectiveResource_GetPropEnt", Native_ObjectiveResource_GetPropEnt);
        CreateNative("Ins_ObjectiveResource_GetPropBool", Native_ObjectiveResource_GetPropBool);
        CreateNative("Ins_ObjectiveResource_GetPropVector", Native_ObjectiveResource_GetPropVector);
        CreateNative("Ins_ObjectiveResource_GetPropString", Native_ObjectiveResource_GetPropString);
        CreateNative("Ins_InCounterAttack", Native_InCounterAttack);
        CreateNative("Ins_GetPlayerScore", Native_GetPlayerScore);
        CreateNative("Ins_GetWeaponName", Native_Weapon_GetWeaponName);
        CreateNative("Ins_GetWeaponId", Native_Weapon_GetWeaponId);
	return APLRes_Success;
}

public OnPluginStart()
{
	cvarVersion = CreateConVar("sm_insurgency_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_PLUGIN | FCVAR_DONTRECORD);
	cvarEnabled = CreateConVar("sm_inslogger_enabled", "1", "sets whether log fixing is enabled", FCVAR_NOTIFY | FCVAR_PLUGIN);
	PrintToServer("[INSURGENCY] Starting");
/*
	AddFolderToDownloadTable("materials/overviews");
	AddFolderToDownloadTable("materials/vgui/backgrounds/maps");
	AddFolderToDownloadTable("materials/vgui/endroundlobby/maps");
*/
	HookEvent("player_pick_squad", Event_PlayerPickSquad);
//	LoadTranslations("insurgency.phrases.txt");
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("game_end", Event_GameEnd);
	HookEvent("game_newmap", Event_GameNewMap);
	HookEvent("game_start", Event_GameStart);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_begin", Event_RoundBegin);
	HookEvent("round_level_advanced", Event_RoundLevelAdvanced);
	HookEvent("object_destroyed", Event_ObjectDestroyed);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured);
	HookEvent("controlpoint_neutralized", Event_ControlPointNeutralized);
	HookEvent("controlpoint_starttouch", Event_ControlPointStartTouch);
	HookEvent("controlpoint_endtouch", Event_ControlPointEndTouch);
	hGameConf = LoadGameConfigFile("insurgency.games");
}

public LoadWeaponData()
{
	if (g_weap_array == INVALID_HANDLE)
	{
		g_weap_array = CreateArray(MAX_DEFINABLE_WEAPONS);
		for (new i;i<MAX_DEFINABLE_WEAPONS;i++)
		{
			PushArrayString(g_weap_array, "");
		}
		PrintToServer("[LOGGER] starting LoadValues");
		new String:name[32];
		decl String:strBuf[32];
		for(new i=0;i<= GetMaxEntities() ;i++){
			if(!IsValidEntity(i))
				continue;
			if(GetEdictClassname(i, name, sizeof(name))){
				if (StrContains(name,"weapon_") == 0) {
					GetWeaponId(i);
				}
			}
		}
	}
}
GetWeaponId(i)
{
	new m_hWeaponDefinitionHandle = GetEntProp(i, Prop_Send, "m_hWeaponDefinitionHandle");
	new String:name[32];
	GetEdictClassname(i, name, sizeof(name));
	decl String:strBuf[32];
	GetArrayString(g_weap_array, m_hWeaponDefinitionHandle, strBuf, sizeof(strBuf));
	if(!StrEqual(name, strBuf))
	{
		SetArrayString(g_weap_array, m_hWeaponDefinitionHandle, name);
		PrintToServer("[INSLIB] Weapons %s not in trie, added as index %d", name,m_hWeaponDefinitionHandle);
	}
	return m_hWeaponDefinitionHandle;
}
public Native_Weapon_GetWeaponId(Handle:plugin, numParams)
{
	new len;
	GetNativeStringLength(1, len);
	if (len <= 0)
	{
	  return false;
	}
	new String:weapon_name[len+1];
	decl String:strBuf[32];
	GetNativeString(1, weapon_name, len+1);
	LoadWeaponData();
	new iEntity = FindEntityByClassname(-1,weapon_name);
	if (iEntity)
	{
		return GetWeaponId(iEntity);
	}
	else
	{
		for(new i = 0; i < MAX_DEFINABLE_WEAPONS; i++)
		{
			GetArrayString(g_weap_array, i, strBuf, sizeof(strBuf));
			if(StrEqual(weapon_name, strBuf)) return i;
		}
	}
	return -1;
}
public Native_Weapon_GetWeaponName(Handle:plugin, numParams)
{
	new weaponid = GetNativeCell(1);
	decl String:strBuf[32];
	LoadWeaponData();
	GetArrayString(g_weap_array, weaponid, strBuf, sizeof(strBuf));
	new maxlen = GetNativeCell(3);
	SetNativeString(2, strBuf, maxlen+1);
}

public Native_Weapon_GetMaxClip1(Handle:plugin, numParams)
{
	new weapon = GetNativeCell(1);
	StartPrepSDKCall(SDKCall_Entity);
	if(!PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "GetMaxClip1")) 
	{
		SetFailState("PrepSDKCall_SetFromConf false, nothing found"); 
	}
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	new Handle:hCall = EndPrepSDKCall();
	new value = SDKCall(hCall, weapon);
	CloseHandle(hCall);
	return value;
}
public Native_ObjectiveResource_GetProp(Handle:plugin, numParams)
{
	new len;
	GetNativeStringLength(1, len);
	if (len <= 0)
	{
	  return false;
	}
	new String:prop[len+1],retval=-1;
	GetNativeString(1, prop, len+1);
	new size = GetNativeCell(2);
	new element = GetNativeCell(3);
	GetObjRes();
	if (g_iObjResEntity > 0)
	{
		retval = GetEntData(g_iObjResEntity, FindSendPropOffs("CINSObjectiveResource", prop) + (size * element));
	}
	return retval;
}
public Native_ObjectiveResource_GetPropFloat(Handle:plugin, numParams)
{
	new len;
	GetNativeStringLength(1, len);
	if (len <= 0)
	{
	  return false;
	}
	new String:prop[len+1],Float:retval=-1.0;
	GetNativeString(1, prop, len+1);
	new size = GetNativeCell(2);
	new element = GetNativeCell(3);
	GetObjRes();
	if (g_iObjResEntity > 0)
	{
		retval = Float:GetEntData(g_iObjResEntity, FindSendPropOffs("CINSObjectiveResource", prop) + (size * element));
	}
	return Float:retval;
}
public Native_ObjectiveResource_GetPropEnt(Handle:plugin, numParams)
{
	new len;
	GetNativeStringLength(1, len);
	if (len <= 0)
	{
	  return false;
	}
	new String:prop[len+1],retval=-1;
	GetNativeString(1, prop, len+1);
	new element = GetNativeCell(2);
	GetObjRes();
	if (g_iObjResEntity > 0)
	{
		retval = GetEntData(g_iObjResEntity, FindSendPropOffs("CINSObjectiveResource", prop) + (4 * element));
	}
	return retval;
}
public Native_ObjectiveResource_GetPropBool(Handle:plugin, numParams)
{
	new len;
	GetNativeStringLength(1, len);
	if (len <= 0)
	{
	  return false;
	}
	new String:prop[len+1],retval=-1;
	GetNativeString(1, prop, len+1);
	new element = GetNativeCell(2);
	GetObjRes();
	if (g_iObjResEntity > 0)
	{
		retval = bool:GetEntData(g_iObjResEntity, FindSendPropOffs("CINSObjectiveResource", prop) + (element));
	}
	return retval;
}
public Native_ObjectiveResource_GetPropVector(Handle:plugin, numParams)
{
	new len;
	GetNativeStringLength(1, len);
	if (len <= 0)
	{
	  return false;
	}
	new String:prop[len+1],retval=-1;
	GetNativeString(1, prop, len+1);
	new size = GetNativeCell(2);
	new element = GetNativeCell(3);
	GetObjRes();
	if (g_iObjResEntity > 0)
	{
		new Float:result[3];
		retval = GetEntDataVector(g_iObjResEntity, FindSendPropOffs("CINSObjectiveResource", prop) + (size * element), result);
		SetNativeArray(2, result, 3);
	}
	return retval;
}
public Native_ObjectiveResource_GetPropString(Handle:plugin, numParams)
{
	new len;
	GetNativeStringLength(1, len);
	if (len <= 0)
	{
	  return false;
	}
	new String:prop[len+1],retval=-1;
	GetNativeString(1, prop, len+1);
/*
	new maxlen = GetNativeCell(3);
	GetObjRes();
	if (g_iObjResEntity > 0)
	{
		//SetNativeString(2, buffer, maxlen+1);
		//GetEntData(g_iObjResEntity, FindSendPropOffs("CINSObjectiveResource", prop) + (size * element));
	}
*/
	return retval;
}
/*
//        decl Float:flGoalPos[3];
//        GetNativeArray(3, flGoalPos, 3);
g_iNumControlPoints);
		m_nActivePushPointIndex = GetEntData(g_iObjResEntity, g_nActivePushPointIndex);
		m_nTeamOneActiveBattleAttackPointIndex = GetEntData(g_iObjResEntity, g_nTeamOneActiveBattleAttackPointIndex);
		m_nTeamOneActiveBattleDefendPointIndex = GetEntData(g_iObjResEntity, g_nTeamOneActiveBattleDefendPointIndex);
		m_nTeamTwoActiveBattleAttackPointIndex = GetEntData(g_iObjResEntity, g_nTeamTwoActiveBattleAttackPointIndex);
		m_nTeamTwoActiveBattleDefendPointIndex = GetEntData(g_iObjResEntity, g_nTeamTwoActiveBattleDefendPointIndex);
		//PrintToServer("[INSURGENCY] m_iNumControlPoints %d m_nActivePushPointIndex %d m_nTeamOneActiveBattleAttackPointIndex %d m_nTeamOneActiveBattleDefendPointIndex %d m_nTeamTwoActiveBattleAttackPointIndex %d m_nTeamTwoActiveBattleDefendPointIndex %d",m_iNumControlPoints,m_nActivePushPointIndex,m_nTeamOneActiveBattleAttackPointIndex,m_nTeamOneActiveBattleDefendPointIndex,m_nTeamTwoActiveBattleAttackPointIndex,m_nTeamTwoActiveBattleDefendPointIndex);
		for (new i=0;i<16;i++)
		{
			m_iCappingTeam[i] = GetEntData(g_iObjResEntity, g_iCappingTeam+(i*4));
			m_iOwningTeam[i] = GetEntData(g_iObjResEntity, g_iOwningTeam+(i*4));
			m_nInsurgentCount[i] = GetEntData(g_iObjResEntity, g_nInsurgentCount+(i*4));
			m_nSecurityCount[i] = GetEntData(g_iObjResEntity, g_nSecurityCount+(i*4));
			m_bSecurityLocked[i] = GetEntData(g_iObjResEntity, g_bSecurityLocked+i);
			m_bInsurgentsLocked[i] = GetEntData(g_iObjResEntity, g_bInsurgentsLocked+i);
			m_iObjectType[i] = GetEntData(g_iObjResEntity, g_iObjectType+(i*4));
			if (i < 2)
			{
				m_nReinforcementWavesRemaining[i] = GetEntData(g_iObjResEntity, g_nReinforcementWavesRemaining+(i*4));
				//PrintToServer("[INSURGENCY] m_nReinforcementWavesRemaining[%d] %d",i,m_nReinforcementWavesRemaining[i]);
			}
			m_nRequiredPointIndex[i] = GetEntData(g_iObjResEntity, g_nRequiredPointIndex+(i*4));
			//PrintToServer("[INSURGENCY] index %d m_iCappingTeam %d m_iOwningTeam %d m_nInsurgentCount %d m_nSecurityCount %d m_vCPPositions %f,%f,%f m_bSecurityLocked %d m_bInsurgentsLocked %d m_iObjectType %d m_nRequiredPointIndex %d",i,m_iCappingTeam[i],m_iOwningTeam[i],m_nInsurgentCount[i],m_nSecurityCount[i],m_vCPPositions[i][0],m_vCPPositions[i][1],m_vCPPositions[i][2],m_bSecurityLocked[i],m_bInsurgentsLocked[i],m_iObjectType[i],m_nRequiredPointIndex[i]);
		}

	}
}
*/
GetLogicEnt() {
	if ((g_iLogicEntity < 1) || !IsValidEntity(g_iLogicEntity))
	{
		new String:sGameMode[32],String:sLogicEnt[64];
		GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
		Format (sLogicEnt,sizeof(sLogicEnt),"logic_%s",sGameMode);
		if (!StrEqual(sGameMode,"checkpoint")) return;
		g_iLogicEntity = FindEntityByClassname(-1,sLogicEnt);
	}
}
GetPlayerManagerEnt() {
	if ((g_iPlayerManagerEntity < 1) || !IsValidEntity(g_iPlayerManagerEntity))
	{
		g_iPlayerManagerEntity = FindEntityByClassname(-1,"ins_player_manager");
	}
}
public Native_GetPlayerScore(Handle:plugin, numParams)
{
	GetPlayerManagerEnt();
	new client = GetNativeCell(1);
	new retval = -1;
	if ((IsValidClient(client)) && (g_iPlayerManagerEntity > 0))
	{
		retval = GetEntData(g_iPlayerManagerEntity, FindSendPropOffs("CINSPlayerResource", "m_iPlayerScore") + (4 * client));
		//PrintToServer("[INSLIB] Client %N m_iPlayerScore %d",client,retval);
	}
	return retval;
}
public Native_InCounterAttack(Handle:plugin, numParams)
{
	GetLogicEnt();
	new bool:retval;
	if (g_iLogicEntity > 0)
	{
		retval = GetEntData(g_iLogicEntity, FindSendPropOffs("CLogicCheckpoint", "m_bCounterAttack"));
	}
	return retval;
}
public Action:Event_ControlPointCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
	{
		return Plugin_Continue;
	}
	//"priority" "short"
	//"cp" "byte"
	//"cappers" "string"
	//"cpname" "string"
	//"team" "byte"
	GetObjRes();
	return Plugin_Continue;
}
public Action:Event_ControlPointNeutralized(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
	{
		return Plugin_Continue;
	}
	//"priority" "short"
	//"cp" "byte"
	//"cappers" "string"
	//"cpname" "string"
	//"team" "byte"
	GetObjRes();
	return Plugin_Continue;
}
public Action:Event_ControlPointStartTouch(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
	{
		return Plugin_Continue;
	}
	//new area = GetEventInt(event, "area");
	//new object = GetEventInt(event, "object");
	//new player = GetEventInt(event, "player");
	//new team = GetEventInt(event, "team");
	//new owner = GetEventInt(event, "owner");
	//new type = GetEventInt(event, "type");
	//PrintToServer("[LOGGER] Event_ControlPointStartTouch: player %N area %d object %d player %d team %d owner %d type %d",player,area,object,player,team,owner,type);
	GetObjRes();
	return Plugin_Continue;
}
public Action:Event_ControlPointEndTouch(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
	{
		return Plugin_Continue;
	}
	//"owner" "short"
	//"player" "short"
	//"team" "short"
	//"area" "byte"
	//new owner = GetEventInt(event, "owner");
	//new player = GetEventInt(event, "player");
	//new team = GetEventInt(event, "team");
	//new area = GetEventInt(event, "area");

	//PrintToServer("[LOGGER] Event_ControlPointEndTouch: player %N area %d player %d team %d owner %d",player,area,player,team,owner);
	GetObjRes();
	return Plugin_Continue;
}

public Action:Event_ObjectDestroyed(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvarEnabled))
	{
		return Plugin_Continue;
	}
	//decl String:attacker_authid[64],String:assister_authid[64],String:classname[64];
	//"team" "byte"
	//"attacker" "byte"
	//"cp" "short"
	//"index" "short"
	//"type" "byte"
	//"weapon" "string"
	//"weaponid" "short"
	//"assister" "byte"
	//"attackerteam" "byte"
	GetObjRes();
	return Plugin_Continue;
}
public Action:Event_GameStart( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"priority" "short"
	GetObjRes();
	return Plugin_Continue;
}
public Action:Event_GameNewMap( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"mapname" "string"
	GetObjRes();
	return Plugin_Continue;
}
public Action:Event_RoundLevelAdvanced( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"level" "short"
	GetObjRes();
	return Plugin_Continue;
}
public Action:Event_GameEnd( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"team2_score" "short"
	//"winner" "byte"
	//"team1_score" "short"
	GetObjRes();
	return Plugin_Continue;
}
public Action:Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"priority" "short"
	//"timelimit" "short"
	//"lives" "short"
	//"gametype" "short"
	GetObjRes();
	return Plugin_Continue;
}
public Action:Event_RoundBegin( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"priority" "short"
	//"timelimit" "short"
	//"lives" "short"
	//"gametype" "short"
	GetObjRes();
	return Plugin_Continue;
}
public Action:Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"reason" "byte"
	//"winner" "byte"
	//"message" "string"
	//"message_string" "string"
	GetObjRes();
	return Plugin_Continue;
}

public Action:Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast )
{
	//new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	GetObjRes();
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	//"deathflags" "short"
	//"attacker" "short"
	//"customkill" "short"
	//"lives" "short"
	//"attackerteam" "short"
	//"damagebits" "short"
	//"weapon" "string"
	//"weaponid" "short"
	//"userid" "short"
	//"priority" "short"
	//"team" "short"
	//"y" "float"
	//"x" "float"
	//"z" "float"
	//"assister" "short"
	GetObjRes();
	return Plugin_Continue;
}


public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

//jballou - LogRole support
public Action:Event_PlayerPickSquad(Handle:event, const String:name[], bool:dontBroadcast)
{
	//"squad_slot" "byte"
	//"squad" "byte"
	//"userid" "short"
	//"class_template" "string"
	//new client = GetClientOfUserId( GetEventInt( event, "userid" ) );

	new squad = GetEventInt( event, "squad" );
	new squad_slot = GetEventInt( event, "squad_slot" );
	decl String:class_template[64];
	GetEventString(event, "class_template",class_template,sizeof(class_template));
	UpdateRoleName(squad,squad_slot,class_template);
	GetObjRes();
	return Plugin_Continue;
}
public UpdateRoleName(squad,squad_slot,String:class_template[])
{
/*
	if (g_role_array == INVALID_HANDLE)
		g_role_array = CreateArray(MAX_SQUADS*SQUAD_SIZE);
	ReplaceString(class_template,sizeof(class_template),"template_","",false);
	ReplaceString(class_template,sizeof(class_template),"_training","",false);
	ReplaceString(class_template,sizeof(class_template),"_coop","",false);
	ReplaceString(class_template,sizeof(class_template),"_security","",false);
	ReplaceString(class_template,sizeof(class_template),"_insurgent","",false);
	ReplaceString(class_template,sizeof(class_template),"_survival","",false);
	new idx=(squad*SQUAD_SIZE)+squad_slot;
	SetArrayString(g_role_array,idx,class_template);
*/
}
public OnMapStart()
{
	GetObjRes();
	LoadWeaponData();
//	GetTeams();
}
public GetObjRes()
{
	if ((g_iObjResEntity < 1) || !IsValidEntity(g_iObjResEntity))
	{
		g_iObjResEntity = FindEntityByClassname(0,"ins_objective_resource");
	}
}
/*
public Native_GetClientRole(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	//m_iSquadSlot
}
*/
