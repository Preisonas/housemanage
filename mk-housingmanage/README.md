# mk-housingmanage (React UI Version)

A modern React-based housing management UI for FiveM, designed to work with `mk-housing`.

## Features

- 🏠 Multi-house selection screen
- 🔐 Lock/unlock house doors
- 👥 Add and remove residents
- 💰 Pay housing taxes
- 🔧 Workshop upgrade system
- 📱 Modern tablet-style interface

## Requirements

- [ESX Framework](https://github.com/esx-framework/esx-legacy)
- [oxmysql](https://github.com/overextended/oxmysql)
- [mk-housing](https://github.com/Preisonas/mk-housing) (your housing base script)

## Installation

### 1. Build the React UI

```bash
npm install
npm run build
```

### 2. Set up the Resource

1. Create folder `mk-housingmanage` in your `resources` folder
2. Copy these files:
   - `client.lua`
   - `server.lua`  
   - `fxmanifest.lua`
3. Create `html/` folder inside the resource
4. Copy built files from `dist/`:
   - `dist/index.html` → `html/index.html`
   - `dist/assets/` → `html/assets/`

### 3. Database

The script uses your existing `mk_houses` table. Make sure it has these columns:
- `id` - House ID
- `owner_identifier` - Player identifier
- `street` - Street name
- `area` - Area name  
- `price` - House price
- `locked` - Lock state (0/1)
- `residents` - JSON array of resident identifiers
- `due_at` - Tax due timestamp
- `max_residents` - Max resident count
- `garage_spaces` - Garage spots
- `workshop_level` - Workshop upgrade level (0-3)

If you need to add missing columns:
```sql
ALTER TABLE mk_houses ADD COLUMN IF NOT EXISTS workshop_level INT DEFAULT 0;
ALTER TABLE mk_houses ADD COLUMN IF NOT EXISTS residents TEXT DEFAULT '[]';
ALTER TABLE mk_houses ADD COLUMN IF NOT EXISTS due_at INT DEFAULT NULL;
```

### 4. Start the Resource

Add to `server.cfg`:
```cfg
ensure mk-housingmanage
```

## Usage

### Commands
- `/housingtablet` - Opens the housing UI
- Default keybind: `F7`

### From Other Scripts
```lua
-- Open the housing tablet
TriggerEvent('mk-housingmanage:openUI')
```

## Callbacks Used

### From mk-housing (required)
- `mk-housing:getHouseState` - Gets house state (lock, residents, etc.)
- `mk-housing:setLocked` - Toggle lock
- `mk-housing:removeResident` - Remove resident

### New callbacks (this script)
- `mk-housingmanage:getPlayerHouses` - Get all player houses
- `mk-housingmanage:addResident` - Add resident with validation
- `mk-housingmanage:payTax` - Pay housing tax
- `mk-housingmanage:getWorkshopLevels` - Get workshop data
- `mk-housingmanage:startConstruction` - Start workshop upgrade

## Workshop Requirements

Level 1:
- $100
- Water x5
- Lockpick x1

Level 2:
- $50,000
- Construction Materials x24
- Construction Equipment x15

Level 3:
- $150,000
- Construction Materials x48
- Construction Equipment x30

## License

MIT
