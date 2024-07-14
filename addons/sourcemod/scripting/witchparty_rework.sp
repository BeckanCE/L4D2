#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#undef REQUIRE_PLUGIN
#include <readyup>
#include <l4d2_penalty_bonus>
#include <l4d2_skill_detect>
#define REQUIRE_PLUGIN

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION "2.4"
#define Position_rhand 1
#define Position_lhand 2

ConVar
	g_cvarDebug,
	g_cvarBonus,
	g_cvarPrintBonus,

	g_cvarGlowEnabled,
	g_cvarGlowMinRange,
	g_cvarGlowMaxRange,

	g_cvarSpawnIncap,
	g_cvarSpawnTime,
	g_cvarSpawnDistance,
	g_cvarSpawnLimit,
	g_cvarSpawnMethod,

	g_cvarHealthLimit,
	g_cvarHealthPerm,
	g_cvarHealthTemp,

	g_cvarAdrenalineEffect,

	g_cvarTankKillWitch,
	g_cvarTankSpawnWitch,
	g_cvarTankMelee;

Handle
	g_hSpawnTimer;
int
	g_iMeleeEnt[MAXPLAYERS + 1];

bool
	g_bMeleeViewOn[MAXPLAYERS + 1],
	g_bSpawnWitchBride = false;

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/
public Plugin myinfo =
{
	name		= "WirchParty Rework",
	author		= "Lechuga",
	description = "Essential features for witchparty",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/lechuga16/WitchParty-Rework"
}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public void OnPluginStart()
{
	LoadTranslation("witchparty_rework.phrases");

	g_cvarDebug			   = CreateConVar("sm_wp_debug", "0", "Debug messages", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarBonus			   = CreateConVar("sm_wp_witch_bonus", "10", "Wich Death Bonus. 0: disabled", FCVAR_NONE, true, 0.0);
	g_cvarPrintBonus	   = CreateConVar("sm_wp_bonus_print", "1", "Print the bonus when successfully killing the wich", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvarGlowEnabled	   = CreateConVar("sm_wp_glow_enabled", "1", "Enable witch glow", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarGlowMinRange	   = CreateConVar("sm_wp_glow_min_range", "10", "Minimum range for witch glow", FCVAR_NONE, true, 0.0);
	g_cvarGlowMaxRange	   = CreateConVar("sm_wp_glow_max_range", "2000", "Maximum range for witch glow", FCVAR_NONE, true, 0.0);

	g_cvarSpawnIncap	   = CreateConVar("sm_wp_spawn_incap", "2", "Generate witch when a survivor becomes incapacitated. 0: disabled, any other number is the number of switches", FCVAR_NONE, true, 0.0);
	g_cvarSpawnTime		   = CreateConVar("sm_wp_spawn_witch", "12.0", "Respawn time", FCVAR_NONE, true, 2.0);
	g_cvarSpawnLimit	   = CreateConVar("sm_wp_spawn_limit", "15", "Sets limit for witches spawned. 0: disabled", FCVAR_NONE, true, 0.0);
	g_cvarSpawnDistance	   = CreateConVar("sm_wp_spawn_distance_kill", "1500", "Distance from survivors that witch should be removed. If 0, plugin will not remove witches.", FCVAR_NONE);
	g_cvarSpawnMethod	   = CreateConVar("sm_wp_spawn_method", "1", "Method that will be used for spawning. 0:lef4dhooks(allows respawn of WitchBride) 1:sktools(only normal Witch)", FCVAR_NONE, true, 0.0);

	g_cvarHealthLimit	   = CreateConVar("sm_wp_health_limit", "0", "Sets limit for witches health. 0: disabled", FCVAR_NONE, true, 0.0);
	g_cvarHealthPerm	   = CreateConVar("sm_wp_health_perm", "5", "Permanent health for witches. 0: disabled", FCVAR_NONE, true, 0.0);
	g_cvarHealthTemp	   = CreateConVar("sm_wp_health_temp", "10", "Temporary health for witches. 0: disabled", FCVAR_NONE, true, 0.0);

	g_cvarAdrenalineEffect = CreateConVar("sm_wp_adrenaline_effect", "3.0", "Seconds of adrenaline effect can kill a witch. 0.0: disabled", FCVAR_NONE, true, 0.0);

	g_cvarTankKillWitch	   = CreateConVar("sm_wp_tank_kill_witch", "1", "Allow tank to kill witches", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarTankSpawnWitch   = CreateConVar("sm_wp_tank_spawn_witch", "0", "Allow tank to spawn witches", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarTankMelee		   = CreateConVar("sm_wp_tank_melee", "1", "Add a witch to the tank as a melee", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvarSpawnTime.AddChangeHook(OnConVarChanged);

	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("witch_killed", Event_Witchkilled, EventHookMode_Pre);
	HookEvent("player_incapacitated", Event_Incapacitated, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath); 

	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);


	RegAdminCmd("sm_spawnwitch", Cmd_SpawnWitch, ADMFLAG_GENERIC, "Respawn Witch");
	RegAdminCmd("sm_killwitch", Cmd_killWitch, ADMFLAG_GENERIC, "Kill All Witch");
	RegConsoleCmd("sm_showmelee", Cmd_ShowMelee, "Show/Hide melee witch for tank"); 
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	deletetimer(g_hSpawnTimer);
	g_hSpawnTimer = CreateTimer(convar.FloatValue, Timer_Spawned, _, TIMER_REPEAT);
}

Action Cmd_SpawnWitch(int iClient, int iArgs)
{
	SpawnWitch();
	CPrintToChat(iClient, "%t %t", "Tag", "WitchSpawned");
	return Plugin_Handled;
}

Action Cmd_killWitch(int iClient, int iArgs)
{
	KillWiches();
	CPrintToChat(iClient, "%t %t", "Tag", "AllWitchesKilled");
	return Plugin_Handled;
}

public Action Cmd_ShowMelee(int client, int args)
{
	if(IsValidClientIndex(client))
		g_bMeleeViewOn[client] = !g_bMeleeViewOn[client];
	return Plugin_Handled;
}

public void OnMapEnd()
{
	deletetimer(g_hSpawnTimer);
}

/*****************************************************************
			F O R W A R D   P L U G I N
*****************************************************************/

public void OnWitchCrown(int survivor, int damage)
{
	if (g_cvarBonus.IntValue > 0)
		PBONUS_AddRoundBonus(g_cvarBonus.IntValue, !g_cvarPrintBonus.BoolValue);

	if (L4D_IsPlayerIncapacitated(survivor))
		return;

	if (g_cvarAdrenalineEffect.IntValue)
		L4D2_UseAdrenaline(survivor, g_cvarAdrenalineEffect.FloatValue, false, false);

	IncreaseHealth(survivor);
}

public void OnWitchCrownChip(int survivor, int damage, int chipdamage)
{
	if (g_cvarBonus.IntValue > 0)
		PBONUS_AddRoundBonus(g_cvarBonus.IntValue, !g_cvarPrintBonus.BoolValue);

	if (L4D_IsPlayerIncapacitated(survivor))
		return;

	if (g_cvarAdrenalineEffect.IntValue)
		L4D2_UseAdrenaline(survivor, g_cvarAdrenalineEffect.FloatValue, false, false);

	IncreaseHealth(survivor);
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

// Readyup
public void OnRoundIsLive()
{
	deletetimer(g_hSpawnTimer);
	g_hSpawnTimer = CreateTimer(g_cvarSpawnTime.FloatValue, Timer_Spawned, _, TIMER_REPEAT);
}

Action Timer_Spawned(Handle timer)
{
	if (L4D2_IsTankInPlay() && !g_cvarTankSpawnWitch.BoolValue)
	{
		logdebug("Tank is in play, skipping witch spawn");
		return Plugin_Continue;
	}

	int iCountAliveWitches = GetCountAliveWitches();

	if (g_cvarSpawnLimit.IntValue > 0 && iCountAliveWitches >= g_cvarSpawnLimit.IntValue)
	{
		logdebug("Spawn limit reached %d/%d;", iCountAliveWitches, g_cvarSpawnLimit.IntValue);
		return Plugin_Continue;
	}

	SpawnWitch();
	logdebug("Attempting to spawn %d/%d witches", iCountAliveWitches + 1, g_cvarSpawnLimit.IntValue);

	return Plugin_Continue;
}

// Events
public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvarGlowEnabled.BoolValue)
		return;

	int iWitchid = event.GetInt("witchid");
	SetGlow(iWitchid);
}

public Action Event_Witchkilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvarGlowEnabled.BoolValue)
		return Plugin_Continue;

	int iWitchid = event.GetInt("witchid");
	RestGlow(iWitchid);
	return Plugin_Continue;
}

public Action Event_Incapacitated(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvarSpawnIncap.BoolValue)
		return Plugin_Continue;

	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsClientInGame(iClient) || L4D_GetClientTeam(iClient) != L4DTeam_Survivor)
		return Plugin_Continue;

	int iWitchSpawned = 0;
	do
	{
		SpawnWitch();
		iWitchSpawned++;
		logdebug("Attempting to spawn %d witches for incap", g_cvarSpawnIncap.IntValue);
	}
	while (iWitchSpawned < g_cvarSpawnIncap.IntValue);

	CPrintToChatAll("%t %t", "Tag", "Incapacitated", iWitchSpawned);
	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));

	if(!IsValidClientIndex(iClient))
		return;

	DeleteMelee(iClient);
}

public void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_cvarTankMelee.BoolValue)
		return;
		
	int client = GetClientOfUserId(GetEventInt(event, "player"));
	int bot	   = GetClientOfUserId(GetEventInt(event, "bot"));

	if (IsValidClientIndex(client))
		DeleteMelee(client);

	if (IsValidClientIndex(bot))
	{
		DeleteMelee(bot);
		CreateMeleeTank(bot);
	}
}

public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_cvarTankMelee.BoolValue)
		return;

	int client = GetClientOfUserId(GetEventInt(event, "player"));
	int bot	   = GetClientOfUserId(GetEventInt(event, "bot"));

	if (IsValidClientIndex(bot))
		DeleteMelee(bot);

	if (IsValidClientIndex(client))
	{
		DeleteMelee(client);
		CreateMeleeTank(client);
	}
}

// left4dhoocks
public void L4D2_OnEndVersusModeRound_Post()
{
	deletetimer(g_hSpawnTimer);

	if(g_cvarTankMelee.BoolValue)
		ResetAllState();
}

public void L4D_OnSpawnTank_Post(int client, const float vecPos[3], const float vecAng[3])
{
	if (!g_cvarTankKillWitch.BoolValue)
		return;

	KillWiches();
	CPrintToChatAll("%t %t", "Tag", "TankSpawned");

	if (g_cvarTankMelee.BoolValue)
		CreateMeleeTank(client);
}

public void L4D_OnWitchSetHarasser(int witch, int victim)
{
	if (!g_cvarGlowEnabled.BoolValue)
		return;

	if(!IsValidClientIndex(victim))
		return;

	RestGlow(witch);
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

bool deletetimer(Handle &hTimer)
{
	if (hTimer != null)
	{
		delete hTimer;
		hTimer = null;
		logdebug("Deleting timer %d", hTimer);
		return true;
	}
	return false;
}

/**
 * Check if the translation file exists
 *
 * @param translation	Translation name.
 * @noreturn
 */
stock void LoadTranslation(const char[] translation)
{
	char
		sPath[PLATFORM_MAX_PATH],
		sName[64];

	Format(sName, sizeof(sName), "translations/%s.txt", translation);
	BuildPath(Path_SM, sPath, sizeof(sPath), sName);
	if (!FileExists(sPath))
		SetFailState("Missing translation file %s.txt", translation);

	LoadTranslations(translation);
}

/**
 * Logs a debug message to the server console and log file.
 *
 * @param sMessage The message to be logged.
 * @param ... Additional arguments to be formatted into the message.
 */
public void logdebug(const char[] sMessage, any...)
{
	if (!g_cvarDebug.BoolValue)
		return;

	static int	iCheck = -1;
	static char sFormat[512];
	static char sFilename[64];

	VFormat(sFormat, sizeof(sFormat), sMessage, 2);

	GetPluginFilename(null, sFilename, sizeof(sFilename));
	if ((iCheck = FindCharInString(sFilename, '/', true)) != -1 || (iCheck = FindCharInString(sFilename, '\\', true)) != -1)
		Format(sFilename, sizeof(sFilename), "%s", sFilename[iCheck + 1]);

	ReplaceString(sFilename, sizeof(sFilename), ".smx", "", false);
	LogMessage("[%s] %s", sFilename, sFormat);
	PrintToServer("[%s] %s", sFilename, sFormat);
}

/**
 * Sets the glow properties for a witch entity.
 *
 * @param iWitch The index of the witch entity.
 */
void SetGlow(int iWitch)
{
	SetEntProp(iWitch, Prop_Send, "m_iGlowType", 3);
	SetEntProp(iWitch, Prop_Send, "m_glowColorOverride", 16777215);
	SetEntProp(iWitch, Prop_Send, "m_nGlowRangeMin", g_cvarGlowMinRange.IntValue);
	SetEntProp(iWitch, Prop_Send, "m_nGlowRange", g_cvarGlowMaxRange.IntValue);
}

/**
 * Resets the glow properties of a witch entity.
 *
 * @param iWitch The index of the witch entity.
 */
void RestGlow(int iWitch)
{
	SetEntProp(iWitch, Prop_Send, "m_iGlowType", 0);
	SetEntProp(iWitch, Prop_Send, "m_glowColorOverride", 0);
	SetEntProp(iWitch, Prop_Send, "m_nGlowRangeMin", 0);
	SetEntProp(iWitch, Prop_Send, "m_nGlowRange", 0);
}

/**
 * Spawns a witch entity at a random position.
 */
void SpawnWitch()
{
	float
		fSpawnPos[3],
		fSpawnAng[3];

	int
		iRandom = GetRandom();

	if (iRandom > 0 && L4D_GetRandomPZSpawnPosition(iRandom, 8, 30, fSpawnPos))
	{
		int iWichEntity;
		fSpawnAng[1] = GetRandomFloatEx(-179.0, 179.0);

		if(g_cvarSpawnMethod.IntValue)
		{
			iWichEntity = CreateEntityByName("witch");
			if (iWichEntity <= MaxClients)
			{
				logdebug("Failed to create a witch. Method: Sktools | Pos[%.1f][%.1f][%.1f] | Ang[%.1f][%.1f][%.1f]", fSpawnPos[0], fSpawnPos[1], fSpawnPos[2], fSpawnAng[0], fSpawnAng[1], fSpawnAng[2]);
				return;
			}
			SetAbsOrigin(iWichEntity, fSpawnPos);
			SetAbsAngles(iWichEntity, fSpawnAng);
			DispatchSpawn(iWichEntity);
		}
		else
		{
			if(g_bSpawnWitchBride)
				iWichEntity = L4D2_SpawnWitchBride(fSpawnPos, fSpawnAng);
			else
				iWichEntity = L4D2_SpawnWitch(fSpawnPos, fSpawnAng);
			
			g_bSpawnWitchBride = !g_bSpawnWitchBride;
			if (iWichEntity <= MaxClients)
			{
				logdebug("Failed to create a witch. Method: lef4dhooks | Pos[%.1f][%.1f][%.1f] | Ang[%.1f][%.1f][%.1f]", fSpawnPos[0], fSpawnPos[1], fSpawnPos[2], fSpawnAng[0], fSpawnAng[1], fSpawnAng[2]);
				return;
			}
		}
	}
}

/**
 * Returns a random client index from the list of alive survivors.
 *
 * @return The index of a random alive survivor client, or 0 if no survivors are found.
 */
int GetRandom()
{
	int client;
	ArrayList array = new ArrayList();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && L4D_GetClientTeam(i) == L4DTeam_Survivor)
			array.Push(i);
	}

	if (array.Length > 0)
		client = array.Get(GetRandomIntEx(0, array.Length - 1));

	delete array;
	return client;
}

/**
 * Generates a random floating-point number between the specified minimum and maximum values.
 *
 * @param min The minimum value of the range (inclusive).
 * @param max The maximum value of the range (exclusive).
 * @return A random floating-point number between min and max.
 */
float GetRandomFloatEx(float min, float max)
{
	return (GetURandomFloat() * (max - min)) + min;
}

/**
 * Generates a random integer between the specified minimum and maximum values.
 *
 * @param min The minimum value of the range (inclusive).
 * @param max The maximum value of the range (inclusive).
 * @return A random integer between the specified minimum and maximum values.
 */
int GetRandomIntEx(int min, int max)
{
	int random = GetURandomInt();
	if (random == 0)
	{
		random++;
	}
	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

/**
 * Retrieves the count of alive witches.
 *
 * @return The number of alive witches.
 */
int GetCountAliveWitches()
{
	int countAlive = 0;
	int iNdex	   = -1;

	while ((iNdex = FindEntityByClassname2(iNdex, "witch")) != -1)
	{
		countAlive++;
		logdebug("Witch ID = %i (Alive witches = %i)", iNdex, countAlive);

		if (g_cvarSpawnDistance.FloatValue > 0.0)
		{
			float WitchPos[3];
			float PlayerPos[3];
			GetEntPropVector(iNdex, Prop_Send, "m_vecOrigin", WitchPos);
			int k		= 0;
			int clients = 0;

			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && L4D_GetClientTeam(i) == L4DTeam_Survivor)
				{
					clients++;
					GetClientAbsOrigin(i, PlayerPos);
					float distance = GetVectorDistance(WitchPos, PlayerPos);
					logdebug("Distance to witch = %f; Max distance = %f", distance, g_cvarSpawnDistance.FloatValue);

					if (distance > g_cvarSpawnDistance.FloatValue)
					{
						k++;
					}
				}
			}

			if (k == clients)
			{
				AcceptEntityInput(iNdex, "Kill");
				countAlive--;
			}
		}
	}
	logdebug("Alive witches: %d | Spawn Distance Max: %d", countAlive, g_cvarSpawnDistance.IntValue);
	return countAlive;
}

/**
 * Finds the next entity of the specified classname starting from the given entity index.
 *
 * @param startEnt The entity index to start searching from.
 * @param classname The classname of the entity to find.
 * @return The entity index of the found entity, or -1 if no entity is found.
 */
int FindEntityByClassname2(int startEnt, const char[] classname)
{
	while (startEnt < GetMaxEntities() && !IsValidEntity(startEnt))
	{
		startEnt++;
	}
	return FindEntityByClassname(startEnt, classname);
}

/**
 * Increases the health of a player.
 *
 * @param iClient The client index of the player.
 */
void IncreaseHealth(int iClient)
{
	int
		iHealthCurrent	   = GetEntProp(iClient, Prop_Send, "m_iHealth"),
		iHealthTempCurrent = L4D_GetPlayerTempHealth(iClient),

		iHealth			   = iHealthCurrent + g_cvarHealthPerm.IntValue,
		iHealthTemp		   = iHealthTempCurrent + g_cvarHealthTemp.IntValue,

		iTotalHealth	   = iHealth + iHealthTemp;

	if (g_cvarHealthLimit.BoolValue)
	{
		int iHealthLimit = g_cvarHealthLimit.IntValue;

		if (iHealth > iHealthLimit)
		{
			SetEntProp(iClient, Prop_Send, "m_iHealth", iHealthLimit);
			L4D_SetPlayerTempHealth(iClient, 0);
			CPrintToChat(iClient, "%t", "HealthLimitReached");
		}
		else if (iTotalHealth > iHealthLimit)
		{
			int
				iMissingHealth = iHealthLimit - iHealth,
				iMissingHealthTemp;

			if (iMissingHealth < iHealthTemp)
				iMissingHealthTemp = iMissingHealth;
			else
				iMissingHealthTemp = iHealthTemp;

			SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
			L4D_SetPlayerTempHealth(iClient, iMissingHealthTemp + iHealthTempCurrent);
			CPrintToChat(iClient, "%t %t", "Tag", "Health", iMissingHealth, iMissingHealthTemp);
		}
		else
		{
			SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
			L4D_SetPlayerTempHealth(iClient, iHealthTemp);
			CPrintToChat(iClient, "%t %t", "Tag", "Health", iHealth, iHealthTemp);
		}
	}
	else
	{
		SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
		L4D_SetPlayerTempHealth(iClient, iHealthTemp);
		CPrintToChat(iClient, "%t %t", "Tag", "Health", g_cvarHealthPerm.IntValue, g_cvarHealthTemp.IntValue);
	}
}

/**
 * Kills all witches in the game.
 */
void KillWiches()
{
	int iNdex = -1;

	while ((iNdex = FindEntityByClassname2(iNdex, "witch")) != -1)
	{
		AcceptEntityInput(iNdex, "Kill");
	}
}

void CreateMeleeTank(int iClient)
{
 	if(IsValidClientIndex(iClient) && IsClientInGame(iClient) && IsPlayerAlive(iClient) && IsTank(iClient))
		CreateTimer(1.0, Timer_CreateMelee, iClient);
}

public Action Timer_CreateMelee(Handle timer, any iClient)
{
	if(IsValidClientIndex(iClient) && IsClientInGame(iClient) && IsPlayerAlive(iClient) && IsTank(iClient))
		CreateMelee(iClient);

	return Plugin_Stop;
}

void CreateMelee(int client)
{
	logdebug("Creating melee for Tank %N", client);
	DeleteMelee(client);

	int iPosition = 1;

	if (GetRandomInt(1, 3) < 3)
		iPosition = Position_rhand;
	else
		iPosition = Position_lhand;

	float fScale = 1.0;
	int	  iMelee = 0;

	iMelee		= CreateEntityByName("prop_dynamic_override");

	SetEntityModel(iMelee, "models/infected/witch.mdl");
	DispatchSpawn(iMelee);

	char tname[60];
	Format(tname, sizeof(tname), "target%d", client);
	DispatchKeyValue(client, "targetname", tname);
	DispatchKeyValue(iMelee, "parentname", tname);

	float fPos[3];
	float fAng[3];

	SetVariantString(tname);
	AcceptEntityInput(iMelee, "SetParent", iMelee, iMelee, 0);

	char sPositon[32];

	if (iPosition == Position_lhand)
		sPositon = "lhand";
	else
		sPositon = "rhand";

	SetVariantString(sPositon);
	AcceptEntityInput(iMelee, "SetParentAttachment");

	if (iPosition == Position_rhand)
	{
		SetVector(fPos, -3.0, 15.0, 3.0);
		SetVector(fAng, -90.0, -0.0, 90.0);
	}
	else if (iPosition == Position_lhand)
	{
		SetVector(fPos, 3.0, 15.0, -3.0);
		SetVector(fAng, 90.0, -0.0, 90.0);
	}

	TeleportEntity(iMelee, fPos, fAng, NULL_VECTOR);

	SetEntProp(iMelee, Prop_Send, "m_CollisionGroup", 2);
	SetEntPropFloat(iMelee, Prop_Send, "m_flModelScale", fScale);

	g_iMeleeEnt[client]	= iMelee;
	g_bMeleeViewOn[client] = false;
	SDKHook(g_iMeleeEnt[client], SDKHook_SetTransmit, Hook_SetTransmit);
}

public Action Hook_SetTransmit(int entity, int client)
{
	if(entity == g_iMeleeEnt[client])
	{
		if(g_bMeleeViewOn[client])
			return Plugin_Continue;
		else
			return Plugin_Handled;
	}

	return Plugin_Continue;
}

void DeleteMelee(int client)
{
	if (IsMelee(g_iMeleeEnt[client]))
	{
		AcceptEntityInput(g_iMeleeEnt[client], "ClearParent");
		AcceptEntityInput(g_iMeleeEnt[client], "kill");
		SDKUnhook(g_iMeleeEnt[client], SDKHook_SetTransmit, Hook_SetTransmit);
	}
	g_iMeleeEnt[client] = 0;
}

bool IsMelee(int ent)
{
	if (ent > 0 && IsValidEdict(ent) && IsValidEntity(ent))
		return true;
	else
		return false;
}

void SetVector(float target[3], float x, float y, float z)
{
	target[0] = x;
	target[1] = y;
	target[2] = z;
}

void ResetAllState()
{
	for(int i=1; i<=MaxClients; i++)
	{
		g_iMeleeEnt[i]=0;
	}
}

/**
 * Checks if a client is a tank.
 *
 * @param iClient The client index to check.
 * @return True if the client is a tank, false otherwise.
 */
bool IsTank(int iClient)
{
	if (L4D_GetClientTeam(iClient) == L4DTeam_Infected && L4D2_GetPlayerZombieClass(iClient) == L4D2ZombieClass_Tank)
		return true;

	return false;
}

stock bool IsValidClientIndex(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients);
}

// =======================================================================================
// Bibliography
// https://forums.alliedmods.net/showthread.php?p=2656053 Witch Glow
// https://forums.alliedmods.net/showthread.php?t=138553 MultiWitches v1.3
// https://github.com/MatthewClair/sourcemod-plugins/blob/5a70db01be64ef4a34504625b15fa9201006f199/healer_witch/healer_witch.sp Healer Witch
// https://github.com/MatthewClair/sourcemod-plugins/blob/5a70db01be64ef4a34504625b15fa9201006f199/mutliwitch/l4d_multiwitch.sp MultiWitch
// =======================================================================================
