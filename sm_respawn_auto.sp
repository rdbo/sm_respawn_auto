#include <sourcemod>
#include <cstrike>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define ADMFLAG_RESPAWN ADMFLAG_SLAY

public Plugin myinfo = {
    name        = "Player Auto Respawn",
    author      = "rdbo",
    description = "Respawn Dead Players",
    version     = "1.0.0",
    url         = ""
};

ConVar g_cvAutoRespawn;
ConVar g_cvRespawnProtection;
ConVar g_cvKillerTime;
ConVar g_cvMaxDeaths;
ConVar g_cvPlayerDmg;
ConVar g_cvSpawnAlpha;
float g_LastSpawn[MAXPLAYERS];
float g_LastDeath[MAXPLAYERS];
int g_ConsecutiveDeaths[MAXPLAYERS];

public void OnGameFrame()
{
    if (!g_cvAutoRespawn.BoolValue)
        return;
    
    for (int i = 1; i < MaxClients; ++i)
    {
        if (!IsClientInGame(i))
            continue;
        
        int team = GetClientTeam(i);
        
        if (!IsPlayerAlive(i) && (team == CS_TEAM_CT || team == CS_TEAM_T))
        {
            if (g_ConsecutiveDeaths[i] < g_cvMaxDeaths.IntValue)
            {
                RespawnPlayer(i);
            }
        }
    }
}

 public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
 {
    if (g_cvAutoRespawn.BoolValue)
    {
        int health = GetClientHealth(victim);
        float game_time = GetGameTime();
        
        if (game_time - g_LastSpawn[victim] < g_cvRespawnProtection.FloatValue || (!g_cvPlayerDmg.BoolValue && (damagetype & (DMG_BULLET | DMG_SLASH))))
            return Plugin_Handled;
            
        if (damage >= health)
            HandleDeath(victim);
    }
        
    return Plugin_Continue;
 }

public Action HkPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (g_cvAutoRespawn.BoolValue)
    {
        int client_id = event.GetInt("userid");
        int client = GetClientOfUserId(client_id);
        float game_time = GetGameTime();
        
        if (game_time - g_LastSpawn[client] < g_cvRespawnProtection.FloatValue)
        {
            return Plugin_Handled;
        }
        
        HandleDeath(client);
    }
    
    return Plugin_Continue;
}

public Action HkPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvAutoRespawn.BoolValue)
        return Plugin_Continue;
    
    int client_id = event.GetInt("userid");
    int client = GetClientOfUserId(client_id);
    float game_time = GetGameTime();
    g_LastSpawn[client] = game_time;
    CreateTimer(0.1, HandleProtAlpha, client);
    return Plugin_Continue;
}

public Action HkRoundFreezeEnd(Handle event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i < MaxClients; ++i)
    {
        ResetData(i);
    }
    
    return Plugin_Continue;
}

public void OnPluginStart()
{
    PrintToServer("[SM] Player Auto Respawn Loaded");
    g_cvAutoRespawn = CreateConVar("sm_respawn_auto", "0", "Enable auto respawn");
    g_cvRespawnProtection = CreateConVar("sm_respawn_prot", "10", "Respawn protection time");
    g_cvMaxDeaths = CreateConVar("sm_respawn_deaths", "5", "Maximum consecutive deaths");
    g_cvKillerTime = CreateConVar("sm_respawn_killer", "15", "Maximum time to consider as consecutive death ( > Protection time)");
    g_cvPlayerDmg = CreateConVar("sm_respawn_dmg", "1", "Enable Player Damage");
    g_cvSpawnAlpha = CreateConVar("sm_respawn_alpha", "125", "Alpha on Respawn Protection");
    HookEvent("player_spawn", HkPlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", HkPlayerDeath, EventHookMode_Pre);
    HookEvent("round_freeze_end", HkRoundFreezeEnd, EventHookMode_PostNoCopy);
    RegAdminCmd("sm_respawn_reset", CMD_RespawnReset, ADMFLAG_RESPAWN, "Resets All Spawn Data");
}

public void OnClientConnected(int client)
{
    ResetData(client);
}

public void OnClientDisconnect(int client)
{
    ResetData(client);
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

void ResetData(int client)
{
    g_LastSpawn[client] = 0.0;
    g_LastDeath[client] = 0.0;
    g_ConsecutiveDeaths[client] = 0;
}

public void OnClientPutInServer(int client)
{	
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

void RespawnPlayer(int client)
{
    CS_RespawnPlayer(client);
}

public Action HandleProtAlpha(Handle timer, int client)
{
    int r, g, b, a;
    GetEntityRenderColor(client, r, g, b, a);
    
    if (GetGameTime() - g_LastSpawn[client] >= g_cvRespawnProtection.FloatValue)
    {
        a = 0xFF;
    }
    else
    {
        a = g_cvSpawnAlpha.IntValue;
        CreateTimer(g_cvRespawnProtection.FloatValue, HandleProtAlpha, client);
    }
    
    SetEntityRenderColor(client, r, g, b, a);
}

void HandleDeath(int client)
{
    float game_time = GetGameTime();
    
    if (game_time - g_LastDeath[client] < g_cvKillerTime.FloatValue)
    {
        g_ConsecutiveDeaths[client] += 1;
    }
    
    else
    {
        g_ConsecutiveDeaths[client] = 0;
    }
    
    g_LastDeath[client] = game_time;
}

public Action CMD_RespawnReset(int client, int args)
{
    for (int i = 1; i < MaxClients; ++i)
        ResetData(i);
    return Plugin_Handled;
}
