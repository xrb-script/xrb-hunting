Preview : https://youtu.be/O0O9BtxZ7fo?si=mPKYZbS5PxI2bpov

*   **Animal Skinning:** Allows players to skin specific dead animals found in the game world using `ox_target`.
*   **Loot System:** Rewards players with configurable amounts of meat and a chance-based skin drop upon successful skinning, managed via `ox_inventory`.
*   **Required Tool:** Skinning action requires the player to possess a specific, configurable item (e.g., `skining_knife`) in their inventory.
*   **Sell System:** Includes a configurable NPC ped (with model, location, and map blip) where players can sell their gathered hunting products for cash at predefined prices.
*   **Progress & Interaction:** Utilizes `ox_lib` for a visual progress bar during the skinning animation and provides clear notifications (with framework fallbacks).
*   **Dual Framework Compatibility:** Designed to work seamlessly with both **QBCore** and **ESX** frameworks – easily switchable via a setting in the `config.lua` file.
*   **Highly Configurable:** Allows easy modification of skinnable animals, meat/skin item names, drop amounts/chances, item sell prices, the required skinning tool, NPC details, and animation settings through the `config.lua`.
*   **Dependency Integration:** Built specifically for use with modern resources like `ox_lib`, `ox_target`, and `ox_inventory`.
