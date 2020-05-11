#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#pragma newdecls required
#pragma tabsize 4

#include <geoip>

#define SPPP_COMPILER 0

#if !SPPP_COMPILER
	#define decl static
#endif

#define SCOREBOARD_REVEAL 0

#define START_XP_INDEX 1200
#define END_XP_INDEX 1395

int              g_iOldPersonaRank[MAXPLAYERS + 1],
                 g_iPersonaRank[MAXPLAYERS + 1],
                 m_pPersonaDataPublic;		// CEconPersonaDataPublic : GCSDK::CProtoBufSharedObject

static const int m_player_level_ = 16;		// m_msgObject (CSOPersonaDataPublic) => 4 + player_level_ (int) => 12

GlobalForward    g_hForwardLevelChange;

// scoreboard_language.sp
public Plugin myinfo = 
{
	name = "[Scoreboard] Language", 
	author = "Wend4r", 
	version = "1.5.1"
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

	for(int i = MaxClients + 1; --i;)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);

			if(!IsFakeClient(i))
			{
				SetPersonaLevel(i, g_iPersonaRank[i]);
			}
		}
	}

	HookEvent("player_team", OnPlayerTeam);
}

public void OnMapStart()
{
	decl char sBuffer[PLATFORM_MAX_PATH];

	for(int i = START_XP_INDEX; i != END_XP_INDEX; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "materials/panorama/images/icons/xp/level%i.png", i);
		AddFileToDownloadsTable(sBuffer);
	}

	AddFileToDownloadsTable("materials/panorama/images/icons/xp/level1500.png");
}

public void OnClientPutInServer(int iClient)
{
	if(!IsFakeClient(iClient))
	{
		decl char sLang[3], sIP[32];

		static const char sCodes[][] =
		{
			"US", "SV", "BR", "BG", "CZ", "DK", "LU", "FL", "FR", "DE",
			"LU", "IL", "HU", "IT", "JP", "KR", "AT", "LT", "NO", "PL",
			"PT", "AD", "RU", "CN", "SK", "ES", "SE", "CN", "TH", "TR",
			"UA", "SA", "GB", "MH", "BN", "BI", "SM", "MK", "BT", "GY",
			"KI", "JM", "KN", "NA", "TT", "KM", "BZ", "TZ", "AL", "PG",
			"ZA", "SC", "BA", "SB", "ER", "LC", "GD", "ET", "TL", "VU",
			"AU", "AG", "VA", "TN", "XK", "PK", "FJ", "TV", "MR", "DZ",
			"NZ", "KE", "KG", "SS", "ST", "AF", "CU", "TM", "DJ", "EC",
			"JO", "CY", "MY", "MM", "CD", "DM", "ZW", "HR", "PH", "SZ",
			"GQ", "NP", "SD", "BS", "MZ", "SG", "KH", "RS", "LY", "KZ",
			"BH", "CV", "KP", "VS", "BD", "CA", "AZ", "PA", "MV", "KW",
			"PW", "QA", "BB", "LR", "ME", "TJ", "TG", "LB", "MA", "MX",
			"WS", "SO", "UY", "SN", "NR", "IN", "IR", "UZ", "BF", "UG",
			"SY", "VN", "SI", "FM", "HT", "TW", "VC", "CM", "GE", "SR",
			"LI", "CL", "GT", "BO", "GH", "GW", "AR", "MW", "CG", "DO",
			"PY", "MD", "NI", "CF", "EG", "HN", "LA", "ZM", "LS", "MN",
			"RW", "MT", "TO", "CH", "NE", "BY", "GR", "IS", "OM", "IQ",
			"LK", "CR", "BW", "AE", "GM", "MU", "RO", "BJ", "GN", "MG",
			"BE", "TD", "ML", "SL", "YE", "NL", "AM", "NG", "PE", "EE",
			"LV", "CO", "ID", "MC", "GA"
		};

		GetClientIP(iClient, sIP, sizeof(sIP));

		if(strncmp(sIP, "192.168.1", 9) && GeoipCode2(sIP, sLang))
		{
			int iLang = 0;

			while(strcmp(sCodes[iLang], sLang))
			{
				if(++iLang == sizeof(sCodes))
				{
					return;
				}
			}

			g_iPersonaRank[iClient] = START_XP_INDEX + iLang;
		}
		else
		{
			g_iPersonaRank[iClient] = 1500;
		}
	}
}

void OnPlayerTeam(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if(!hEvent.GetBool("disconnect") && !hEvent.GetInt("oldteam"))
	{
		int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

		if(iClient && !IsFakeClient(iClient))
		{
			SetPersonaLevel(iClient, g_iPersonaRank[iClient]);

			Call_StartForward(g_hForwardLevelChange);
			Call_PushCell(iClient);
			Call_PushCell(g_iOldPersonaRank[iClient]);
			Call_PushCell(g_iPersonaRank[iClient]);
			Call_Finish();
		}
	}
}

void SetPersonaLevel(const int &iClient, const int &iLevel)
{
	// *m_pPersonaDataPublic -> m_msgObject -> player_level_ :

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

#if SCOREBOARD_REVEAL
public void OnPlayerRunCmdPost(int iClient, int iButtons)
{
	static int iOldButtons[MAXPLAYERS + 1];

	if(iButtons & IN_SCORE && !(iOldButtons[iClient] & IN_SCORE))
	{
		StartMessageOne("ServerRankRevealAll", iClient, USERMSG_BLOCKHOOKS);
		EndMessage();
	}

	iOldButtons[iClient] = iButtons;
}
#endif