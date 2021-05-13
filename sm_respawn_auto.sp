#include <sourcemod>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

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
float g_LastSpawn[MAXPLAYERS];
float g_LastDeath[MAXPLAYERS];
int g_ConsecutiveDeaths[MAXPLAYERS];

public void OnGameFrame()
{
    if (!g_cvAutoRespawn.BoolValue)
        return;
    
    for (int i = 1; i < MaxClients; ++i)
    {
        int team = GetClientTeam(i);
        if (IsClientInGame(i) && !IsPlayerAlive(i) && (team == CS_TEAM_CT || team == CS_TEAM_T) && g_ConsecutiveDeaths[i] < g_cvMaxDeaths.IntValue)
        {
            PrintToChat(i, "[GAME FRAME] Forcing Respawn...");
            PrintToChat(i, "[PLAYER DEATH] Game Time:  %f", GetGameTime());
            PrintToChat(i, "[PLAYER DEATH] Last Spawn: %f", g_LastDeath[i]);
            PrintToChat(i, "[PLAYER DEATH] Last Death: %f", g_LastDeath[i]);
            PrintToChat(i, "[PLAYER DEATH] Deaths:     %i", g_ConsecutiveDeaths[i]);
            RespawnPlayer(i);
        }
    }
}

public Action HkPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvAutoRespawn.BoolValue)
        return Plugin_Continue;
    
    int client_id = event.GetInt("userid");
    int client = GetClientOfUserId(client_id);
    float game_time = GetGameTime();
    
    if (game_time - g_LastSpawn[client] < g_cvRespawnProtection.FloatValue)
    {
        PrintToChat(client, "[PLAYER DEATH] Respawn Protection");
        return Plugin_Handled;
    }
    
    if (game_time - g_LastDeath[client] < g_cvKillerTime.FloatValue)
    {
        g_ConsecutiveDeaths[client] += 1;
        PrintToChat(client, "[PLAYER DEATH] Consecutive Death");
    }
    else
    {
        PrintToChat(client, "[PLAYER DEATH] Reset Deaths");
        g_ConsecutiveDeaths[client] = 0;
    }
    
    g_LastDeath[client] = game_time;
    
    return Plugin_Continue;
}

public Action HkPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvAutoRespawn.BoolValue)
        return Plugin_Continue;
    
    int client_id = event.GetInt("userid");
    int client = GetClientOfUserId(client_id);
    float game_time = GetGameTime();
    PrintToChat(client, "[PLAYER SPAWN] You have spawned");
    g_LastSpawn[client] = game_time;
    return Plugin_Continue;
}

public Action HkRoundFreezeEnd(Handle event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i < MaxClients; ++i)
    {
        PrintToChat(i, "[ROUND END] Your Data has been Reset");
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
    HookEvent("player_spawn", HkPlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", HkPlayerDeath, EventHookMode_Pre);
    HookEvent("round_freeze_end", HkRoundFreezeEnd, EventHookMode_PostNoCopy);
}

public void OnClientConnected(int client)
{
    ResetData(client);
}

public void OnClientDisconnect(int client)
{
    ResetData(client);
}

void ResetData(int client)
{
    g_LastSpawn[client] = 0.0;
    g_LastDeath[client] = 0.0;
    g_ConsecutiveDeaths[client] = 0;
}

void RespawnPlayer(int client)
{
    CS_RespawnPlayer(client);
}
