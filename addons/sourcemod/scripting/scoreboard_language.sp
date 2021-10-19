#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <PTaH>

#pragma newdecls required
#pragma tabsize 4

#include <geoip>

#if !SPPP_COMPILER
	#define decl static
#endif

enum struct FlagData
{
	char sCountryCode[4];
	int  iIndex;

	void ParseKeyValue(const char[] szKey, const char[] szValue)
	{
		strcopy(this.sCountryCode, sizeof(this.sCountryCode), szKey);
		this.iIndex = StringToInt(szValue);
	}
}

int              g_iOldPersonaRank[MAXPLAYERS + 1],
                 g_iPersonaRank[MAXPLAYERS + 1],
                 g_iNoneFlagIndex,
                 m_pPersonaDataPublic,
                 m_player_level_;

ArrayList        g_hFlagsData;

GlobalForward    g_hForwardLevelChange,
                 g_hForwardLevelChangePost;

Handle           g_hCreateEconPersonaDataPublic;

// scoreboard_language.sp
public Plugin myinfo = 
{
	name = "[Scoreboard] Language",
	author = "Wend4r",
	version = "1.6.4",
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

	g_hForwardLevelChange = new GlobalForward("Scoreboard_LoadPersonaLevel", ET_Hook, Param_Cell, Param_CellByRef, Param_Cell);
	g_hForwardLevelChangePost = new GlobalForward("Scoreboard_LoadPersonaLevelPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

	RegPluginLibrary("scoreboard_language");

	return APLRes_Success;
}

int Scoreboard_SetPersonaLevel(Handle hPlugin, int iArgs)
{
	int iClient = GetNativeCell(1),
	    iLevel = GetNativeCell(2);

	if(IsClientInGame(iClient) && (GetNativeCell(3) || !g_iPersonaRank[iClient] || g_iPersonaRank[iClient] == g_iNoneFlagIndex))
	{
		if(iLevel == -1)
		{
			iLevel = g_iOldPersonaRank[iClient];
		}

		return SetPersonaLevel(iClient, iLevel);
	}

	return false;
}

int Scoreboard_GetPersonaLevel(Handle hPlugin, int iArgs)
{
	int iClient = GetNativeCell(1);

	return GetNativeCell(2) ? g_iOldPersonaRank[iClient] : g_iPersonaRank[iClient];
}

public void OnPluginStart()
{
	{
		static const char szGameData[] = "econ_persona_data_public.games",
		                  szNearestNetpropForPersonaDataPublicKey[] = "Nearest netprop for m_pPersonaDataPublic",
		                  szNearestNetpropToPersonaDataPublicOffset[] = "Nearest netprop to m_pPersonaDataPublic",
		                  szEconPersonaDataPublicPlayerLevelOffset[] = "CEconPersonaDataPublic::player_level_",
		                  szCreateEconPersonaDataPublicAddress[] = "GCSDK::CreateSharedObjectSubclass<CEconPersonaDataPublic>";

		GameData hGameData = new GameData(szGameData);

		if(!hGameData)
		{
			SetFailState("Failed to initialize \"gamedata/%s.txt\" gamedata file", szGameData);
		}

		{
			decl char sValue[64];

			if(hGameData.GetKeyValue(szNearestNetpropForPersonaDataPublicKey, sValue, sizeof(sValue)))
			{
				m_pPersonaDataPublic = FindSendPropInfo("CCSPlayer", sValue);
			}
			else
			{
				SetFailState("Failed to get \"%s\" key value", szNearestNetpropForPersonaDataPublicKey);
			}
		}

		{
			int iOffset = hGameData.GetOffset(szNearestNetpropToPersonaDataPublicOffset);

			if(iOffset == -1)
			{
				SetFailState("Failed to get \"%s\" offset", szNearestNetpropToPersonaDataPublicOffset);
			}

			m_pPersonaDataPublic += iOffset;

			iOffset = hGameData.GetOffset(szEconPersonaDataPublicPlayerLevelOffset);

			if(iOffset == -1)
			{
				SetFailState("Failed to get \"%s\" offset", szEconPersonaDataPublicPlayerLevelOffset);
			}

			m_player_level_ = iOffset;
		}

		StartPrepSDKCall(SDKCall_Static);
		PrepSDKCall_SetFromConf(hGameData, SDKConf_Address, szCreateEconPersonaDataPublicAddress);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

		if(!(g_hCreateEconPersonaDataPublic = EndPrepSDKCall()))
		{
			SetFailState("Failed to get \"%s\" address", szCreateEconPersonaDataPublicAddress);
		}

		hGameData.Close();
	}

	g_hFlagsData = new ArrayList(sizeof(FlagData));

	PTaH(PTaH_InventoryUpdatePost, Hook, OnInventoryUpdatePost);

	HookEvent("player_spawn", OnPlayerSpawn);
}

public void OnMapStart()
{
	static char sPath[PLATFORM_MAX_PATH];

	static SMCParser hParser;

	if(sPath[0])
	{
		g_hFlagsData.Clear();
	}
	else
	{
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/scoreboard_language.ini");

		(hParser = new SMCParser()).OnKeyValue = OnSectionSettings;
	}

	decl char sBuffer[PLATFORM_MAX_PATH];

	SMCError iError = hParser.ParseFile(sPath);

	if(iError != SMCError_Okay)
	{
		hParser.GetErrorString(iError, sBuffer, sizeof(sBuffer));
		SetFailState("%s - %s", sPath, sBuffer);
	}

	int iIndex = g_hFlagsData.FindString("none");

	g_iNoneFlagIndex = iIndex != -1 ? g_hFlagsData.Get(iIndex, FlagData::iIndex) : 0;

	for(int i = 0, iLen = g_hFlagsData.Length; i != iLen; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "materials/panorama/images/icons/xp/level%i.png", g_hFlagsData.Get(i, FlagData::iIndex));
		AddFileToDownloadsTable(sBuffer);
	}

	for(int i = MaxClients + 1; --i;)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			LoadPlayerData(i);
			LoadFlags(i);
		}
	}
}

SMCResult OnSectionSettings(SMCParser hParser, const char[] szKey, const char[] szValue, bool bKeyQuotes, bool bValueQuotes)
{
	decl FlagData aFlag;

	aFlag.ParseKeyValue(szKey, szValue);
	g_hFlagsData.PushArray(aFlag, sizeof(aFlag));
}

public void OnClientPutInServer(int iClient)
{
	if(!IsFakeClient(iClient))
	{
		LoadPlayerData(iClient);
	}
}

void LoadPlayerData(int iClient)
{
	decl char sCode[3], sIP[32];

	GetClientIP(iClient, sIP, sizeof(sIP));

	if(!IsLocalIP(sIP) && GeoipCode2(sIP, sCode))
	{
		int iIndex = g_hFlagsData.FindString(sCode);

		if(iIndex != -1)
		{
			g_iPersonaRank[iClient] = g_hFlagsData.Get(iIndex, FlagData::iIndex);
			
			return;
		}
	}
	
	g_iPersonaRank[iClient] = g_iNoneFlagIndex;
}

// by Phoenix (aka komashchenko).
bool IsLocalIP(const char[] szIP)
{
	decl char sIPs[4][4];

	if(ExplodeString(szIP, ".", sIPs, sizeof(sIPs), sizeof(sIPs[])) == 4)
	{
		int iBuf = StringToInt(sIPs[0]);

		return iBuf == 10 || // 10.x.x.x
		      (iBuf == 172 && (16 <= StringToInt(sIPs[1]) <= 31)) || // 172.16.x.x  - 172.31.x.x
		      (iBuf == 192 && StringToInt(sIPs[1]) == 168); // 192.168.x.x
	}

	return false;
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

void LoadFlags(int iClient)
{
	if(g_hForwardLevelChange.FunctionCount)
	{
		decl Action iAction;

		Call_StartForward(g_hForwardLevelChange);
		Call_PushCell(iClient);
		Call_PushCellRef(g_iPersonaRank[iClient]);
		Call_PushCell(g_iOldPersonaRank[iClient]);
		Call_Finish(iAction);

		if(iAction == Plugin_Handled)
		{
			return;
		}
	}

	if(SetPersonaLevel(iClient, g_iPersonaRank[iClient]) && g_hForwardLevelChangePost.FunctionCount)
	{
		Call_StartForward(g_hForwardLevelChangePost);
		Call_PushCell(iClient);
		Call_PushCell(g_iPersonaRank[iClient]);
		Call_PushCell(g_iOldPersonaRank[iClient]);
		Call_Finish();
	}
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

bool SetPersonaLevel(int iClient, int iLevel)
{
	// *m_pPersonaDataPublic -> player_level_ :

	Address pPersonaDataPublic = view_as<Address>(GetEntData(iClient, m_pPersonaDataPublic));

	if(pPersonaDataPublic)
	{
		if(!g_iOldPersonaRank[iClient])
		{
			g_iOldPersonaRank[iClient] = LoadFromAddress(pPersonaDataPublic + view_as<Address>(m_player_level_), NumberType_Int32);
		}

		StoreToAddress(pPersonaDataPublic + view_as<Address>(m_player_level_), iLevel, NumberType_Int32);

		return true;
	}
	else		// Non-steam or non-prime player.
	{
		Address pNewPersonaPublic = SDKCall(g_hCreateEconPersonaDataPublic);		// Inclusive memory allocation from g_pMemAlloc .

		StoreToAddress(pNewPersonaPublic + view_as<Address>(m_player_level_), iLevel, NumberType_Int32);
		SetEntData(iClient, m_pPersonaDataPublic, pNewPersonaPublic);		// pNewPersonaPublic must be free in CCSPlayer::~CCSPlayer() .
	}

	return false;
}

public void OnClientDisconnect(int iClient)
{
	g_iOldPersonaRank[iClient] = 0;
	g_iPersonaRank[iClient] = 0;
}

public void OnPluginEnd()
{
	for(int i = MaxClients + 1; --i;)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			SetPersonaLevel(i, g_iOldPersonaRank[i]);
		}
	}
}