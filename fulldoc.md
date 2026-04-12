This project is to create a 'World of Warcraft: Midnight' addon for game and API version 12.0.1. Be mindful of Blizzard's API usage and be compatible with UI policy.

The addons purpose is to log other players characters within the player raid group when we kill any raid boss, and for the player to look back on those logs within a cleanly displayed addon window to see and filter previously played with players that were successful in killing raid encounters. It only logs players that were in the raid group on a successful boss kill. Consider Blizzards API with "Recent Allies" social feature if useful.

I want a sleek modern dark/grey/slate theme design with respective class colours for the class and name info but also keep the addon overly lightweight and non-computing intensive, I do not really want to use default blizzard UI assets for the majority of the UI, feel free to nest blizzard UI assets for class colours, spec icons, class icons and role icons.

I want the main window frame of the addon to be moveable, scaleable (text size) and resizeable/corner dragged both vertically and horiztonally, but with a minimum for both to keep all info visible and a maximum.

The chat commands /ra and /raidallies will open the window, and also close the window if open. 

The main window to have the following information on the raid characters that were in the group ONLY on a boss kill: 
It may be more readable if we firstly have a history of raid encounters as a list and then clicking the log expands the below as nested data, or a new frame, if new frame, add a back button to go back to the main frame as it was when the user left it; Info to show - a small class and role icon (DPS, tank, healer) followed by the Character name-Realm, raid name, boss name and difficulty. 

If the log was an achievement for the current user (Ahead of the Curve, Cutting Edge), display the background of that log in a different colour, for AOTC it should be a gold colour, and for CE it should be red; keep text readable to not get lost on the background of these logs.
I also want an numberical indicator somewhere on the list for number of kills with this player, I do not want the number of kills to be it's own column; however you think best structured.

IMPORTANT; I do not want stacking logs, sure create a new log for each boss kill but if a character name already appears in the existing list, just add a tally to the boss kill count to that player already existing and display more info in tooltip hover (later described).

Difficulty colouring: I want green for "LFR", blue for "Normal", purple for "Heroic", orange for "Mythic".

Keyboard/visual functionality: Pressing escape should close all windows related to the addon, there should be an 'X' in the top right of the main frame, this will close all frames the addon has open.

Important filtering!: Filter button will appear to the left of the 'X', it should open new frame window which is anchored to the right side of the main frame window. I want to be able to filter by raid difficulty via dropdown (including an 'Any Difficulty' option), raids (with a toggle/checkbox), AOTC/CE achievement kills, number of kills and a checkbox/toggle for 'Full clear'.
Full clear logs are if you stayed with the same characters throughout the raid encounter, for example in WoW:Midnight, there's a raid called "March on Quel'Danas" with the bosses "Belo'ren, Child of Al'ar" and "Midnight Falls". If you were with the same characters throughout the raid encounter March on Quel'Danas and killed all bosses within that raid, that is a full clear. If there is an API for this then use that. Essentially detect if same group stayed for entire raid and killed all bosses, use API if available, otherwise infer logically.
Use image as reference for filter style.
I also want a "Guild Clear" toggle filter, this matches logs that include characters from the same guild as the player.

Options button: 
I want an options button to the left of the filters button, this will replace the filter frame if open, and the filter frame will replace the options frame if open. 
Options: 
I want a slider to change window opacity from 0-100%, this changes all elements except the text. 
I want a font size slider from 10-18 font sizes. 
I also want an addon font option as a dropdown to select different fonts available.
Allow a toggle/checkbox option for the players realm only, so check what realm the player that is using the addon is on, and then filter by those players only.

Hovering behaviour/tooltip: 
Hovering a player in the list should display what would normally display depending on current users addons if hovering a player. It should also display time since that log was complete eg. "30 seconds ago", "2 days ago", "11 months ago", "4 years, 2 months" ago.
I also want a right click option available for players on the list, it should display standard WoW right click options that are available and within Blizzard/WoW API and Addon ToS capabilities, invite, whisper, ignore and if user has RaiderIO Addon installed, show RaiderIO Profile etc.

At the bottom in the footer of the mainframe I want a "Support me" button. This opens a standard Blizzard_Static_Popup_Game/GameDialog XML frame (without closing any frames) to copy a link to 'https://ko-fi.com/nosebug'.
I also want "Created by nosebug" in the footer.


Follow a similar style to the image attached.
@s-research/  will be deleted BY ME eventually, do not directly reference in final code. 

I want this data to be saved in a savevariables db within the WTF folder for WoW, as is commonly used in addon practice.

IMPORTANT! - Ideally I want a shippable addon that will eventually go onto CurseForge for other players to use, keep it lightweight but effective and visually cohesive. Keep project directory and structure clean and within good Addon practice. Avoid unnecessary dependencies.

Future plans and updates, keep these in mind for future:
Displaying icons above players characters in game if they are in your logs.
Options and filtering additions and changes.