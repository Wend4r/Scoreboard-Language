/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This file is part of the SourceMod/SourcePawn SDK.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */
 
#if defined _scoreboard_language_included
 #endinput
#endif
#define _scoreboard_language_included

/**
 * Called when the admin menu is ready to have items added.
 * 
 * @param iClient          Client index.
 * @param iLevel           Level index from core. As reference.
 * @param iOldLevel        Original level index.
 *
 * @return                 Plugin_Handled for block.
 */
forward Action Scoreboard_LoadPersonaLevel(int iClient, int &iLevel, int iOldLevel);

/**
 * Called after the admin menu is ready to have items added.
 * 
 * @param iClient          Client index.
 * @param iLevel           Level index from core.
 * @param iOldLevel        Original level index.
 *
 * @noreturn
 */
forward void Scoreboard_LoadPersonaLevelPost(int iClient, int iLevel, int iOldLevel);

/**
 * Sets current Persona Level.
 *
 * @param iClient          Client index.
 * @param iLevel           Level index. -1 for setting original level.
 * @param bPriority        Sets if already exists.
 *
 * @noreturn
 */
native void Scoreboard_SetPersonaLevel(int iClient, int iLevel = -1, bool bPriority = false);

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
