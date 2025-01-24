/*
* 
* Auto Recorder
* http://forums.alliedmods.net/showthread.php?t=92072
* 
* Description:
* Automates SourceTV recording based on player count
* and time of day. Also allows admins to manually record.
* 
* Changelog
* May 09, 2009 - v.1.0.0:
*   [*] Initial Release
* May 11, 2009 - v.1.1.0:
*   [+] Added path cvar to control where demos are stored
*   [*] Changed manual recording to override automatic recording
*   [+] Added seconds to demo names
* May 04, 2016 - v.1.1.1:
*   [*] Changed demo file names to replace slashes with hyphens [ajmadsen]
* Aug 26, 2016 - v.1.2.0:
*   [*] Now ignores bots in the player count by default
*   [*] The SourceTV client is now always ignored in the player count
*   [+] Added sm_autorecord_ignorebots to control whether to ignore bots
*   [*] Now checks the status of the server immediately when a setting is changed
* Jun 21, 2017 - v.1.3.0:
*   [*] Fixed minimum player count setting being off by one
*   [*] Fixed player counting code getting out of range
*   [*] Updated source code to the new syntax
* Apr 15, 2022 - v.1.3.1:
*   [*] Increased the length limit of the map name in the demo filename
*   [*] Fixed workshop map demo filenames missing the .dem extension
* Sept 28, 2023 - v.1.4.0:
*   [*] Add forwards and natives for API usage
*   [*] Small code improvements
* Sept 11, 2024 - v.1.4.1:
*	[*] Make timer check every 5 seconds instead of 300
*	[*] Add sm_autorecord_checkstatus to control whether to check status automatically
* Jan 19, 2025 - v.1.4.2:
*	[*] Add forward to check if plugin is available
* 
*/

#include <sourcemod>
#include <AutoRecorder>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Auto Recorder",
	author = "Stevo.TVR, inGame, maxime1907, .Rushaway",
	description = "Automates SourceTV recording based on player count and time of day.",
	version = AutoRecorder_VERSION,
	url = "http://www.theville.org"
}

GlobalForward g_hForward_StatusOK;
GlobalForward g_hForward_StatusNotOK;

Handle g_hFwd_OnStartRecord;
Handle g_hFwd_OnStopRecord;

ConVar g_hTvEnabled = null;
ConVar g_hAutoRecord = null;
ConVar g_hMinPlayersStart = null;
ConVar g_hIgnoreBots = null;
ConVar g_hTimeStart = null;
ConVar g_hTimeStop = null;
ConVar g_hFinishMap = null;
ConVar g_hDemoPath = null;
ConVar g_hCheckStatus = null;

bool g_bRestartRecording = false;
bool g_bIsRecording = false;
bool g_bIsManual = false;

int g_iRestartRecording;
int g_iRecordingFromTick;
int g_iRecordingDemoCount;
int g_iTimestamp;

char g_sPath[PLATFORM_MAX_PATH];
char g_sDemoName[PLATFORM_MAX_PATH];
char g_sFileName[PLATFORM_MAX_PATH * 2];
char g_sTime[16];
char g_sMap[48];


// Default: o=rx,g=rx,u=rwx | 755
#define DIRECTORY_PERMISSIONS (FPERM_O_READ|FPERM_O_EXEC | FPERM_G_READ|FPERM_G_EXEC | FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC)

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("AutoRecorder_IsDemoRecording", Native_IsDemoRecording);
	CreateNative("AutoRecorder_GetDemoRecordCount", Native_GetDemoRecordCount);
	CreateNative("AutoRecorder_GetDemoRecordingMap", Native_GetDemoRecordingMap);
	CreateNative("AutoRecorder_GetDemoRecordingTick", Native_GetDemoRecordingTick);
	CreateNative("AutoRecorder_GetDemoRecordingName", Native_GetDemoRecordingName);
	CreateNative("AutoRecorder_GetDemoRecordingTime", Native_GetDemoRecordingTime);

	g_hForward_StatusOK = CreateGlobalForward("AutoRecorder_OnPluginOK", ET_Ignore);
	g_hForward_StatusNotOK = CreateGlobalForward("AutoRecorder_OnPluginNotOK", ET_Ignore);

	g_hFwd_OnStartRecord = CreateGlobalForward("AutoRecorder_OnStartRecord", ET_Ignore, Param_String, Param_String, Param_String, Param_Cell, Param_String);
	g_hFwd_OnStopRecord = CreateGlobalForward("AutoRecorder_OnStopRecord", ET_Ignore, Param_String, Param_String, Param_String, Param_Cell, Param_String);

	RegPluginLibrary("AutoRecorder");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hAutoRecord = CreateConVar("sm_autorecord_enable", "1", "Enable automatic recording", _, true, 0.0, true, 1.0);
	g_hMinPlayersStart = CreateConVar("sm_autorecord_minplayers", "4", "Minimum players on server to start recording", _, true, 0.0);
	g_hIgnoreBots = CreateConVar("sm_autorecord_ignorebots", "1", "Ignore bots in the player count", _, true, 0.0, true, 1.0);
	g_hTimeStart = CreateConVar("sm_autorecord_timestart", "-1", "Hour in the day to start recording (0-23, -1 disables)");
	g_hTimeStop = CreateConVar("sm_autorecord_timestop", "-1", "Hour in the day to stop recording (0-23, -1 disables)");
	g_hFinishMap = CreateConVar("sm_autorecord_finishmap", "1", "If 1, continue recording until the map ends", _, true, 0.0, true, 1.0);
	g_hDemoPath = CreateConVar("sm_autorecord_path", "demos", "Path to store recorded demos");
	g_hCheckStatus = CreateConVar("sm_autorecord_checkstatus", "1", "Automatically check if all conditions are met to start recording", _, true, 0.0, true, 1.0);

	AutoExecConfig(true);

	RegAdminCmd("sm_record", Command_Record, ADMFLAG_ROOT, "Starts a SourceTV demo");
	RegAdminCmd("sm_stoprecord", Command_StopRecord, ADMFLAG_ROOT, "Stops the current SourceTV demo");

	HookEvent("round_start", OnRoundStart);

	g_hTvEnabled = FindConVar("tv_enable");

	g_hDemoPath.GetString(g_sPath, sizeof(g_sPath));
	if(!DirExists(g_sPath))
	{
		InitDirectory(g_sPath);
	}

	g_hMinPlayersStart.AddChangeHook(OnConVarChanged);
	g_hIgnoreBots.AddChangeHook(OnConVarChanged);
	g_hTimeStart.AddChangeHook(OnConVarChanged);
	g_hTimeStop.AddChangeHook(OnConVarChanged);
	g_hDemoPath.AddChangeHook(OnConVarChanged);

	CreateTimer(5.0, Timer_CheckStatus, _, TIMER_REPEAT);

	CleanUp();
	StopRecord();
	CheckStatus();
}

public void OnAllPluginsLoaded()
{
	SendForward_Available();
}

public void OnPluginPauseChange(bool pause)
{
	if (pause)
		SendForward_NotAvailable();
	else
		SendForward_Available();
}

public void OnPluginEnd()
{
	SendForward_NotAvailable();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char [] newValue)
{
	if(convar == g_hDemoPath)
	{
		if(!DirExists(newValue))
		{
			InitDirectory(newValue);
		}
	}
	else
	{
		CheckStatus();
	}
}

public void OnRoundStart(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	if(g_bRestartRecording && g_iRestartRecording <= GetTime())
	{
		StopRecord();
		CheckStatus();
	}
}

public void OnMapStart()
{
	g_iRecordingDemoCount = 0;
	GetCurrentMap(g_sMap, sizeof(g_sMap));
	// replace slashes in map path name with dashes, to prevent fail on workshop maps
	ReplaceString(g_sMap, sizeof(g_sMap), "/", "-", false);
	// replace periods in map path name with underscores, so workshop map demos still get a .dem extension
	ReplaceString(g_sMap, sizeof(g_sMap), ".", "_", false);
}

public void OnMapEnd()
{
	if(g_bIsRecording)
	{
		StopRecord();
		CleanUp();
	}
}

public void OnClientPutInServer(int client)
{
	CheckStatus();
}

public void OnClientDisconnect_Post(int client)
{
	CheckStatus();
}

public Action Timer_CheckStatus(Handle timer)
{
	if (g_hCheckStatus.BoolValue)
		CheckStatus();

	return Plugin_Continue;
}

public Action Command_Record(int client, int args)
{
	if(g_bIsRecording)
	{
		ReplyToCommand(client, "[SM] SourceTV is already recording!");
		return Plugin_Handled;
	}

	if (!StartRecord())
	{
		ReplyToCommand(client, "[SM] Cannot start recording.");
		return Plugin_Handled;
	}

	g_bIsManual = true;

	ReplyToCommand(client, "[SM] SourceTV is now recording...");
	LogAction(-1, -1, "\"%L\" manually started recording demo on SourceTV.", client);

	return Plugin_Handled;
}

public Action Command_StopRecord(int client, int args)
{
	if(!g_bIsRecording)
	{
		ReplyToCommand(client, "[SM] SourceTV is not recording!");
		return Plugin_Handled;
	}

	StopRecord();

	if(g_bIsManual)
	{
		g_bIsManual = false;
		CheckStatus();
	}

	ReplyToCommand(client, "[SM] Stopped recording.");
	LogAction(-1, -1, "\"%L\" manually stopped recording demo on SourceTV.", client);

	return Plugin_Handled;
}

void CheckStatus()
{
	if(g_hAutoRecord.BoolValue && !g_bIsManual)
	{
		int iMinClients = g_hMinPlayersStart.IntValue;

		int iTimeStart = g_hTimeStart.IntValue;
		int iTimeStop = g_hTimeStop.IntValue;
		bool bReverseTimes = (iTimeStart > iTimeStop);

		char sCurrentTime[4];
		FormatTime(sCurrentTime, sizeof(sCurrentTime), "%H", GetTime());
		int iCurrentTime = StringToInt(sCurrentTime);

		if(GetPlayerCount() >= iMinClients && (iTimeStart < 0 || (iCurrentTime >= iTimeStart && (bReverseTimes || iCurrentTime < iTimeStop))))
		{
			StartRecord();
		}
		else if(g_bIsRecording && !g_hFinishMap.BoolValue && (iTimeStop < 0 || iCurrentTime >= iTimeStop))
		{
			StopRecord();
		}
	}
}

int GetPlayerCount()
{
	bool bIgnoreBots = g_hIgnoreBots.BoolValue;

	int iNumPlayers = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && (!bIgnoreBots || !IsFakeClient(i)))
		{
			iNumPlayers++;
		}
	}

	if(!bIgnoreBots)
	{
		iNumPlayers--;
	}

	return iNumPlayers;
}

stock void GetPath(char[] buffer, int size)
{
	g_hDemoPath.GetString(buffer, size);
}

bool StartRecord()
{
	if(g_hTvEnabled.BoolValue && !g_bIsRecording)
	{
		bool bSourceTV = false;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientSourceTV(i))
			{
				bSourceTV = true;
				break;
			}
		}

		if (!bSourceTV)
			return false;

		GetPath(g_sPath, sizeof(g_sPath));

		g_iTimestamp = GetTime();
		FormatTime(g_sTime, sizeof(g_sTime), "%Y%m%d-%H%M%S", g_iTimestamp);
		Format(g_sDemoName, sizeof(g_sDemoName), "auto-%s-%s", g_sTime, g_sMap);
		Format(g_sFileName, sizeof(g_sFileName), "%s.dem", g_sDemoName);

		ServerCommand("tv_record \"%s/%s\"", g_sPath, g_sDemoName);
		g_iRecordingFromTick = GetGameTickCount();
		g_bIsRecording = true;
		g_bRestartRecording = true;
		g_iRestartRecording = g_iTimestamp + 1800;
		g_iRecordingDemoCount++;

		LogMessage("Recording to \"%s/%s\"", g_sPath, g_sFileName);

		Call_StartForward(g_hFwd_OnStartRecord);
		Call_PushString(g_sPath);
		Call_PushString(g_sMap);
		Call_PushString(g_sTime);
		Call_PushCell(g_iRecordingDemoCount);
		Call_PushString(g_sFileName);
		Call_Finish();

		return true;
	}

	return false;
}

void StopRecord()
{
	if(g_hTvEnabled.BoolValue && g_bIsRecording)
	{
		ServerCommand("tv_stoprecord");

		GetPath(g_sPath, sizeof(g_sPath));
		Call_StartForward(g_hFwd_OnStopRecord);
		Call_PushString(g_sPath);
		Call_PushString(g_sMap);
		Call_PushString(g_sTime);
		Call_PushCell(g_iRecordingDemoCount);
		Call_PushString(g_sFileName);
		Call_Finish();

		CleanUp();
	}
}

void CleanUp()
{
	g_bIsRecording = false;
	g_bRestartRecording = false;
	g_iRestartRecording = -1;
	g_iRecordingFromTick = -1;
	g_sTime = "\0";
	g_sDemoName = "\0";
	g_sFileName = "\0";
}

void InitDirectory(const char[] sDir)
{
	char sPieces[32][PLATFORM_MAX_PATH];
	int iNumPieces = ExplodeString(sDir, "/", sPieces, sizeof(sPieces), sizeof(sPieces[]));

	for(int i = 0; i < iNumPieces; i++)
	{
		Format(g_sPath, sizeof(g_sPath), "%s/%s", g_sPath, sPieces[i]);
		if(!DirExists(g_sPath))
		{
			CreateDirectory(g_sPath, DIRECTORY_PERMISSIONS);
		}
	}
}

public int Native_GetDemoRecordCount(Handle hPlugin, int numParams)
{
	return g_iRecordingDemoCount;
}

public int Native_IsDemoRecording(Handle hPlugin, int numParams)
{
	return g_bIsRecording;
}

public int Native_GetDemoRecordingTick(Handle hPlugin, int numParams)
{
	if (!g_bIsRecording)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "SourceTV is not recording!");
		return -1;
	}

	return GetGameTickCount() - g_iRecordingFromTick;
}

public int Native_GetDemoRecordingName(Handle hPlugin, int numParams)
{
	if (!g_bIsRecording)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "SourceTV is not recording!");
		return -1;
	}

	int maxlen = GetNativeCell(2);
	SetNativeString(1, g_sDemoName, maxlen);
	return 1;
}

public int Native_GetDemoRecordingTime(Handle hPlugin, int numParams)
{
	if (!g_bIsRecording)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "SourceTV is not recording!");
		return -1;
	}

	return g_iTimestamp;
}

public int Native_GetDemoRecordingMap(Handle hPlugin, int numParams)
{
	if (!g_bIsRecording)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "SourceTV is not recording!");
		return -1;
	}

	int maxlen = GetNativeCell(2);
	SetNativeString(1, g_sMap, maxlen);
	return 1;
}

stock void SendForward_Available()
{
	Call_StartForward(g_hForward_StatusOK);
	Call_Finish();
}

stock void SendForward_NotAvailable()
{
	Call_StartForward(g_hForward_StatusNotOK);
	Call_Finish();
}
