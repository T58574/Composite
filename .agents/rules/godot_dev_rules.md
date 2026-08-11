# Godot 4.7 & Composite Project Conventions

## 1. Local Executable & CLI Operations
* **Godot Executable Path**: `C:\Users\user\Documents\gamedev\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`
* **Headless Validation**: Always run headless check after editing GDScript or `.tscn` scenes:
  `& "C:\Users\user\Documents\gamedev\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --editor --quit`

## 2. GDScript 2 (Godot 4) Syntax Rules
* **Export Ranges**: Always use `@export_range(min, max, step)`, e.g., `@export_range(1.0, 10.0, 0.1) var length: float = 6.8`. Do NOT use `@export float_range(...)`.
* **Data Containers / Structs**: GDScript does not have a `struct` keyword. Use inner classes inheriting from `RefCounted` or `Object`:
  ```gdscript
  class ImpactResult extends RefCounted:
      var penetrated: bool = false
      var effective_thickness_mm: float = 0.0
  ```
* **SurfaceTool & Mesh Generation**: If using `SurfaceTool.generate_tangents()`, you MUST call `st.set_uv(...)` before adding vertices with `st.add_vertex(...)`.

## 3. Physics Engine (Godot-Jolt)
* **Jolt 3D Integration**: Godot 4.4+ natively includes Jolt Physics. Enable in `project.godot`:
  `physics/3d/physics_engine="Jolt"`

## 4. MCP Integration
* **CLI MCP Server**: `@coding-solo/godot-mcp` configured in `mcp_config.json` with `GODOT_PATH` pointing to the console executable.
* **Editor Plugin Bridge**: Internal plugin at `res://addons/godot_mcp/` listens on TCP port `127.0.0.1:7080`.

## 5. UI Control Node Input Filtering (mouse_filter)
* **Full-Screen Overlays**: Full-screen root `Control` and overlay container nodes (`UIOverlay`) MUST have `mouse_filter = 2` (`MOUSE_FILTER_IGNORE`).
* **Rationale**: Godot 4 defaults Control nodes to `mouse_filter = 0` (`MOUSE_FILTER_STOP`), which intercepts and consumes 100% of mouse clicks, camera drags, and keyboard events across the entire viewport.

## 6. Batch Launcher Script (.bat) Syntax
* **Path Escaping**: Do NOT use `"%~dp0"` inside quoted arguments in CMD (e.g., `"--path %~dp0"`), as trailing backslashes `\"` escape closing double-quotes in Windows CLI.
* **Standard Pattern**: Always navigate first and use relative path `.`:
  ```cmd
  @echo off
  cd /d "%~dp0"
  "C:\Users\user\Documents\gamedev\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" --path .
  ```
