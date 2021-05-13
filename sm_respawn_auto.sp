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
        float game_time = GetGameTime();
        if (IsClientInGame(i) && !IsPlayerAlive(i) && g_ConsecutiveDeaths[i] < g_cvMaxDeaths.IntValue)
        {
            g_LastSpawn[i] = game_time;
            RespawnPlayer(i);
        }
    }
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!g_cvAutoRespawn.BoolValue)
        return Plugin_Continue;
    
    float game_time = GetGameTime();
    if (game_time - g_LastSpawn[victim] < g_cvRespawnProtection.FloatValue)
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public void HkPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client_id = event.GetInt("userid");
    int client = GetClientOfUserId(client_id);
    float game_time = GetGameTime();
    
    if (game_time - g_LastDeath[client] < g_cvKillerTime.FloatValue)
        g_ConsecutiveDeaths[client] += 1;
    
    g_LastDeath[client] = game_time;
}

public Action HkRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i < MaxClients; ++i)
    {
        ResetData(i);
    }
    
    return Plugin_Continue;
}

public void OnPluginStart()
{
    g_cvAutoRespawn = CreateConVar("sm_respawn_auto", "0", "Enable auto respawn");
    g_cvRespawnProtection = CreateConVar("sm_respawn_prot", "10", "Respawn protection time");
    g_cvMaxDeaths = CreateConVar("sm_respawn_deaths", "5", "Maximum consecutive deaths");
    g_cvKillerTime = CreateConVar("sm_respawn_killer", "10", "Minimum time to consider as consecutive death");
    HookEvent("player_death", HkPlayerDeath, EventHookMode_Post);
    HookEvent("round_end", HkRoundEnd, EventHookMode_Post);
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

public void RespawnPlayer(int client)
{
    CS_RespawnPlayer(client);
}
