#if defined _callvotekicklimit_sql_included
	#endinput
#endif
#define _callvotekicklimit_sql_included

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

ConVar
	g_cvarSQL;

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/
public void OnPluginStart_SQL()
{
	g_cvarSQL = CreateConVar("sm_cvkl_sql", "0", "Enables kick counter registration to the database, if disabled it uses local memory.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	RegAdminCmd("sm_cvkl_sql_install", Command_CreateSQL, ADMFLAG_ROOT, "Install SQL tables");

	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), DIR_CALLVOTE);
	g_hDatabase = Connect("callvote");
}

Action Command_CreateSQL(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	char sQuery[600];
	Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `callvote_kicklimit` ( \
        `id` int(6) NOT NULL auto_increment, \
        `authid` varchar(64) character set utf8 NOT NULL default '' COMMENT 'Client calling for a vote', \
        `created` int(11) NOT NULL default '0' COMMENT 'Creation date in unix format', \
        `authidTarget` varchar(64) character set utf8 NOT NULL default '' COMMENT 'Objective of a kick vote', \
        PRIMARY KEY(`id`)) \
		ENGINE = InnoDB DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci");

	if (!SQL_FastQuery(g_hDatabase, sQuery))
	{
		char sSQLError[255];
		SQL_GetError(g_hDatabase, sSQLError, sizeof(sSQLError));
		log(false, "SQL failed: %s", sSQLError);
		log(false, "Query: %s", sQuery);
		CReplyToCommand(iClient, "%t %t", "Tag", "DBQueryError");
		return Plugin_Handled;
	}

	CReplyToCommand(iClient, "%t %t", "Tag", "DBTableCreated");
	log(true, "%t Tables have been created.", "Tag");
	return Plugin_Handled;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

/**
 * Inserts a record into the `callvote_kicklimit` table in the database.
 *
 * @param sClientID The authid of the client initiating the vote.
 * @param sTargetID The authid of the target player being voted to be kicked.
 * @return True if the record was successfully inserted, false otherwise.
 */
bool sqlinsert(const char[] sClientID, const char[] sTargetID)
{
	if (!g_cvarSQL.BoolValue)
		return false;

	char sQuery[600];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `callvote_kicklimit` (`authid`, `created`, `authidTarget`) VALUES ('%s', '%d', '%s')", sClientID, GetTime(), sTargetID);

	if (!SQL_FastQuery(g_hDatabase, sQuery))
	{
		char sError[255];
		SQL_GetError(g_hDatabase, sError, sizeof(sError));
		log(false, "Query failed: %s", sError);
		log(false, "Query dump: %s", sQuery);
		return false;
	}

	return true;
}

/**
 * Retrieves the count of kick votes for a specific client and SteamID within the last 24 hours.
 *
 * @param iClient The client index.
 * @param sSteamID The SteamID of the client.
 */
void GetCountKick(int iClient, const char[] sSteamID)
{
	char sQuery[255];

	g_hDatabase.Format(sQuery, sizeof(sQuery), "SELECT COUNT(*) FROM callvote_kicklimit WHERE created >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 DAY)) AND authid = '%s';", sSteamID);
	g_hDatabase.Query(CallBack_GetCountKick, sQuery, GetClientUserId(iClient));
}

/**
 * Callback function for retrieving the count of kicks from the database.
 *
 * @param db The database connection.
 * @param results The result set containing the count of kicks.
 * @param error The error message, if any.
 * @param data The user ID associated with the client.
 */
public void CallBack_GetCountKick(Database db, DBResultSet results, const char[] error, any data)
{
	int iClient = GetClientOfUserId(data);
	if (iClient == CONSOLE)
		return;

	int iKick;

	if (results == null)
		ThrowError("Error: %s", error);

	if (results.FetchRow())
	{
		iKick = results.FetchInt(0);
	}

	g_Players[iClient].Kick = iKick;
	if (!iKick)
		IsNewClient(iClient);
}
