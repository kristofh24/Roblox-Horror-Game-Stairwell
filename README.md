# Roblox Horror Game (Stairwell)

## Overview

**Timeline**: June 16, 2024 - December 19, 2025 (18 months)  
**Approach**: Feature-driven development, incrementally building systems based on gameplay needs and user feedback

**Version Convention**: release.major.minor      
**First Release**: January 14, 2024   
**Current Version**: pre-alpha 1.7.3

This is a multiplayer horror game hosted on the Roblox platform that has been in development for 2 years. The game sparked from a simple idea to have a game set in a dark stairwell and quickly developed into a game of survival in an unforgiving environment. Both the early versions and currently in progress version focus on procedurally generated maps, although in drastically different styles. Throughout development I have heavily focused on crafting a convincing environment. I am especially proud of the sound design and visual effects for when the running monster spawns and descends the stairwell, causing the player to see flashing red while hearing their own heartbeat as they run for the nearest hiding spot. Additionally, as the monster passes by doors in the stairwell, it slams them open with a loud thud, further terrifying the player. Below is a detailed development flow to aid with understanding my process.

*Repository note:* Because this project is created using Roblox, the repository only contains key script files nested in folders named to appropriately represent the hierarchy of the project. Roblox has no direct GitHub integration, and thus the complete project source code (including models, sounds, etc.) cannot be included.

---

## Development Flow

### Initial Game Idea
**Objective**: Create and design a horror game set in a stairwell decending endlessly, requiring the player to survive and make it as deep as possible

**Components**:
1. **World Design**:
   - Concrete stairwell with rusted metallic rails
   - Dirty doors that make loud noise when opened
   - Rooms containing items for survival (batteries, adrenaline)
   - Scattered fluorescent lights that constantly buzz
   - Metallic vents can be used to hide

2. **Main_OLD.lua**:
   - Player management
   - Monster spawning logic
   - Item spawning logic
   - Dynamic cell loading/unloading system

3. **Framework.lua**
   - First-person camera effects
   - Player movement (walk, crouch)
   - Flashlight with battery system
   - Interactions (doors, vents, items)

---

### Release 1.5.0 (June 16, 2024)
**Goal**: Expand and refine existing game systems (patch notes begin at this version)

**Components**:
1. **LightDetection.lua**
   - Real-time light detection at arbitrary points
   - Support for multiple light types (PointLight, SpotLight, SurfaceLight)
   - Raycast-based detection

2. **Framework.lua**
   - Introduced use of DeltaTime for rendering calculations

3. **Monster1/Behavior.lua**
   - Logic to break through doors blocked by cracked planks

**Key Features Introduced**:
- Players can hide in the dark from monsters
- Planks blocking doors can crack
- Monsters can break through cracked planks
- Performance optimizations (60+ FPS support)

---

### Bug Fix (June 16, 2024 - Pre-alpha 1.5.1)
**Goal**: Polish previously added features

**Components Enhance**:
1. **Main_OLD.lua**:
   - Introduced overlap prevention logic to fix chunks overlapping

---

### Release 1.6.0 (July 1, 2024)
**Goal**: Create a more immersive environment and enhance monster behavior

**Components Enhanced**:
1. **World Design**:
   - Character models to override Roblox avatars
   - Floor number signs for added detail
   - Monster model

1. **Framework.lua**
   - Sanity system integration
   - Spectating
   - Enhanced UI systems

2. **Monster1/Behavior.lua**
   - Logic to only attack players in dark when they are too close

**Key Features Introduced**:
- Spectating
- Sanity system added
- Running monster model
- Monsters attack players standing too close in the dark
- Floor number signs
- Character model

---

### Balancing (July 1, 2024 - Pre-alpha 1.6.1)
**Goal**: Balance and polish previously added features

**Components Enhanced**:
1. **Framework.lua**
   - Adjusted sanity drain rates for better gameplay balance

2. **Monster1/Behavior.lua**
   - Balanced monster behavior

---

### Release 1.7.0 (July 18, 2024)
**Goal**: Add new monster and item and rework item spawning and sanity system

**Components Enhanced**:
1. **World Design:**:
   - Eyes model (added Monster2 to hierarchy)

2. **Main_OLD.lua**
   - Eyes monster spawn system
   - Reworked item spawn system with weighted probabilities
   - Reworked sanity drain system

3. **Eyes/Behavior.lua**:
   - Eyes despawns (with effect) when light level at position above 3
   - Eyes attacks players standing too close then despawns

4. **Framework.lua**
   - Interaction with sanity restoration item
   - Jumpscare effect when attacked by Eyes

5. **RemoteHandler.lua**
   - Support for sanity restoration item

**Key Features Introduced**:
- New monster (Eyes)
- Sanity juice item to restore sanity
- Reworked item spawn system
- Reworked sanity drain system

---

### Balancing & Bug Fix (July 19, 2024 - Pre-alpha 1.7.1)
**Goal**: Balance and polish previously added features

1. **Framework.lua**
   - Sanity drain when attacked by Eyes
   - Fixed end screen showing wrong depth
   - Sound system fixes for spectators

---

### Balancing & Bug Fix (July 20, 2024 - Pre-alpha 1.7.2)
**Goal**: Improve spectate system and balance and polish previously added systems

1. **Main_OLD.lua**:
   - Rebalanced item spawn chances

2. **Framework.lua**
   - Spectator stat viewing
   - Camera rotation fixes

---

### Map Generation Overhaul (July 20 - Present - In progress)
**Goal**: Overhaul map generation and world design; objective of game shifts away from being based in a stairwell

**Components Built**:
1. **gen.lua**
   - Generates map using pre-built tiles called *rooms*
   - Pivot point system for room connections
   - Room overlap prevention system using parts representing room bounding boxes
   - Recursive generation until map requirements reached
   - Computer room placement logic

2. **Main.lua**:
   - Condensed version of `Main_OLD.lua` for overhaul
   - Player management
   - Invokes map generation using `gen.lua`

**Key Features Introduced**:
- Complete map generation rewrite
- Procedural room placement
- Overlap prevention system

---

## Development Strategy

### Feature-Driven Architecture
```
Initial Game (World Design, Basic Systems)
    ↓
Release 1.5.0 (Light Detection, Hiding Mechanics)
    ↓
Release 1.6.0 (Sanity, Spectating, Enhanced Monsters)
    ↓
Release 1.7.0 (New Monster/Content, System Reworks)
    ↓
Map Generation Overhaul (Procedural Generation - Ongoing)
```

### Key Principles
- **Iterative Refinement**: Continuously balance and improve game
- **Modular Design**: Components developed separately for easier modification, updates, and fixes
- **Player Experience**: Prioritize atmosphere and horror feel

---

## Timeline

| Date | Version | Focus | Major Changes |
|------|---------|-------|---------------|
| **January 14 - June 16, 2024** | Undocumented | Initial Game | World design, player mechanics, monster and item spawning logic |
| **June 16, 2024** | 1.5.0 | Release | Light detection, hiding mechanics, planks, DeltaTime rendering |
| **June 16, 2024** | 1.5.1 | Bug Fix | Fixed room overlap issues |
| **July 1, 2024** | 1.6.0 | Release | Sanity system, spectating, character models, enhanced monster behavior |
| **July 1, 2024** | 1.6.1 | Balancing | Adjusted sanity drain, balanced monster behavior |
| **July 18, 2024** | 1.7.0 | Release | Eyes monster, sanity juice item, reworked item/sanity systems |
| **July 19, 2024** | 1.7.1 | Balancing & Bug Fix | Sanity drain from Eyes attacks, fixed depth tracking, spectator sound fixes |
| **July 20, 2024** | 1.7.2 | Balancing & Bug Fix | Rebalanced item spawns, spectator stat viewing, camera fixes |
| **July 20, 2024 - Present** | In Progress | Map Generation Overhaul | Complete map generation rewrite, procedural room placement, gen.lua system |

---

## Development Decisions

1. **Sanity System** - Focus on psychological horror element beyond jump scares
2. **Procedural Generation** - Focus on improved map generation for better user experience
3. **Modular Architecture** - Separated core systems for maintainability
4. **Iterative Approach** - Continuously adjusted sanity drain and item spawn rates to maximize player enjoyment

---