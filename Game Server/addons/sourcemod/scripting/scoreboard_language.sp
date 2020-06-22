#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <PTaH>

#pragma newdecls required
#pragma tabsize 4

#include <geoip>

#define SPPP_COMPILER 0

#if !SPPP_COMPILER
	#define decl static
#endif

int              g_iOldPersonaRank[MAXPLAYERS + 1],
                 g_iPersonaRank[MAXPLAYERS + 1],
                 m_pPersonaDataPublic;		// CEconPersonaDataPublic : GCSDK::CProtoBufSharedObject

static const int m_player_level_ = 16;		// CEconPersonaDataPublic::player_level_ (int) => 16

ArrayList        g_hFlagCodes,
                 g_hFlagIndexes;

GlobalForward    g_hForwardLevelChange;

// scoreboard_language.sp
public Plugin myinfo = 
{
	name = "[Scoreboard] Language",
	author = "Wend4r",
	version = "1.6.0",
	url = "Discord: Wend4r#0001 | VK: vk.com/wend4r"
}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] sError, int iErrorSize)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		strcopy(sError, iErrorSize, "This plugin works only on CS:GO");

		return APLRes_SilentFailure;
	}

	CreateNative("Scoreboard_SetPersonaLevel", Scoreboard_SetPersonaLevel);
	CreateNative("Scoreboard_GetPersonaLevel", Scoreboard_GetPersonaLevel);

	g_hForwardLevelChange = new GlobalForward("Scoreboard_LoadPersonaLevel", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

	RegPluginLibrary("scoreboard_language");

	return APLRes_Success;
}

int Scoreboard_SetPersonaLevel(Handle hPlugin, int iArgs)
{
	int iClient = GetNativeCell(1),
	    iLevel = GetNativeCell(2);

	if(GetNativeCell(3) || !g_iPersonaRank[iClient] || g_iPersonaRank[iClient] == 1500)
	{
		if(iLevel == -1)
		{
			iLevel = g_iOldPersonaRank[iClient];
		}

		SetPersonaLevel(iClient, iLevel);
	}
}

int Scoreboard_GetPersonaLevel(Handle hPlugin, int iArgs)
{
	int iClient = GetNativeCell(1);

	return GetNativeCell(2) ? g_iOldPersonaRank[iClient] : g_iPersonaRank[iClient];
}

public void OnPluginStart()
{
	/* in CCSPlayer struct side
		...
		CNetworkVarBase<unsigned short,CCSPlayer::NetworkVar_m_unMusicID> m_unMusicID;		// 2 bytes // ->
		bool m_bNeedToUpdateMusicFromInventory;		// 1 byte
		unsigned __int16 m_unEquippedPlayerSprayIDs[1];		// 2 bytes
		bool m_bNeedToUpdatePlayerSprayFromInventory;		// 1 byte
		CEconPersonaDataPublic *m_pPersonaDataPublic;		// pointer => 4 bytes // <-
		bool m_bNeedToUpdatePersonaDataPublicFromInventory;
		CNetworkVarBase<bool,CCSPlayer::NetworkVar_m_bIsScoped> m_bIsScoped;
		CNetworkVarBase<bool,CCSPlayer::NetworkVar_m_bIsWalking> m_bIsWalking;
		...
	*/

	m_pPersonaDataPublic = FindSendPropInfo("CCSPlayer", "m_unMusicID") + 10;		// 2 + 1 + 2 + 1 + 4. HARD OFFSET. OHH YEEE :D

	g_hFlagCodes = new ArrayList(2);		// char[8]
	g_hFlagIndexes = new ArrayList();		// int

	PTaH(PTaH_InventoryUpdatePost, Hook, OnInventoryUpdatePost);

	HookEvent("player_spawn", OnPlayerSpawn);
}

public void OnMapStart()
{
	static char sPath[PLATFORM_MAX_PATH];

	if(!sPath[0])
	{
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/scoreboard_language.ini");
	}

	decl char sBuffer[PLATFORM_MAX_PATH];

	SMCParser hParser = new SMCParser();

	hParser.OnKeyValue = OnSectionSettings;

	SMCError iError = hParser.ParseFile(sPath);

	if(iError != SMCError_Okay)
	{
		hParser.GetErrorString(iError, sBuffer, sizeof(sBuffer));
		SetFailState("%s - %s", sPath, sBuffer);
	}

	for(int i = 0, iLen = g_hFlagIndexes.Length; i != iLen; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "materials/panorama/images/icons/xp/level%i.png", g_hFlagIndexes.Get(i));
		AddFileToDownloadsTable(sBuffer);
	}

	for(int i = MaxClients + 1; --i;)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);

			if(!IsFakeClient(i))
			{
				SetPersonaLevel(i, g_iPersonaRank[i]);
				LoadFlags(i);
			}
		}
	}
}

SMCResult OnSectionSettings(SMCParser hParser, const char[] sKey, const char[] sValue, bool bKeyQuotes, bool bValueQuotes)
{
	g_hFlagCodes.PushString(sKey);
	g_hFlagIndexes.Push(StringToInt(sValue));
}

public void OnClientPutInServer(int iClient)
{
	if(!IsFakeClient(iClient))
	{
		decl char sCode[3], sIP[32];

		GetClientIP(iClient, sIP, sizeof(sIP));

		decl int iIndex;

		if(strncmp(sIP, "192.168.1", 9) && GeoipCode2(sIP, sCode) && (iIndex = g_hFlagCodes.FindString(sCode)))
		{
			g_iPersonaRank[iClient] = g_hFlagIndexes.Get(iIndex);
			
			return;
		}
		
		g_iPersonaRank[iClient] = (iIndex = g_hFlagCodes.FindString("none")) != -1 ? g_hFlagIndexes.Get(iIndex) : 0;
	}
}

void OnPlayerSpawn(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if(!hEvent.GetInt("teamnum"))
	{
		int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

		if(iClient && !IsFakeClient(iClient))
		{
			SDKHook(iClient, SDKHook_PostThinkPost, OnLoadClientPostThinkPost);
		}
	}
}

void OnLoadClientPostThinkPost(int iClient)
{
	LoadFlags(iClient);
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnLoadClientPostThinkPost);
}

void LoadFlags(const int &iClient)
{
	SetPersonaLevel(iClient, g_iPersonaRank[iClient]);

	Call_StartForward(g_hForwardLevelChange);
	Call_PushCell(iClient);
	Call_PushCell(g_iOldPersonaRank[iClient]);
	Call_PushCell(g_iPersonaRank[iClient]);
	Call_Finish();
}

void OnInventoryUpdatePost(int iClient, CCSPlayerInventory pInventory)
{
	SDKHook(iClient, SDKHook_PostThinkPost, OnClientPostThinkPost);
}

void OnClientPostThinkPost(int iClient)
{
	SetPersonaLevel(iClient, g_iPersonaRank[iClient]);
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnClientPostThinkPost);
}

void SetPersonaLevel(const int &iClient, const int &iLevel)
{
	// *m_pPersonaDataPublic -> player_level_ :

	Address pPersonaDataPublic = view_as<Address>(LoadFromAddress(GetEntityAddress(iClient) + view_as<Address>(m_pPersonaDataPublic), NumberType_Int32));

	if(pPersonaDataPublic)
	{
		if(!g_iOldPersonaRank[iClient])
		{
			g_iOldPersonaRank[iClient] = LoadFromAddress(pPersonaDataPublic + view_as<Address>(m_player_level_), NumberType_Int32);
		}

		StoreToAddress(pPersonaDataPublic + view_as<Address>(m_player_level_), iLevel, NumberType_Int32);
	}
}

public void OnClientDisconnect(int iClient)
{
	g_iOldPersonaRank[iClient] = 0;
	g_iPersonaRank[iClient] = 0;
}