Preview : https://youtu.be/O0O9BtxZ7fo?si=mPKYZbS5PxI2bpov

🔹 Animal Skinning: Allows players to skin specific dead animals found in the game world using ox_target.

🔹 Loot System: Rewards players with configurable amounts of meat and a chance-based skin drop upon successful skinning, managed via ox_inventory.

🔹 Required Tool: Skinning action requires the player to possess a specific, configurable item (e.g., skining_knife) in their inventory.

🔹 Sell System: Includes a configurable NPC ped (with model, location, and map blip) where players can sell their gathered hunting products for cash at predefined prices.

🔹 Progress & Interaction: Utilizes ox_lib for a visual progress bar during the skinning animation and provides clear notifications (with framework fallbacks).

🔹 Dual Framework Compatibility: Designed to work seamlessly with both QB/QBOX and ESX frameworks – easily switchable via a setting in the config.lua file.

🔹 Hunting Talent Tree & Level System

Level System: Players earn XP through hunting activities (e.g. skinning animals, selling items, etc.). Each time a player levels up, they receive 1 Talent Point.

Talent Tree:

Accessible via command: /hunting

Opens a UI displaying all available talents

Players can spend their Talent Points to unlock specific talents of their choice

Each talent provides unique benefits, such as:

Increased drop chances

More meat/skin rewards

Faster skinning time

Selling price bonuses

Hidden Admin Panel:

Only visible to users with admin permissions

Allows admins to:

Manage player XP

Add/remove levels

Reset talents

Fully control player progression

🔹 Tebex Integration (Monetization Ready)

Includes 2 purchasable items for Tebex:

XP Boost Item:

Grants extra XP or temporary XP boost when used

XP Reset Item:

Resets player XP and talents, allowing them to reallocate points

🔹 Dependency Requirement

This script now requires xrb-lib to function properly

Built to integrate seamlessly with modern resources like:

ox_lib

ox_target

ox_inventory

xrb-lib

🔹 Fully Configurable

XP rates, level caps, and talent effects can be easily configured in config.lua

Talent tree can be fully customized and expanded
