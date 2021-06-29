#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <SteamWorks>

#pragma semicolon 1
#pragma newdecls required

char g_ip[100];
char g_port[10];

Database DB = null;

public Plugin myinfo = 
{
	name = "[CSGO] Mysql player information", 
	author = "TheFlyingApple", 
	description = "Saves player SteamID, prime, Name and IP, Join Date and Lastseen Date", 
	version = "1.1"
};

public void OnPluginStart()
{
	GetConVarString(FindConVar("ip"), g_ip, sizeof(g_ip));
	GetConVarString(FindConVar("hostport"), g_port, sizeof(g_port));
	if(DB == null)
		SQL_DBConnect();
}

public void OnConfigsExecuted() 
{
	GetConVarString(FindConVar("ip"), g_ip, sizeof(g_ip));
	GetConVarString(FindConVar("hostport"), g_port, sizeof(g_port));
	if(DB == null)
		SQL_DBConnect();
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidClient(client))
	{
		char steamid[32], query[1024];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		
		FormatEx(query, sizeof(query), "SELECT name FROM firstjoin WHERE auth = '%s' AND serverIp = '%s' AND serverPort = '%s';", steamid, g_ip, g_port);
		DB.Query(CheckPlayer_Callback, query, GetClientSerial(client));
	}
}

public void CheckPlayer_Callback(Database db, DBResultSet result, char[] error, any data)
{
	if(result == null)
	{
		LogError("[FirstJoin] Query Fail: %s", error);
		return;
	}

	int id = GetClientFromSerial(data);

	if(!id)
		return;
		
	if (result.FetchRow())
	{
		updateName(id);
		return;
	}
	
	char userName[MAX_NAME_LENGTH], steamid[32], ip[32];
	GetClientName(id, userName, sizeof(userName));
	GetClientAuthId(id, AuthId_Steam2, steamid, sizeof(steamid));
	GetClientIP(id, ip, sizeof(ip));
	
	int len = strlen(userName) * 2 + 1;
	char[] escapedName = new char[len];
	DB.Escape(userName, escapedName, len);

	len = strlen(steamid) * 2 + 1;
	char[] escapedSteamId = new char[len];
	DB.Escape(steamid, escapedSteamId, len);

	bool isPrime = k_EUserHasLicenseResultDoesNotHaveLicense == SteamWorks_HasLicenseForApp(id, 624820) ? 0 : 1;
	
	char query[512], time[32];
	FormatTime(time, sizeof(time), "%d-%m-%Y", GetTime());
	Format(query, sizeof(query), "INSERT INTO `firstjoin` (serverIp, serverPort, name, auth, ip, isPrime, joindate, lastseen) VALUES ('%s', '%s', '%s', '%s', '%s', '%i', '%s', '%s') ON DUPLICATE KEY UPDATE name = '%s';", g_ip, g_port, escapedName, escapedSteamId, ip, isPrime, time, time, escapedName);
	DB.Query(Nothing_Callback, query, id);
}

void updateName(int client)
{
	char userName[MAX_NAME_LENGTH], steamid[32];
	GetClientName(client, userName, sizeof(userName));
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	int len = strlen(userName) * 2 + 1;
	char[] escapedName = new char[len];
	DB.Escape(userName, escapedName, len);

	len = strlen(steamid) * 2 + 1;
	char[] escapedSteamId = new char[len];
	DB.Escape(steamid, escapedSteamId, len);

	bool isPrime = k_EUserHasLicenseResultDoesNotHaveLicense == SteamWorks_HasLicenseForApp(client, 624820) ? 0 : 1;

	char query[512], time[32];
	FormatTime(time, sizeof(time), "%d-%m-%Y", GetTime());
	FormatEx(query, sizeof(query), "UPDATE `firstjoin` SET name = '%s', isPrime = '%i', lastseen = '%s' WHERE auth = '%s' AND serverIp = '%s' AND serverPort = '%s';", escapedName, isPrime, time, escapedSteamId, g_ip, g_port);
	DB.Query(Nothing_Callback, query, client);
}

void SQL_DBConnect()
{
	if(DB != null)
		delete DB;
		
	if(SQL_CheckConfig("firstjoin"))
	{
		Database.Connect(SQLConnection_Callback, "firstjoin");
	}
	else
	{
		LogError("[FirstJoin] Startup failed. Error: %s", "\"firstjoin\" is not a specified entry in databases.cfg.");
	}
}


public void SQLConnection_Callback(Database db, char[] error, any data)
{
	if(db == null)
	{
		LogError("[FirstJoin] Can't connect to server. Error: %s", error);
		return;
	}		
	DB = db;
	DB.Query(Nothing_Callback, "CREATE TABLE IF NOT EXISTS `firstjoin` (`id` INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,`serverIp` varchar(100) NOT NULL,`serverPort` varchar(64) NOT NULL,`name` varchar(64) NOT NULL,`auth` varchar(32) NOT NULL,`ip` varchar(32) NOT NULL,`joindate` varchar(32) NOT NULL,`lastseen` varchar(32) NOT NULL) ENGINE = MyISAM DEFAULT CHARSET = utf8;", DBPrio_High);
}

public void Nothing_Callback(Database db, DBResultSet result, char[] error, any data)
{
	if(result == null)
		LogError("[FirstJoin] Error: %s", error);
}

stock bool IsValidClient(int client)
{
	if((1 <= client <= MaxClients) && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
		return true;
	return false;
}