#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma tabsize 0

public Plugin myinfo = 
{
	name = "Isınma Turu",
	author = "Emur",
	description = "Oylama İle Isınma Turu Başlatır",
	version = "1.3",
	url = "www.pluginmerkezi.com"
};

ConVar g_yetkili_flag, g_yetkili_flag2, g_warmup_sure, g_warmup_bekleme; //ConVarlar

bool baslat = false, warmupaktif = false, bekleme = false;

int gerisayim = 0; //Geri sayım için
Handle warmup_timer = null;

float checkpoint_kordinatlar[MAXPLAYERS + 1][3], checkpoint_acilar[MAXPLAYERS + 1][3]; //Checkpoint koordinatları

public void OnPluginStart()
{
	g_yetkili_flag = CreateConVar("isinma_yetkili_flag", "z", "Oylamayı başlatabilmesini istediğiniz yetkili flagını yazınız.");
	g_yetkili_flag2 = CreateConVar("isinma_flag", "z", "Direkt başlatabilmek için gerekli flag.");
	g_warmup_sure = CreateConVar("isinma_sure", "900", "Isınma kaç saniye sürsün.");
	g_warmup_bekleme = CreateConVar("isinma_bekleme", "900", "Oylamada hayır çıkarsa kaç saniye beklemek gereksin.");
	AutoExecConfig(true, "isinmaturu", "sourcemod/PluginMerkezi");
	
	HookEvent("round_end", event_end);
	HookEvent("player_spawn", event_spawn);
	
	RegConsoleCmd("sm_fjvote", command_oylama);
	RegConsoleCmd("sm_fjbitir", command_bitir);
	RegConsoleCmd("sm_fjbaslat", command_baslat);
	RegConsoleCmd("sm_fjmenu", command_ozellikleri);
	RegConsoleCmd("sm_fj", command_ozellikleri);
}

public void OnMapEnd()
{
	baslat = false, warmupaktif = false, bekleme = false;
}

public Action command_baslat(int client, int args)
{
	char yetkiliflag[32];
	g_yetkili_flag2.GetString(yetkiliflag, sizeof(yetkiliflag));
	if(YetkiDurum(client, yetkiliflag))
	{
		if(warmupaktif)
		{
			PrintToChat(client, "[SM] \x01Şuanda zaten warmup oynanıyor.");
			return Plugin_Handled;
		}
		PrintToChatAll("[SM] \x06Isınma Turu \x01bir sonraki round başlayacak ve \x0415 Dakika \x01sürecektir.");
      	SetCvar("mp_warmuptime", g_warmup_sure.IntValue);
      	baslat = true;
	}
	else
		PrintToChat(client, "[SM] \x01Bu komutu kullanabilmek için yetkili olmalısın.");
	return Plugin_Handled;
}

public Action command_oylama(int client, int args)
{
	char yetkiliflag[32];
	g_yetkili_flag.GetString(yetkiliflag, sizeof(yetkiliflag));
	if(YetkiDurum(client, yetkiliflag))
	{
		if(bekleme)
		{
			PrintToChat(client, "[SM] \x01Yeniden oylama yapmak için biraz beklemelisin.");
			return Plugin_Handled;
		}
		Menu menu = new Menu(isinma_oylama);
		menu.SetTitle("Isınma Oynansın Mı?");
		menu.AddItem("1", "Evet");
		menu.AddItem("2", "Hayır");
		menu.ExitButton = false;
		menu.DisplayVoteToAll(20);
	}
	else
		PrintToChat(client, "[SM] \x01Bu komutu kullanabilmek için yetkili olmalısın.");
	return Plugin_Handled;
}

public int isinma_oylama(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_VoteEnd)
    {
        if(param1 == 0)
        {
        	PrintToChatAll("[SM] \x06Isınma Turu \x01bir sonraki round başlayacak ve \x0415 Dakika \x01sürecektir.");
        	SetCvar("mp_warmuptime", g_warmup_sure.IntValue);
        	baslat = true;
        }
        else
        {
        	bekleme = true;
       		CreateTimer(g_warmup_bekleme.FloatValue, beklemekaldir,_, TIMER_FLAG_NO_MAPCHANGE);
       	}
    }
}

public Action beklemekaldir(Handle timer)
{
	bekleme = false;
	return Plugin_Stop;
}

public Action command_bitir(int client, int args)
{
	char yetkiliflag[32];
	g_yetkili_flag.GetString(yetkiliflag, sizeof(yetkiliflag));
	if(YetkiDurum(client, yetkiliflag))
	{
		if(warmupaktif)
		{
			ServerCommand("mp_warmup_end");
			PrintToChatAll("[SM] \x04Isınma turu \x06%N \x01tarafından bitirildi.", client);
			SetCvar("mp_solid_teammates", 0);
			warmupaktif = false;
			
			warmup_timer = null;
			delete warmup_timer;
		}
		else
		{
			PrintToChat(client, "[SM] \x01Şuanda aktif bir ısınma turu yok.", client);
		}
	}
	else
		PrintToChat(client, "[SM] \x01Bu komutu kullanabilmek için yetkili olmalısın.");
	return Plugin_Handled;
}

public Action command_ozellikleri(int client, int args)
{
	if(warmupaktif)
		menu_ozellikler(client);
	else
		PrintToChat(client, "[SM] \x01Bu komutu sadece warmup'da kullanabilirsin.");
	return Plugin_Handled;
}

public void menu_ozellikler(int client)
{
	Menu menu = new Menu(isinma_ozellikler);
	menu.SetTitle("FJ Menu");
	menu.AddItem("1", "Checkpoint Seç");
	if(checkpoint_kordinatlar[client][2] == 0.0)
		menu.AddItem("2", "Checkpoint'e Işınlan", ITEMDRAW_DISABLED);
	else
		menu.AddItem("2", "Checkpoint'e Işınlan");
	if(GetEntityMoveType(client) != MOVETYPE_NOCLIP)
		menu.AddItem("3", "Noclip");
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
		menu.AddItem("3", "Noclip [X]");
	if(GetClientTeam(client) != CS_TEAM_SPECTATOR)
		menu.AddItem("4", "İzleyici Moduna Geç");
	else
		menu.AddItem("4", "Oynamaya Devam Et");
	if(GetClientTeam(client) == CS_TEAM_T || GetClientTeam(client) == CS_TEAM_CT)
		menu.AddItem("5", "Karşı Takıma Geç");
	else
		menu.AddItem("5", "Karşı Takıma Geç", ITEMDRAW_DISABLED);
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int isinma_ozellikler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(!warmupaktif){
		return;}
		char item[32];
		menu.GetItem(param2, item, sizeof(item));
		if(StrEqual(item, "1"))
		{
			if(GetEntPropEnt(param1, Prop_Send, "m_hGroundEntity") == 0)
			{
				GetClientAbsAngles(param1, checkpoint_acilar[param1]);
				GetClientAbsOrigin(param1, checkpoint_kordinatlar[param1]);
				PrintToChat(param1, "[SM] \x01Bulunduğun konum \x04checkpoint \x01olarak kaydedildi.");
			}
			else
				PrintToChat(param1, "[SM] \x01Checkpoint belirlemek için yerde olmalısın.");
		}	
		else if(StrEqual(item, "2"))
		{
			TeleportEntity(param1, checkpoint_kordinatlar[param1], checkpoint_acilar[param1], NULL_VECTOR);
			PrintToChat(param1, "[SM] \x04Checkpointine \x01Başarıyla ışınlandın.");
		}
		else if(StrEqual(item, "3"))
		{
			if(GetEntityMoveType(param1) != MOVETYPE_NOCLIP)
			{
				SetEntityMoveType(param1, MOVETYPE_NOCLIP);
				PrintToChat(param1, "[SM] \x04Noclip \x01etkinleştirildi.");
			}
			else
			{	
				SetEntityMoveType(param1, MOVETYPE_WALK);	
				PrintToChat(param1, "[SM] \x04Noclip \x01pasifleştirildi.");
			}
		}
		else if(StrEqual(item, "4"))
		{
			if(GetClientTeam(param1) != CS_TEAM_SPECTATOR)
				ChangeClientTeam(param1, CS_TEAM_SPECTATOR);
			else
				ChangeClientTeam(param1, CS_TEAM_T);
		}
		else if(StrEqual(item, "5"))
		{
			if(GetClientTeam(param1) == CS_TEAM_T)
				ChangeClientTeam(param1, CS_TEAM_CT);
			else
				ChangeClientTeam(param1, CS_TEAM_T);
		}
		menu_ozellikler(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public Action event_end(Event event, const char[] name, bool dontBroadcast)
{
	if(baslat)
	{
		gerisayim = 3;
		CreateTimer(1.0, gerisayim_timer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		baslat = false;
	}
	return Plugin_Continue;
}

public Action gerisayim_timer(Handle timer)
{
	if(gerisayim == 0)
	{
		PrintToChatAll("[SM] \x04Isınma Turunun Başlamasına \x01son \x06%d \x01saniye.", gerisayim);
		ServerCommand("mp_warmup_start");
		SetCvar("mp_solid_teammates", 1);
		warmup_timer = CreateTimer(g_warmup_sure.FloatValue, warmupkapa, _, TIMER_FLAG_NO_MAPCHANGE);
		warmupaktif = true;
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
				menu_ozellikler(i);
		}
		return Plugin_Stop;
	}
	else
	{
		PrintToChatAll("[SM] \x04Isınma Turunun Başlamasına \x01son \x06%d \x01saniye.", gerisayim);
		gerisayim--;
	}
	return Plugin_Continue;
}

public Action warmupkapa(Handle timer)
{
	SetCvar("mp_solid_teammates", 0);
	warmupaktif = false;
	return Plugin_Stop;
}


public Action event_spawn(Event event, const char[] name, bool dontBroadcast)
{
	if(warmupaktif)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		SetEntProp(client, Prop_Data, "m_takedamage", 1, 1);
	}
	return Plugin_Continue;
}


/************************************************ Burdan Sonrasını Elleme ****************************************/

void SetCvar(char cvarName[64], int value)
{
    Handle IntCvar = FindConVar(cvarName);
    if (IntCvar == null)return;
    
    int flags = GetConVarFlags(IntCvar);
    flags &= ~FCVAR_NOTIFY;
    SetConVarFlags(IntCvar, flags);
    
    SetConVarInt(IntCvar, value);
    
    flags |= FCVAR_NOTIFY;
    SetConVarFlags(IntCvar, flags);
}


bool YetkiDurum(int client, char[] sFlags)
{
    if (StrEqual(sFlags, "public", false) || StrEqual(sFlags, "", false))
        return true;
    if (StrEqual(sFlags, "none", false))
        return false;
    AdminId id = GetUserAdmin(client);
    if (id == INVALID_ADMIN_ID)
        return false;
    if (CheckCommandAccess(client, "sm_not_a_command", ADMFLAG_ROOT, true))
        return true;
    int iCount, iFound, flags;
    if (StrContains(sFlags, ";", false) != -1)
    {
        int c = 0, iStrCount = 0;
        while (sFlags[c] != '\0')
        {
            if (sFlags[c++] == ';')
                iStrCount++;
        }
        iStrCount++;
        char[][] sTempArray = new char[iStrCount][30];
        ExplodeString(sFlags, ";", sTempArray, iStrCount, 30);
        for (int i = 0; i < iStrCount; i++)
        {
            flags = ReadFlagString(sTempArray[i]);
            iCount = 0;
            iFound = 0;
            for (int j = 0; j <= 20; j++)
            {
                if (flags & (1 << j))
                {
                    iCount++;
                    
                    if (GetAdminFlag(id, view_as<AdminFlag>(j)))
                        iFound++;
                }
            }
            if (iCount == iFound)
                return true;
        }
    }
    else
    {
        flags = ReadFlagString(sFlags);
        iCount = 0;
        iFound = 0;
        for (int i = 0; i <= 20; i++)
        {
            if (flags & (1 << i))
            {
                iCount++;
                if (GetAdminFlag(id, view_as<AdminFlag>(i)))
                    iFound++;
            }
        }
        if (iCount == iFound)
            return true;
    }
    return false;
} 


public void OnClientPostAdminCheck(int client)
{
	checkpoint_kordinatlar[client][2] = 0.0;
}