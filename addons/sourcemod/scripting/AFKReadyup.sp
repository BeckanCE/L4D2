#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

ConVar
	g_cvarDebug,
	g_cvarEnable,
	g_cvarPlayerIgnore,
	g_cvarTime,
	g_cvarReadyFooter,
	g_cvarShowTimer;

int
	g_iPlayerAFK[MAXPLAYERS + 1];

float
	g_fPlayerLastPos[MAXPLAYERS + 1][3],
	g_fPlayerLastEyes[MAXPLAYERS + 1][3];

Handle
	g_hStartTimerAFK;

bool
	g_bReadyUpAvailable;

enum L4DTeam
{
	L4DTeam_Unassigned = 0,
	L4DTeam_Spectator  = 1,
	L4DTeam_Survivor   = 2,
	L4DTeam_Infected   = 3
}

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/

public Plugin myinfo =
{
	name		= "AFK on Readyup",
	author		= "lechuga",
	description = "Manage AFK players in the readyup",
	version		= "1.1",
	url			= "https://github.com/lechuga16/AFK-on-readyup"
};

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public void OnAllPluginsLoaded()
{
	g_bReadyUpAvailable = LibraryExists("readyup");
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "readyup"))
		g_bReadyUpAvailable = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "readyup"))
		g_bReadyUpAvailable = false;
}

public void OnPluginStart()
{
	LoadTranslations("AFKReadyup.phrases");
	g_cvarDebug		   = CreateConVar("sm_afk_debug", "0", "Debug messages", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarEnable	   = CreateConVar("sm_afk_enable", "1", "Activate the plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarPlayerIgnore = CreateConVar("sm_afk_ignore", "1", "Ignore players ready", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarTime		   = CreateConVar("sm_afk_time", "40", "Time to move players", FCVAR_NOTIFY, true, 0.0);
	g_cvarReadyFooter  = CreateConVar("sm_afk_footer", "1", "Show ready footer", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarShowTimer	   = CreateConVar("sm_afk_show", "10", "Show timer to players, 0 is disable", FCVAR_NOTIFY, true, 0.0);

	AutoExecConfig(false, "AFKReadyup");

	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);

	HookEvent("entity_shoved", Event_PlayerAction_Attacker);
	HookEvent("weapon_fire", Event_PlayerAction_UserID);
	HookEvent("weapon_reload", Event_PlayerAction_UserID);
	HookEvent("player_use", Event_PlayerAction_UserID);
	HookEvent("player_jump", Event_PlayerAction_UserID);
	HookEvent("player_team", Event_PlayerTeam);
}

Action Command_Say(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue || !g_bReadyUpAvailable || !IsInReady())
		return Plugin_Continue;

	if (!IsValidClientIndex(iClient) || !IsClientInGame(iClient) || IsFakeClient(iClient))
		return Plugin_Continue;

	ResetTimers(iClient);
	return Plugin_Continue;
}

public void OnPluginEnd()
{
	if (!g_cvarEnable.BoolValue)
		return;

	PrintDebug("Plugin End, timer null (%s)", (g_hStartTimerAFK != null) ? "true" : "false");

	if (g_hStartTimerAFK != null)
		delete g_hStartTimerAFK;
}

public void OnMapEnd()
{
	/*
	 * Sometimes the event 'round_start' is called before OnMapStart()
	 * and the timer handle is not reset, so it's better to do it here.
	 */
	if (g_hStartTimerAFK != null)
		delete g_hStartTimerAFK;
}

/*****************************************************************
			F O R W A R D   P L U G I N S
*****************************************************************/

public OnReadyUpInitiate()
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (g_cvarReadyFooter.BoolValue)
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "%T", "Footer", LANG_SERVER, g_cvarTime.IntValue);
		AddStringToReadyFooter("");
		AddStringToReadyFooter(sBuffer);
	}

	if (g_hStartTimerAFK != null)
		delete g_hStartTimerAFK;

	g_hStartTimerAFK = CreateTimer(1.0, Timer_CheckAFK, _, TIMER_REPEAT);
}

public OnRoundIsLive()
{
	if (!g_cvarEnable.BoolValue)
		return;

	PrintDebug("Round is Live, timer null (%s)", (g_hStartTimerAFK != null) ? "true" : "false");

	if (g_hStartTimerAFK != null)
		delete g_hStartTimerAFK;

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;

		ResetTimers(iClient);
	}
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

void Event_PlayerAction_Attacker(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvarEnable.BoolValue || !g_bReadyUpAvailable || !IsInReady())
		return;

	int iClient = GetClientOfUserId(hEvent.GetInt("attacker"));
	if (!IsValidClientIndex(iClient) || !IsClientInGame(iClient) || IsFakeClient(iClient))
		return;

	ResetTimers(iClient);
}

void Event_PlayerAction_UserID(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvarEnable.BoolValue || !g_bReadyUpAvailable || !IsInReady())
		return;

	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!IsValidClientIndex(iClient) || !IsClientInGame(iClient) || IsFakeClient(iClient))
		return;

	ResetTimers(iClient);
}

void Event_PlayerTeam(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvarEnable.BoolValue || !g_bReadyUpAvailable || !IsInReady())
		return;

	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!IsClientInGame(iClient) || IsFakeClient(iClient))
		return;

	L4DTeam Team = view_as<L4DTeam>(GetEventInt(hEvent, "team"));
	if (Team == L4DTeam_Survivor || Team == L4DTeam_Infected)
		ResetTimers(iClient, false);
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

Action Timer_CheckAFK(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (!CheckTeam(i))
			continue;

		if (g_cvarPlayerIgnore.BoolValue && IsReady(i))
			continue;

		if (g_cvarShowTimer.BoolValue && g_iPlayerAFK[i] <= g_cvarShowTimer.IntValue)
			CPrintToChat(i, "%t %t", "Tag", "ShowTimer", g_iPlayerAFK[i]);

		if (PlayerPositionChanged(i))
		{
			ResetTimers(i, false);
			continue;
		}

		if (PlayerEyesChanged(i))
		{
			ResetTimers(i, false);
			continue;
		}

		g_iPlayerAFK[i] = g_iPlayerAFK[i] - 1;

		if (g_iPlayerAFK[i] > 0)
			continue;

		L4D_ChangeClientTeam(i, L4DTeam_Spectator);
		CPrintToChatAll("%t %t", "Tag", "MoveToSpec", i);
	}
	return Plugin_Continue;
}

/**
 * Checks the team of a client.
 *
 * @param iClient The client index.
 * @return True if the client is on the Survivor or Infected team, false otherwise.
 */
bool CheckTeam(int iClient)
{
	L4DTeam Team = L4D_GetClientTeam(iClient);
	return Team == L4DTeam_Survivor || Team == L4DTeam_Infected;
}

/**
 * Checks if the position of a player has changed.
 *
 * @param iClient The client index of the player.
 * @return True if the player's position has changed by more than 80 units, false otherwise.
 */
bool PlayerPositionChanged(int iClient)
{
	float fPos[3];
	GetClientAbsOrigin(iClient, fPos);
	return GetVectorDistance(fPos, g_fPlayerLastPos[iClient]) > 80.0;
}

/**
 * Checks if the eyes of a player have changed.
 *
 * @param iClient The client index of the player.
 * @return True if the eyes have changed, false otherwise.
 */
bool PlayerEyesChanged(int iClient)
{
	float fEyes[3];
	GetClientEyeAngles(iClient, fEyes);
	return fEyes[0] != g_fPlayerLastEyes[iClient][0] && fEyes[1] != g_fPlayerLastEyes[iClient][1];
}

/**
 * Resets the timers for a client.
 *
 * @param iClient The client index.
 * @param bCheckTeam Whether to check the client's team before resetting the timers. Default is true.
 */
void ResetTimers(int iClient, bool bCheckTeam = true)
{
	if (bCheckTeam && !CheckTeam(iClient))
		return;

	g_iPlayerAFK[iClient] = g_cvarTime.IntValue;
	GetClientAbsOrigin(iClient, g_fPlayerLastPos[iClient]);
	GetClientEyeAngles(iClient, g_fPlayerLastEyes[iClient]);
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
 * Returns the clients team using L4DTeam.
 *
 * @param client		Player's index.
 * @return				Current L4DTeam of player.
 * @error				Invalid client index.
 */
stock L4DTeam L4D_GetClientTeam(int client)
{
	int team = GetClientTeam(client);
	return view_as<L4DTeam>(team);
}

/**
 * Changes the team of a client in Left 4 Dead.
 *
 * @param client The client index.
 * @param team The new team for the client.
 */
stock void L4D_ChangeClientTeam(int client, L4DTeam team)
{
	ChangeClientTeam(client, view_as<int>(team));
}

/**
 * Checks if a client index is valid.
 *
 * @param client The client index to check.
 */
stock bool IsValidClientIndex(int iClient)
{
	return iClient > 0 && iClient <= MaxClients;
}

/**
 * Prints a debug message to the server console.
 *
 * @param sMessage The message to be printed.
 * @param ... Additional arguments to be formatted into the message.
 */
void PrintDebug(const char[] sMessage, any...)
{
	if (!g_cvarDebug.BoolValue)
		return;

	static char sFormat[512];
	VFormat(sFormat, sizeof(sFormat), sMessage, 2);

	PrintToServer("[AFK] %s", sFormat);
}

// =======================================================================================
// Bibliography
// https://developer.valvesoftware.com/wiki/List_of_L4D2_Cvars
// https://wiki.alliedmods.net/Generic_Source_Events
// https://wiki.alliedmods.net/Left_4_dead_2_events
// https://github.com/fbef0102/L4D1_2-Plugins/blob/master/L4DVSAutoSpectateOnAFK/scripting/L4DVSAutoSpectateOnAFK.sp
// =======================================================================================