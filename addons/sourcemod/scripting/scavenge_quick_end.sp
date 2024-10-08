#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_gamerules>
#include <colors>

// We must wait longer because of cases where the game doesn't
// do the compare at the same time as us.
#define SAFETY_BUFFER_TIME 1.0

float
	g_flDefaultLossTime;

bool
	g_bInScavengeRound,
	g_bInSecondHalf;

ConVar
	g_hcvarQuickEndSwitch;

enum EndType
{
	QE_SameTargetCompareUsedTime,
	QE_AchievedTargetSetDeadLine,
	QE_WhoSurvivedLonger,
	QE_None
}

EndType g_eEndType;

// GetRoundTime(&minutes, &seconds, team)
#define GetRoundTime(%0,%1,%2) %1 = GetScavengeRoundDuration(%2); %0 = RoundToFloor(%1)/60; %1 -= 60 * %0

public Plugin myinfo =
{
	name		= "[L4D2] Scavenge Quick End",
	author		= "ProdigySim, blueblur",
	description = "Checks various tiebreaker win conditions mid-round and ends the round as necessary.",
	version		= "3.1.2",
	url			= "https://github.com/blueblur0730/modified-plugins"
};

public void OnPluginStart()
{
	g_hcvarQuickEndSwitch = CreateConVar("l4d2_enable_scavenge_quick_end", "1", "Only enable quick end or not, Printing time is not included by this cvar", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	HookEvent("gascan_pour_completed", Event_GascanPourCompleted, EventHookMode_PostNoCopy);
	HookEvent("scavenge_round_start", Event_ScavRoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	LoadTranslation("scavenge_quick_end.phrases");

	RegConsoleCmd("sm_time", Cmd_QuaryTime);
}

//--------
//	Cmd
//--------
public Action Cmd_QuaryTime(int client, any args)
{
	if (!g_bInScavengeRound)
		return Plugin_Handled;

	int iRoundNumber = GameRules_GetProp("m_nRoundNumber");
	if (g_bInSecondHalf)
	{
		int	  iLastRoundMinutes;
		float fLastRoundTime;
		GetRoundTime(iLastRoundMinutes, fLastRoundTime, 3);

		CPrintToChat(client, "%t %t", "Tag", "PrintRoundTime", iRoundNumber, GetScavengeTeamScore(3, iRoundNumber), iLastRoundMinutes, fLastRoundTime);
	}

	int	  iThisRoundMinutes;
	float fThisRoundTime;
	GetRoundTime(iThisRoundMinutes, fThisRoundTime, 2);

	if (g_bInSecondHalf)
		CPrintToChat(client, "%t %t", "Tag", "PrintRoundTimeInHalf", iRoundNumber, GetScavengeTeamScore(2, iRoundNumber), iThisRoundMinutes, fThisRoundTime);
	else
		CPrintToChat(client, "%t %t", "Tag", "PrintRoundTime", iRoundNumber, GetScavengeTeamScore(2, iRoundNumber), iThisRoundMinutes, fThisRoundTime);

	return Plugin_Handled;
}

//----------
//	Events
//----------
public void Event_RoundEnd(Event hEvent, const char[] name, bool dontBroadcast)
{
	if (g_bInScavengeRound)
		PrintRoundEndTimeData(g_bInSecondHalf);

	g_flDefaultLossTime = 0.0;
	g_bInScavengeRound	= false;
	g_bInSecondHalf		= false;
}

public void Event_ScavRoundStart(Event hEvent, const char[] name, bool dontBroadcast)
{
	g_bInSecondHalf		= !hEvent.GetBool("firsthalf");
	g_bInScavengeRound	= true;
	g_flDefaultLossTime = 0.0;
	g_eEndType			= QE_None;

	if (g_bInScavengeRound && g_bInSecondHalf)
	{
		int iScavengeItemsGoal = GameRules_GetProp("m_nScavengeItemsGoal");
		// fully completed or totally lost?
		if (GetScavengeTeamScore(3) == iScavengeItemsGoal)
			g_eEndType = QE_AchievedTargetSetDeadLine;
		else if (GetScavengeTeamScore(3) == 0)
			g_eEndType = QE_WhoSurvivedLonger;

		// record the loss dead line.
		if (GetScavengeTeamScore(3) == iScavengeItemsGoal || GetScavengeTeamScore(3) == 0)
			g_flDefaultLossTime = GameRules_GetPropFloat("m_flRoundStartTime") + GetScavengeRoundDuration(3) + SAFETY_BUFFER_TIME;
	}
}

public void Event_GascanPourCompleted(Event hEvent, const char[] name, bool dontBroadcast)
{
	if (g_bInScavengeRound && g_bInSecondHalf)
	{
		if (GameRules_GetProp("m_nScavengeItemsRemaining") > 0)
		{
			// Same Target Compare Time
			if (GetScavengeTeamScore(2) == GetScavengeTeamScore(3) && GetScavengeRoundDuration(2) < GetScavengeRoundDuration(3))
			{
				g_eEndType = QE_SameTargetCompareUsedTime;
				EndRoundEarlyOnTime(1);
			}
		}
	}
}

//-----------
//	Actions
//-----------
public void OnGameFrame()
{
	if (g_flDefaultLossTime != 0.0 && GetGameTime() > g_flDefaultLossTime)
	{
		g_eEndType = QE_AchievedTargetSetDeadLine;
		EndRoundEarlyOnTime(1);
		g_flDefaultLossTime = 0.0;
	}
}

public void PrintRoundEndTimeData(bool bSecondHalf)
{
	int	  iLastRoundMinutes;
	float fLastRoundTime;
	int iRoundNumber = GameRules_GetProp("m_nRoundNumber");

	if (bSecondHalf)
	{
		GetRoundTime(iLastRoundMinutes, fLastRoundTime, 3);
		CPrintToChatAll("%t %t", "Tag", "PrintRoundEndTime", iRoundNumber, GetScavengeTeamScore(3, iRoundNumber), iLastRoundMinutes, fLastRoundTime);
	}

	int	  iThisRoundMinutes;
	float fThisRoundTime;
	GetRoundTime(iThisRoundMinutes, fThisRoundTime, 2);
	if (bSecondHalf)
		CPrintToChatAll("%t %t", "Tag", "PrintRoundEndTimeInHalf", iRoundNumber, GetScavengeTeamScore(2, iRoundNumber), iThisRoundMinutes, fThisRoundTime);
	else
		CPrintToChatAll("%t %t", "Tag", "PrintRoundEndTime", iRoundNumber, GetScavengeTeamScore(2, iRoundNumber), iThisRoundMinutes, fThisRoundTime);
}

public Action EndRoundEarlyOnTime(int client)
{
	if (!g_hcvarQuickEndSwitch.BoolValue)	 // check enabled quick end or not
		return Plugin_Handled;

	int oldFlags = GetCommandFlags("scenario_end");
	// FCVAR_LAUNCHER is actually FCVAR_DEVONLY`
	SetCommandFlags("scenario_end", oldFlags & ~(FCVAR_CHEAT | FCVAR_DEVELOPMENTONLY));
	ServerCommand("scenario_end");
	ServerExecute();
	SetCommandFlags("scenario_end", oldFlags);

	switch (g_eEndType)
	{
		case QE_SameTargetCompareUsedTime: CPrintToChatAll("%t %t", "Tag", "RoundEndEarly_Type1");
		case QE_AchievedTargetSetDeadLine: CPrintToChatAll("%t %t", "Tag", "RoundEndEarly_Type2");
		case QE_WhoSurvivedLonger: CPrintToChatAll("%t %t", "Tag", "RoundEndEarly_Type3");
	}

	return Plugin_Handled;
}

//-----------
//	Stocks
//-----------


/*
 * Returns the team score of this round.
 *
 * @param team 		team number to return. valid value is 2 and 3
 * @param round		current round number. default value is -1
 * @return 			the team score of this round. invalide team number will return -1.
 */
stock int GetScavengeTeamScore(int team, int round = -1)
{
	team = L4D2_TeamNumberToTeamIndex(team);
	if (team == -1) return -1;

	if (round <= 0 || round > 5)
	{
		round = GameRules_GetProp("m_nRoundNumber");
	}

	return GameRules_GetProp("m_iScavengeTeamScore", _, (2 * (round - 1)) + team);
}

/*
 * Returns the float value of the this round duration.
 * If the round has not ended yet, returns the current duration.
 *
 * @param team		team number. valid value is 2 or 3
 * @return			float value of this round duration. invalide team number will return -1.0
 */
stock float GetScavengeRoundDuration(int team)
{
	float flRoundStartTime = GameRules_GetPropFloat("m_flRoundStartTime");
	if (team == 2 && flRoundStartTime != 0.0 && GameRules_GetPropFloat("m_flRoundEndTime") == 0.0)
	{
		// Survivor team still playing round.
		return GetGameTime() - flRoundStartTime;
	}

	team = L4D2_TeamNumberToTeamIndex(team);
	if (team == -1) return -1.0;

	return GameRules_GetPropFloat("m_flRoundDuration", team);
}

/*
 * Caculate a series of numbers
 *
 * @param minute	minute to set on a varible
 * @param second	seconds	passed on this minute that set on a varible
 * @param team		team number to get time
 *
 * @noreturn
 *
 */
/*
stock void GetRoundTime(int minute, float second, int team)
{
	minute = RoundToFloor(GetScavengeRoundDuration(team)) / 60;
	second -= minute * 60;
}
 */

/*
 * Convert "2" or "3" to "0" or "1" for global static indices.
 * Defaultly recongnise 2 as team survivors and 3 as team infected.
 *
 * @param team 		team number. valid value is 2 and 3.
 * @return 			1 if the team survivors flipped or team is infected,
 *  				0 if the team is survivors or team infected flipped,
 *  				-1 if the team number in invalide.
 */
stock int L4D2_TeamNumberToTeamIndex(int team)
{
	// must be team 2 or 3 for this stupid function
	if (team != 2 && team != 3) return -1;

	// Tooth table:
	// Team | Flipped | Correct index
	// 2	   0		 0
	// 2	   1		 1
	// 3	   0		 1
	// 3	   1		 0
	// index = (team & 1) ^ flipped
	// index = team-2 XOR flipped, or team%2 XOR flipped, or this...
	bool flipped = view_as<bool>(GameRules_GetProp("m_bAreTeamsFlipped", 1));
	if (flipped) ++team;
	return team % 2;
}

/**
 * Get winner number
 *
 * @param round 		round number to get
 *
 * @return 				1 if survivors won this round, 2 otherwise.
 */
stock int GetWinningTeam(int round)
{
	int survivor, infected;
	survivor = GetScavengeTeamScore(2, round);
	infected = GetScavengeTeamScore(3, round);

	return (survivor > infected) ? 1 : 2;
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