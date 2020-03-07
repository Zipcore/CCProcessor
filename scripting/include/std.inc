#define PlName(%0) name = %0
#define PlAuth(%0) author = %0
#define PlDesc(%0) description = %0
#define PlVer(%0) version = %0
#define PlUrl(%0) url = %0

	#if defined STANDART_INFO
		#if !defined PlugAuth
			#define PlugAuth "nullent?" 
		#endif

		#if !defined PlugUrl
			#define PlugUrl "discord.gg/ChTyPUG" 
		#endif

		#if !defined PlugName
			#define PlugName "unknown" 
		#endif

		#if !defined PlugVer
			#define PlugVer "1.1" 
		#endif

		#if !defined PlugDesc
			#define PlugDesc "unknown" 
		#endif
	#endif

public Plugin myinfo = 
{
	PlName(PlugName),
	PlAuth(PlugAuth),
	PlDesc(PlugDesc),
	PlVer(PlugVer),
	PlUrl(PlugUrl)
};


#define SZ(%0)	%0, sizeof(%0)
#define SZF(%0) SZ(%0)

#define FORITER(%0,%1,%2) for(int %0 = %1; %0 < %2; %0++)
#define BUILD(%0,%1) BuildPath(Path_SM, SZ(%0), %1)
#define HOOKCVAR(%0,%1) %0(FindConVar(%1), NULL_STRING, NULL_STRING)

#define PMP PLATFORM_MAX_PATH
#define MPL MAXPLAYERS+1
#define MTL MAX_TARGET_LENGTH
#define MNL MAX_NAME_LENGTH