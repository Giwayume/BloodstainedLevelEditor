# Bloodstained Level Editor

An WORK IN PROGRESS level editor for Bloodstained: Ritual of the Night.

![Editor Preview](https://raw.githubusercontent.com/giwayume/BloodstainedLevelEditor/master/Screenshots/EditorDemoCollisionBoxes.png)

While making changes to a level, changes are automatically saved. Use the "Package -> Test In-Game" option in the menu to test your changes.

## Mouse/Keyboard Controls:

**General:**

| Key                          | Description                 |
|------------------------------|-----------------------------|
| Ctrl + Z                     | Undo the last action        |
| Ctrl + Y or Ctrl + Shift + Z | Redo the last undone action |

**In menus:**

| Key                | Description                         |
|--------------------|-------------------------------------|
| Left Mouse Button  | Select an item                      |
| Right Mouse Button | Context menu for additional options |
| Mouse Wheel        | Scroll when a scrollbar is visible  |
| Delete             | Delete the selected item            |

**When focused on the 3D room preview:**

| Key                       | Description                                                                       |
|---------------------------|-----------------------------------------------------------------------------------|
| Left Mouse Button         | Select an object                                                                  |
| Shift + Left Mouse Button | Select multiple objects                                                           |
| Right Mouse Button        | Click and hold to rotate camera view                                              |
| W/A/S/D                   | Move the camera view in the walking plane, similar to video game walking controls |
| Q/E                       | Move the camera view up/down                                                      |
| Delete                    | Delete the selected object(s)                                                     |

**When focused on the map preview:**

| Key                | Description                            |
|--------------------|----------------------------------------|
| Left Mouse Button  | Select a room. Double click to edit it |
| Right Mouse Button | Hold and drag to pan the view          |
| Mouse Wheel        | Zoom in/out                            |

## Target functionality:
- [ ] Add/Remove enemies from any room
- [x] Edit the placement of any 3D static mesh in any room or remove them
    - [x] Undo/redo history
    - [x] Visual transform cursor
        - [x] Translate meshes
            - [ ] Translation on 2 axis at once
        - [x] Scale meshes
            - [ ] Uniform scaling shortcut
        - [x] Rotate meshes
        - [ ] Snapping to unit increments
    - [x] Inspector
        - [x] Edit transform numbers directly
    - [ ] Load textures/materials as best as we can
    - [x] Remove meshes
- [ ] Add any existing 3D model in the game to any room as a static mesh
- [x] Lights
    - [ ] Add
    - [x] Edit
    - [x] Remove
    - [x] Point lights
    - [x] Spot lights
    - [ ] Directional lights
    - [ ] Temporary solution: allow deletion of light/shadow maps, auto disable static lights, auto convert stationary to movable
    - [ ] Permanent solution: figure out how to create light/shadow maps & implement ray traced map baker in editor.
- [ ] Support "Splines" (used in many levels for the basic level geometry, especially the underground levels)
- [ ] Collision boxes
    - [ ] Add
    - [x] Remove
    - [x] Transform
- [ ] Disable cutscenes
- [ ] Add/Remove NPCs from any room
- [ ] Simulate game camera perspective
- [ ] Edit map room placement, reorganize rooms anywhere
- [ ] Edit room "doors"
- [ ] Add new rooms to the game
- [ ] Visualizers for room doors, room bounds, game grid, playing field (where player walks)