#define PlName(%0) name = %0
#define PlAuth(%0) author = %0
#define PlDesc(%0) description = %0
#define PlVer(%0) version = %0
#define PlUrl(%0) url = %0

#if !defined PlugName
	#define PlugName "unknown" 
#endif

#if !defined PlugVer
	#define PlugVer "1.0" 
#endif

#if !defined PlugDesc
	#define PlugDesc "unknown" 
#endif

public Plugin myinfo = 
{
	PlName(PlugName),
	PlAuth("nullent?"),
	PlDesc(PlugDesc),
	PlVer(PlugVer),
	PlUrl("discord.gg/ChTyPUG")
};


#define SZ(%0)	%0, sizeof(%0)
#define SZF(%0) SZ(%0)

#define FORITER(%0,%1,%2) for(int %0 = %1; %0 < %2; %0++)
#define BUILD(%0,%1) BuildPath(Path_SM, SZ(%0), %1)
#define _CVAR_INIT_CHANGE(%0,%1) %0(FindConVar(%1), NULL_STRING, NULL_STRING)
#define _CVAR_ON_CHANGE(%0) public void %0(ConVar cvar, const char[] szOldVal, const char[] szNewVal)

#define PMP PLATFORM_MAX_PATH
#define MPL MAXPLAYERS+1
#define MTL MAX_TARGET_LENGTH
#define MNL MAX_NAME_LENGTH