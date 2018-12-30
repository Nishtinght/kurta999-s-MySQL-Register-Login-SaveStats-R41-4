#include <a_samp> //www.pornhub.com
#include <a_mysql> //https://github.com/pBlueG/SA-MP-MySQL/releases/download/R41-4/mysql-R41-4-win32.zip
#include <zcmd> //https://github.com/YashasSamaga/I-ZCMD/archive/master.zip

#define MYSQL_HOST "szolgáltató"
#define MYSQL_USER "felhasználónév"
#define MYSQL_PASS "jelszó"
#define MYSQL_DB "adatbázis"
new MySQL:SQL; // változtatható "SQL"

#define ChangeNameDialog(%1) ShowPlayerDialog(%1, DIALOG_CHANGENAME, DIALOG_STYLE_INPUT, !"{0080FF}Névváltás", !"{FFFFFF}Írd be a leendõ neved a névváltáshoz:", !"{00FF00}Tovább", !"{FF0000}Bezár")

new g_szFormatString[144];
#define SendClientMessagef(%1,%2,%3) SendClientMessage(%1, %2, (format(g_szFormatString, sizeof(g_szFormatString), %3), g_szFormatString))

#if !defined gpci
native gpci(playerid, const serial[], maxlen);
#endif

new year, month, day, hour, minute, second;

new g_szQuery[512 +1], g_szDialogFormat[4096], g_szIP[16 +1];

enum e_PLAYER_FLAGS (<<= 1)
{
	e_LOGGED_IN = 1,
	e_FIRST_SPAWN
}
new e_PLAYER_FLAGS:g_PlayerFlags[MAX_PLAYERS char];

new g_pQueryQueue[MAX_PLAYERS];

enum
{
	DIALOG_LOGIN = 20000,
	DIALOG_REGISTER,
	DIALOG_CHANGENAME,
	DIALOG_CHANGEPASS,
	DIALOG_FINDPLAYER
}

#define DIALOG_REGISTERED 1

#define QUERY_COLLISION(%0) printf("Query collision \" #%0 \"! PlayerID: %d, queue: %d, g_pQueryQueue: %d", playerid, queue, g_pQueryQueue[playerid])

#define isnull(%1) ((!(%1[0])) || (((%1[0]) == '\1') && (!(%1[1]))))

public OnFilterScriptInit()
{
	print("\nMySQL RegisterLogin-SaveStats by kurta999 betûtve\n");
 	SQL = mysql_connect("szolgáltató", "felhasználónév", "jelszó", "adatbázis");
	return 1;
}

public OnFilterScriptExit()
{
	mysql_close(SQL);
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	if(IsPlayerNPC(playerid)) return 1;
	if(!(g_PlayerFlags{playerid} & e_LOGGED_IN))
	{
		if(GetPVarInt(playerid, "LineID"))
		{
			LoginDialog(playerid);
		}
		else
		{
			RegisterDialog(playerid);
		}
	}
	return 1;
}

public OnPlayerConnect(playerid)
{
	SetPlayerColor(playerid, (random(0xFFFFFF) << 8) | 0xFF);
	g_pQueryQueue[playerid]++;
	format(g_szQuery, sizeof(g_szQuery), "SELECT `reg_id` FROM `players` WHERE `name` = '%s'", pName(playerid));
	mysql_tquery(SQL, g_szQuery, "THREAD_OnPlayerConnect", "dd", playerid, g_pQueryQueue[playerid]);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	g_pQueryQueue[playerid]++;
	return SavePlayer(playerid, GetPVarInt(playerid, "RegID"));
}

forward THREAD_OnPlayerConnect(playerid, queue);
public THREAD_OnPlayerConnect(playerid, queue)
{
	if(g_pQueryQueue[playerid] != queue) return QUERY_COLLISION(THREAD_OnPlayerConnect);
	new szFetch[12], serial[64];
	cache_get_value_index(0, 0, szFetch);
	SetPVarInt(playerid, "LineID", strval(szFetch));
	g_PlayerFlags{playerid} = e_PLAYER_FLAGS:0;
    if(!IsPlayerNPC(playerid))
	{
		SetPVarInt(playerid, "RegID", -1);
		GetPlayerIp(playerid, g_szIP, sizeof(g_szIP));
		gpci(playerid, serial, sizeof(serial));
		getdate(year, month, day);
		gettime(hour, minute, second);
  		format(g_szQuery, sizeof(g_szQuery), "INSERT INTO `connections`(id, name, ip, serial, time) VALUES(0, '%s', '%s', '%s', '%02d.%02d.%02d/%02d.%02d.%02d')", pName(playerid), g_szIP, serial, year, month, day, hour, minute, second);
		mysql_pquery(SQL, g_szQuery);
		format(g_szQuery, sizeof(g_szQuery), "SELECT * FROM `players` WHERE `name` = '%s' AND `ip` = '%s'", pName(playerid));
		mysql_tquery(SQL, g_szQuery, "THREAD_Autologin", "dd", playerid, g_pQueryQueue[playerid]);
	}
  	return 1;
}

forward THREAD_Autologin(playerid, queue);
public THREAD_Autologin(playerid, queue)
{
	if(g_pQueryQueue[playerid] != queue) return QUERY_COLLISION(THREAD_Autologin);
	new rows, fields;
	cache_get_row_count(rows);
	cache_get_field_count(fields);
	if(rows)
	{
		LoginPlayer(playerid);
		SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Bejelentkezés: {00FF00}Automatikusan bejelentkeztél.");
	}
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	if(IsPlayerNPC(playerid)) return 1;
	if(!(g_PlayerFlags{playerid} & e_LOGGED_IN))
	{
		if(GetPVarInt(playerid, "LineID"))
		{
			LoginDialog(playerid);
		}
		else
		{
			RegisterDialog(playerid);
		}
	}
	return 1;
}

public OnPlayerSpawn(playerid)
{
	if(!(g_PlayerFlags{playerid} & e_FIRST_SPAWN))
	{
		ResetPlayerMoney(playerid);
		GivePlayerMoney(playerid, GetPVarInt(playerid, "Cash"));
		DeletePVar(playerid, "Cash");
		g_PlayerFlags{playerid} |= e_FIRST_SPAWN;
	}
	SetPlayerFightingStyle(playerid, GetPVarInt(playerid, "Style"));
	return 1;
}

NameCheck(const aname[])
{
    new i, ch;
    while ((ch = aname[i++]) && ((ch == ']') || (ch == '[') || (ch == '(') || (ch == ')') || (ch == '_') || (ch == '$') || (ch == '@') || (ch == '.') || (ch == '=') || ('0' <= ch <= '9') || ((ch |= 0x20) && ('a' <= ch <= 'z')))) {}
    return !ch;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
		case DIALOG_LOGIN:
		{
			if(!response)
			    return LoginDialog(playerid);

			if(g_PlayerFlags{playerid} & e_LOGGED_IN)
			{
				SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Bejelentkezés: {FF4040}Már bejelentkeztél.");
				return 1;
			}

			if(isnull(inputtext))
			{
				SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Bejelentkezés: {FF0000}Nem írtál be jelszót!");
				LoginDialog(playerid);
				return 1;
			}

			if(!(3 <= strlen(inputtext) <= 20))
			{
				SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Bejelentkezés: {FF0000}Nem megfelelõ az általad beírt jelszó hosszúsága({FF4040}3-20{FF0000})!");
				LoginDialog(playerid);
				return 1;
			}
			mysql_format(SQL, g_szQuery, sizeof(g_szQuery), "SELECT * FROM `players` WHERE `name` = '%s' AND `pass` COLLATE `utf8_bin` LIKE '%e'", pName(playerid), inputtext);
			mysql_tquery(SQL, g_szQuery, "THREAD_DialogLogin", "dd", playerid, g_pQueryQueue[playerid]);
		}
		case DIALOG_REGISTER:
		{
			if(!response)
			return RegisterDialog(playerid);
			if(isnull(inputtext))
			{
				SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Regisztráció: {FF0000}Nem írtál be jelszót!");
				RegisterDialog(playerid);
				return 1;
			}
			if(!(3 <= strlen(inputtext) <= 20))
			{
				SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Regisztráció: {FF0000}Nem megfelelõ az általad beírt jelszó hosszúsága({FF4040}3-20{FF0000})!");
				RegisterDialog(playerid);
				return 1;
			}
			format(g_szQuery, sizeof(g_szQuery), "SELECT `reg_id` FROM `players` WHERE `name` = '%s'", pName(playerid));
			mysql_pquery(SQL, g_szQuery, "THREAD_Register_1", "dsd", playerid, inputtext, g_pQueryQueue[playerid]);
		}
		case DIALOG_CHANGENAME:
		{
			if(!response)
			return 0;
			if(!(3 <= strlen(inputtext) <= 20))
			{
				SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Névváltás: {FF0000}Nem megfelelõ az általad beírt név hosszúsága({FF4040}3-20{FF0000})!");

				return 1;
			}
			if(!NameCheck(inputtext))
			{
				SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Névváltás: {FF0000}Nem megfelelõ az általad beírt név karakter-tartalma({FF4040}A-Z, 0-9, [], (), $, @.{FF0000})!");
				ChangeNameDialog(playerid);
				return 1;
			}
			if(!strcmp(inputtext, pName(playerid), true))
			{
				SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Névváltás: {FF4040}Jelenleg is ezt a nevet használod.");
				ChangeNameDialog(playerid);
				return 1;
			}
			mysql_format(SQL, g_szQuery, sizeof(g_szQuery), "SELECT `reg_id` FROM `players` WHERE `name` = '%e'", inputtext);
			mysql_pquery(SQL, g_szQuery, "THREAD_Changename", "dsd", playerid, inputtext, g_pQueryQueue[playerid]);
		}
		case DIALOG_CHANGEPASS:
		{
			if(!response)
			return 0;
			if(!(3 <= strlen(inputtext) <= 20))
			{
				SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Jelszóváltás: {FF0000}Az általad beírt jelszó hosszúsága{FF4040}(3-20){FF0000}nem megfelelõ!");

				ShowPlayerDialog(playerid, DIALOG_CHANGEPASS, DIALOG_STYLE_INPUT, "{0080FF}Jelszóváltás", "{FFFFFF}Lentre írd be az új jelszavad! \n\n", "{00FF00}Tovább", "{FF0000}Bezár");
				return 1;
			}
			format(g_szQuery, sizeof(g_szQuery), "SELECT `pass` FROM `players` WHERE `reg_id` = %d", GetPVarInt(playerid, "RegID"));
			mysql_pquery(SQL, g_szQuery, "THREAD_Changepass", "dsd", playerid, inputtext, g_pQueryQueue[playerid]);
		}
		case DIALOG_FINDPLAYER:
		{
			if(!response)
			return 0;
			format(g_szQuery, sizeof(g_szQuery), "SELECT * FROM `players` WHERE `name` = '%s'", inputtext);
			mysql_pquery(SQL, g_szQuery, "THREAD_Findplayer", "dsd", playerid, inputtext, g_pQueryQueue[playerid]);
		}
	}
	return 1;
}

forward THREAD_DialogLogin(playerid, queue);
public THREAD_DialogLogin(playerid, queue)
{
	if(g_pQueryQueue[playerid] != queue) return QUERY_COLLISION(THREAD_DialogLogin);
	new rows, fields;
	cache_get_row_count(rows);
	cache_get_field_count(fields);
	if(rows != 1)
	{
		SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Bejelentkezés: {FF0000}Az általad beírt jelszó nem megfelelõ!");
		LoginDialog(playerid);
		return 1;
	}
	LoginPlayer(playerid);
	SendClientMessage(playerid, 0x00FF00FF, !"{0080FF}Bejelentkezés: {00FF00}Sikeresen bejelentkeztél.");
	return 1;
}

forward THREAD_Register_1(playerid, password[], queue);
public THREAD_Register_1(playerid, password[], queue)
{
	if(g_pQueryQueue[playerid] != queue) return QUERY_COLLISION(THREAD_Register_1);
	new rows, fields;
	cache_get_row_count(rows);
	cache_get_field_count(fields);
	if(rows)
	{
		SendClientMessage(playerid, 0x00FF00FF, "MySQL: A sorok száma több, mint 0, kirúgtunk, ugyanis hiba lehet ebbõl.");
		printf("MySQL rosw > 1 (%d, %s)", playerid, password);
		Kick(playerid);
		return 1;
	}
	getdate(year, month, day);
	gettime(hour, minute, second);
	mysql_format(SQL, g_szQuery, sizeof(g_szQuery), "INSERT INTO `players`(reg_id, name, pass, reg_date, laston) VALUES(0, '%s', '%e', '%02d.%02d.%02d/%02d.%02d.%02d', '%02d.%02d.%02d/%02d.%02d.%02d')", pName(playerid), password, year, month, day, hour, minute, second, year, month, day, hour, minute, second);
	mysql_pquery(SQL, g_szQuery, "THREAD_Register_2", "dsd", playerid, password, g_pQueryQueue[playerid]);
	return 1;
}

forward THREAD_Register_2(playerid, password[], queue);
public THREAD_Register_2(playerid, password[], queue)
{
	if(g_pQueryQueue[playerid] != queue) return QUERY_COLLISION(THREAD_Register_2);
	new iRegID = cache_insert_id();
	SetPVarInt(playerid, "RegID", iRegID);
	SetPVarInt(playerid, "Style", 4);
	g_PlayerFlags{playerid} |= e_LOGGED_IN;
	return 1;
}

forward THREAD_Changename(playerid, inputtext[], queue);
public THREAD_Changename(playerid, inputtext[], queue)
{
	if(g_pQueryQueue[playerid] != queue) return QUERY_COLLISION(THREAD_Changename);
	new rows, fields;
	cache_get_row_count(rows);
	cache_get_field_count(fields);
	if(rows)
	{
		SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Névváltás: {FF0000}Ez a név már használatban van.");
		ChangeNameDialog(playerid);
		return 1;
	}
	new szOldName[MAX_PLAYER_NAME + 1], pRegID = GetPVarInt(playerid, "RegID");
	GetPlayerName(playerid, szOldName, sizeof(szOldName));
	if(SetPlayerName(playerid, inputtext) != 1)
	{
		SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Névváltás: {FF0000}Az általad beírt név nem megfelelõ!");
		ChangeNameDialog(playerid);
		return 1;
	}
	getdate(year, month, day);
	gettime(hour, minute, second);
	format(g_szQuery, sizeof(g_szQuery), "INSERT INTO `namechanges`(id, reg_id, oldname, newname, time) VALUES(0, %d, '%s', '%s', '%02d.%02d.%02d/%02d.%02d.%02d')", pRegID, szOldName, inputtext, year, month, day, hour, minute, second);
	mysql_pquery(SQL, g_szQuery);
	format(g_szQuery, sizeof(g_szQuery), "UPDATE `players` SET `name` = '%s' WHERE `reg_id` = %d", inputtext, pRegID);
	mysql_pquery(SQL, g_szQuery);
	SendClientMessagef(playerid, 0x00FF00FF, "{0080FF}Névváltás: {00FF00}Sikeresen megváltoztattad a neved. Új neved: {00FFFF}%s{00FF00}.", inputtext);
	return 1;
}

forward THREAD_Changepass(playerid, password[], queue);
public THREAD_Changepass(playerid, password[], queue)
{
	if(g_pQueryQueue[playerid] != queue) return QUERY_COLLISION(THREAD_Changepass);
	new szOldPass[21], szEscaped[21], pRegID = GetPVarInt(playerid, "RegID");
	cache_get_value_index(0, 0, szOldPass);
	format(g_szQuery, sizeof(g_szQuery), "UPDATE `players` SET `pass` = '%e' WHERE `reg_id` = %d", password, pRegID);	mysql_pquery(SQL, g_szQuery);
	getdate(year, month, day);
	gettime(hour, minute, second);
	format(g_szQuery, sizeof(g_szQuery), "INSERT INTO `namechanges_p`(id, reg_id, name, oldpass, newpass, time) VALUES(0, %d, '%s', '%s', '%s', '%02d.%02d.%02d/%02d.%02d.%02d')", pRegID, pName(playerid), szOldPass, szEscaped, year, month, day, hour, minute, second);
	mysql_pquery(SQL, g_szQuery);
	SendClientMessagef(playerid, 0x00FF00FF, "{0080FF}Jelszóváltás: {00FF00}Sikeresen megváltoztattad a jelszavad. Új jelszavad: {00FFFF}%s{00FF00}.", password);
	return 1;
}

forward THREAD_Findplayer(playerid, inputtext[], queue);
public THREAD_Findplayer(playerid, inputtext[], queue)
{
	if(g_pQueryQueue[playerid] != queue) return QUERY_COLLISION(THREAD_Findplayer);
	new szFetch[12], szRegDate[24], szLaston[24], iData[6];
	cache_get_value_index_int(0, 0, iData[0]);
	iData[0] = 1;
	cache_get_value_index(0, 4, szRegDate);
	cache_get_value_index(0, 5, szLaston);
	cache_get_value_index_int(0, 6, iData[1]);
	iData[1] = 1;
	cache_get_value_index_int(0, 7, iData[2]);
	iData[2] = 1;
	cache_get_value_index_int(0, 8, iData[3]);
	iData[3] = 1;
	cache_get_value_index_int(0, 9, iData[4]);
	iData[4] = 1;
	cache_get_value_index_int(0, 10, iData[5]);
	iData[5] = 1;
	switch(iData[5])
	{
		case FIGHT_STYLE_NORMAL: szFetch = "Normál";
	   	case FIGHT_STYLE_BOXING: szFetch = "Boxoló";
	   	case FIGHT_STYLE_KUNGFU: szFetch = "Kungfu";
		case FIGHT_STYLE_KNEEHEAD: szFetch = "Kneehead";
		case FIGHT_STYLE_GRABKICK: szFetch = "Grabkick";
		case FIGHT_STYLE_ELBOW: szFetch = "Elbow";
	}
	SendClientMessagef(playerid, 0x00FF00FF, "Név: %s, ID: %d, RegID: %d, Pénz: %d, XP: %d", inputtext, playerid, iData[0], iData[1], iData[2]);
	SendClientMessagef(playerid, 0x00FF00FF, "Ölések: %d, Halálok: %d, Arány: %.2f, Ütés Stílus: %s", iData[3], iData[4], (iData[3] && iData[4]) ? (floatdiv(iData[3], iData[4])) : (0.0), szFetch);
	SendClientMessagef(playerid, 0x00FF00FF, "Regisztáció ideje: %s, Utoljára a szerveren: %s", szRegDate, szLaston);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	if(IsPlayerConnected(killerid) && killerid != INVALID_PLAYER_ID)
	{
		SetPVarInt(killerid, "Kills", GetPVarInt(killerid, "Kills") + 1);
	}
	SetPVarInt(playerid, "Deaths", GetPVarInt(playerid, "Deaths") + 1);
	return 1;
}

forward THREAD_Stats(playerid, queue);
public THREAD_Stats(playerid, queue)
{
	if(g_pQueryQueue[playerid] != queue) return QUERY_COLLISION(THREAD_Stats);
	new RegDate[24], Laston[24], szStyle[24], Kills = GetPVarInt(playerid, "Kills"), Deaths = GetPVarInt(playerid, "Deaths");
	cache_get_value_index(0, 0, RegDate);
	cache_get_value_index(0, 1, Laston);
	switch(GetPlayerFightingStyle(playerid))
	{
		case FIGHT_STYLE_NORMAL: szStyle = "Normál";
	   	case FIGHT_STYLE_BOXING: szStyle = "Boxoló";
	   	case FIGHT_STYLE_KUNGFU: szStyle = "Kungfu";
		case FIGHT_STYLE_KNEEHEAD: szStyle = "Kneehead";
		case FIGHT_STYLE_GRABKICK: szStyle = "Grabkick";
		case FIGHT_STYLE_ELBOW: szStyle = "Elbow";
	}
	SendClientMessagef(playerid, 0x00FF00FF, "Név: %s, ID: %d, RegID: %d, Pénz: %d, XP: %d", pName(playerid), playerid, GetPVarInt(playerid, "RegID"), GetPlayerMoney(playerid), GetPlayerScore(playerid));
	SendClientMessagef(playerid, 0x00FF00FF, "Ölések: %d, Halálok: %d, Arány: %.2f, Ütés Stílus: %s", Kills, Deaths, (Kills && Deaths) ? (floatdiv(Kills, Deaths)) : (0.0), szStyle);
	SendClientMessagef(playerid, 0x00FF00FF, "Regisztáció ideje: %s, Utoljára a szerveren: %s", RegDate, Laston);
	return 1;
}

forward THREAD_FindplayerDialog(playerid, reszlet[], queue);
public THREAD_FindplayerDialog(playerid, reszlet[], queue)
{
	if(g_pQueryQueue[playerid] != queue) return QUERY_COLLISION(THREAD_FindplayerDialog);
	new rows, fields;
	cache_get_row_count(rows);
	cache_get_field_count(fields);
	if(!rows)
	{
		SendClientMessagef(playerid, 0x00FF00FF, "{0080FF}Játékoskeresés: {FF0000}Nincs találat a(z) {FF4040}'%s' {FF0000}részletre.", reszlet);
		return 1;
	}
	else if(rows > 250)
	{
		SendClientMessagef(playerid, 0x00FF00FF, "{0080FF}Játékoskeresés: {FF0000}A(z) '%s' részletre több, mint 180 találat van{FF4040}(%d){FF0000}.", reszlet, rows);
		return 1;
	}
	new x, szName[MAX_PLAYER_NAME], str[64];
	g_szDialogFormat[0] = EOS;
	for( ; x != rows; x++)
	{
		cache_get_value_index(x, 0, szName);
		strcat(g_szDialogFormat, szName);
		strcat(g_szDialogFormat, "\n");
	}
	format(str, sizeof(str), "{00FF00}Találatok a(z) {00FFFF}'%s' {00FF00}részletre.. {00FF00}(%d)", reszlet, x);
	ShowPlayerDialog(playerid, DIALOG_FINDPLAYER, DIALOG_STYLE_LIST, str, g_szDialogFormat, "{00FF00}Tovább", "{FF0000}Bezár");
	return 1;
}

stock LoginDialog(playerid)
{
	new str[64];
	format(str, sizeof(str), "{0080FF}Bejelentkezés: {%06x}%s(%d)", GetPlayerColor(playerid) >>> 8, pName(playerid), playerid);
	ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, str, !"{FFFFFF}Ez a felhasználó már regisztrálva van. Írd be a meglévõ jelszavad a bejelentkezéshez:", !"{00FF00}Tovább", !"{FF0000}Bezár");
	return 1;
}

stock RegisterDialog(playerid)
{
	new str[64];
	format(str, sizeof(str), "{0080FF}Regisztráció: {%06x}%s(%d)", GetPlayerColor(playerid) >>> 8, pName(playerid), playerid);
	ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, str, !"{FFFFFF}Ez a felhasználó még nincs regisztrálva. Írd be a leendõ jelszavad a regisztrációhoz:", !"{00FF00}Tovább", !"{FF0000}Bezár");
	return 1;
}

stock LoginPlayer(playerid)
{
	new iPVarSet[6], iRegID = GetPVarInt(playerid, "LineID");
	if(!iRegID) return printf("Rossz RegID. Játékos: %s(%d) (regid: %d)", pName(playerid), playerid, iRegID);
	SetPVarInt(playerid, "RegID", iRegID);
	cache_get_value_index_int(0, 0, iPVarSet[0]);
	iPVarSet[0] = 1;
	cache_get_value_index_int(0, 6, iPVarSet[1]);
	iPVarSet[1] = 1;
	cache_get_value_index_int(0, 7, iPVarSet[2]);
	iPVarSet[2] = 1;
	cache_get_value_index_int(0, 8, iPVarSet[3]);
	iPVarSet[3] = 1;
	cache_get_value_index_int(0, 9, iPVarSet[4]);
	iPVarSet[4] = 1;
	cache_get_value_index_int(0, 10, iPVarSet[5]);
	iPVarSet[5] = 1;
	SetPVarInt(playerid, "Cash", iPVarSet[1]); 
	SetPlayerScore(playerid, iPVarSet[2]);
	SetPVarInt(playerid, "Kills", iPVarSet[3]);
	SetPVarInt(playerid, "Deaths", iPVarSet[4]);
	SetPVarInt(playerid, "Style", iPVarSet[5]);
	g_PlayerFlags{playerid} |= e_LOGGED_IN;
	return 1;
}

stock SavePlayer(playerid, regid)
{
	if(IsPlayerNPC(playerid)) return 1;
	if(g_PlayerFlags{playerid} & (e_LOGGED_IN | e_FIRST_SPAWN) == (e_LOGGED_IN | e_FIRST_SPAWN))
	{
		getdate(year, month, day);
		gettime(hour, minute, second);
		format(g_szQuery, sizeof(g_szQuery), "UPDATE `players` SET `laston` = '%02d.%02d.%02d/%02d.%02d.%02d', `money` = %d, `score` = %d, `kills` = %d, `deaths` = %d, `fightingstyle` = '%d' WHERE `reg_id` = %d",
		year, month, day, hour, minute, second, GetPlayerMoney(playerid), GetPlayerScore(playerid), GetPVarInt(playerid, "Kills"), GetPVarInt(playerid, "Deaths"), GetPlayerFightingStyle(playerid),
		regid);
		mysql_pquery(SQL, g_szQuery);
	}
	return 1;
}

stock pName(playerid)
{
	static s_szName[MAX_PLAYER_NAME];
	GetPlayerName(playerid, s_szName, sizeof(s_szName));
	return s_szName;
}

CMD:stats(playerid, params[])
{
	format(g_szQuery, sizeof(g_szQuery), "SELECT `reg_date`, `laston`, `money`, `score` FROM `players` WHERE `reg_id` = %d", GetPVarInt(playerid, "RegID"));
	mysql_pquery(SQL, g_szQuery, "THREAD_Stats", "dd", playerid, g_pQueryQueue[playerid]);
	return 1;
}

CMD:changename(playerid, params[])
{
	ChangeNameDialog(playerid);
	return 1;
}

CMD:changepass(playerid, params[])
{
	ShowPlayerDialog(playerid, DIALOG_CHANGEPASS, DIALOG_STYLE_PASSWORD, "{0080FF}Jelszóváltás", "{FFFFFF}Írd be a leendõ jelszavad: \n\n", "{00FF00}Tovább", "{FF0000}Bezár");
	return 1;
}

CMD:findplayer(playerid, params[])
{
	if(isnull(params)) return SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Játékoskeresés: {FF4040}/findplayer <névrészlet>");
	if(strlen(params) > MAX_PLAYER_NAME) return SendClientMessage(playerid, 0x00FF00FF, "{0080FF}Játékoskeresés: {FF0000}Az általad beírt részlet nem megfelelõ{FF4040}(3-20){FF0000}!");
	format(g_szQuery, sizeof(g_szQuery), "SELECT `name` FROM `players` WHERE `name` LIKE '%s%s%s'", "%%", params, "%%");
	mysql_pquery(SQL, g_szQuery, "THREAD_FindplayerDialog", "dsd", playerid, params, g_pQueryQueue[playerid]);
	return 1;
}

CMD:restart(playerid, params[])
{
	SendRconCommand("gmx");
	return 1;
}

/* sql faszfelállító
CREATE TABLE IF NOT EXISTS `connections` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(21) NOT NULL,
  `ip` varchar(16) NOT NULL,
  `serial` varchar(128) NOT NULL,
  `time` varchar(24) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `namechanges` (
  `id` smallint(5) NOT NULL AUTO_INCREMENT,
  `reg_id` mediumint(8) NOT NULL,
  `oldname` varchar(21) NOT NULL,
  `newname` varchar(21) NOT NULL,
  `time` varchar(24) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `reg_id` (`reg_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `namechanges_p` (
  `id` smallint(5) NOT NULL AUTO_INCREMENT,
  `reg_id` mediumint(8) NOT NULL,
  `name` varchar(24) NOT NULL,
  `oldpass` varchar(21) NOT NULL,
  `newpass` varchar(21) NOT NULL,
  `time` varchar(24) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `reg_id` (`reg_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `players` (
  `reg_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(24) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `ip` varchar(20) NOT NULL,
  `pass` varchar(20) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `reg_date` varchar(24) NOT NULL,
  `laston` varchar(24) NOT NULL,
  `money` int(11) NOT NULL DEFAULT '0',
  `score` int(11) NOT NULL DEFAULT '0',
  `kills` mediumint(11) unsigned NOT NULL DEFAULT '0',
  `deaths` mediumint(11) unsigned NOT NULL DEFAULT '0',
  `fightingstyle` enum('4','5','6','7','15','16') NOT NULL DEFAULT '4',
  PRIMARY KEY (`reg_id`),
  KEY `name` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 ROW_FORMAT=DYNAMIC;
*/
