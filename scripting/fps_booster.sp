#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <csgocolors>
#include <clientprefs>

#define PLUGIN_NAME 		"FPS boost"
#define PLUGIN_AUTHOR		"GoD-Tony, de_nerdTV"
#define PLUGIN_VERSION 		"0.0.1"
#define PLUGIN_DESCRIPTION	"Melhor performance client-side evitando transmissão de sons desnecessários"
#define PLUGIN_URL			"https://denerdtv.com"

bool g_bStopSound[MAXPLAYERS+1];
bool g_bHooked;

Handle g_hClientCookie = INVALID_HANDLE;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_hClientCookie = RegClientCookie("sm_fps", "Controla boost de FPS", CookieAccess_Private);
	SetCookieMenuItem(StopSoundCookieHandler, g_hClientCookie, "Boost de FPS");

	// Detect game and hook appropriate tempent.
	char sGame[32];
	GetGameFolderName(sGame, sizeof(sGame));

	if (StrEqual(sGame, "cstrike") || StrEqual(sGame, "csgo")) {
		AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
	}
	
	RegConsoleCmd("sm_fps", Command_StopSound, "Controla boost de FPS");

	for (new i = 1; i <= MaxClients; ++i) {
		if (!AreClientCookiesCached(i)) {
			continue;
		}
		
		OnClientCookiesCached(i);
	}
}

public void StopSoundCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_DisplayOption:
		{
		}
		
		case CookieMenuAction_SelectOption:
		{
			ToggleStopSound(client);
		}
	}
}

void ToggleStopSound(int client)
{
	char info[1];
	int value = !g_bStopSound[client];

	IntToString(value, info, sizeof(info));
	SetClientCookie(client, g_hClientCookie, info);

	g_bStopSound[client] = (value == 1) ? true : false;
	CPrintToChat(client, "{default}[{darkred}FPS{default}] Boost de FPS: %s.", value ? "{green}ligado" : "{darkred}desligado");
	CheckHooks();	
}

public void OnClientCookiesCached(client)
{
	char sValue[8];
	GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));
	
	g_bStopSound[client] = (sValue[0] != '\0' && StringToInt(sValue));
	CheckHooks();
}

public Action Command_StopSound(client, args)
{
	if (AreClientCookiesCached(client)) {
		ToggleStopSound(client);
	} else {
		ReplyToCommand(client, "[SM] Aguardando cookies, por favor tente novamente mais tarde...");
	}
	
	return Plugin_Handled;
}

public OnClientDisconnect_Post(client)
{
	g_bStopSound[client] = false;
	CheckHooks();
}

void CheckHooks()
{
	bool bShouldHook = false;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (g_bStopSound[i]) {
			bShouldHook = true;
			break;
		}
	}
	
	// Fake (un)hook because toggling actual hooks will cause server instability.
	g_bHooked = bShouldHook;
}

public Action CSS_Hook_ShotgunShot(const char[] te_name, const Players[], numClients, float delay)
{
	if (!g_bHooked) {
		return Plugin_Continue;
	}
	
	// Check which clients need to be excluded.
	int newClients[MAXPLAYERS];
	int client;
	int newTotal = 0;
	
	for (int i = 0; i < numClients; i++) {
		client = Players[i];
		
		if (!g_bStopSound[client]) {
			newClients[newTotal++] = client;
		}
	}
	
	if (newTotal == numClients) { // No clients were excluded.
		return Plugin_Continue;
	} else if (newTotal == 0) { // All clients were excluded and there is no need to broadcast.
		return Plugin_Stop;
	}
	
	// Re-broadcast to clients that still need it.
	float vTemp[3];
	TE_Start("Shotgun Shot");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_Send(newClients, newTotal, delay);
	
	return Plugin_Stop;
}