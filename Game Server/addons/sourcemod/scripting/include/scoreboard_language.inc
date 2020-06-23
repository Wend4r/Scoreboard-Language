#if defined _scoreboard_language_included
 #endinput
#endif
#define _scoreboard_language_included

/**
 * Called when sets Persona Level.
 * 
 * @param iClient          Client index.
 * @param iLevel           Level index from core.
 * @param iOldLevel        Original level index.
 *
 * @noreturn
 */
forward void Scoreboard_LoadPersonaLevel(int iClient, int iLevel, int iOldLevel);

/**
 * Sets current Persona Level.
 *
 * @param iClient          Client index.
 * @param iLevel           Level index. -1 for setting original level.
 * @param bPriority        Sets if already exists.
 *
 * @return                 Is successful sets.
 */
native bool Scoreboard_SetPersonaLevel(int iClient, int iLevel = -1, bool bPriority = false)

/**
 * Gets current Persona Level.
 *
 * @param iClient          Client index.
 * @param bIsOld           Is return the original level index.
 *
 * @return                 Level index.
 */
native int Scoreboard_GetPersonaLevel(int iClient, bool bIsOld = false);



public SharedPlugin __pl_scoreboard_language = 
{
	name = "scoreboard_language",
	file = "scoreboard_language.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_scoreboard_language_SetNTVOptional()
{
	MarkNativeAsOptional("Scoreboard_SetPersonaLevel");
	MarkNativeAsOptional("Scoreboard_GetPersonaLevel");
}
#endif
