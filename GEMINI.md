# GEMINI & AI AGENT TECHNICAL INSTRUCTIONS

This document contains authoritative technical instructions, executable paths, compilation rules, and architecture invariants for AI agents working on the **Composite** project.

---

## 1. Environment & Executable Paths

* **Godot Console Executable**: `C:\Users\user\Documents\gamedev\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`
* **Godot GUI Executable**: `C:\Users\user\Documents\gamedev\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe`
* **Headless Validation Command**:
  ```powershell
  & "C:\Users\user\Documents\gamedev\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --editor --quit
  ```
  *(Always run this command after modifying `.gd` scripts or `.tscn` scene files to ensure zero syntax errors).*
* **Automated Unit & Integration Test Suite Command**:
  ```powershell
  & "C:\Users\user\Documents\gamedev\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless -s res://scripts/tests/test_runner.gd
  ```
  *(Runs the 6 automated test suites for ballistics, procedural builders, shooting, topology, card UI, and vertex dragging).*

---

## 2. GDScript 2 (Godot 4) Rules & Invariants

1. **Export Ranges**:
   * Always use `@export_range(min, max, step)`, e.g., `@export_range(1.0, 10.0, 0.1) var length: float = 6.8`.
   * **Do NOT** use `@export float_range(...)`.

2. **Data Structs**:
   * GDScript 2 does not have a `struct` keyword. Custom data containers must be inner classes inheriting from `RefCounted` or `Object`:
     ```gdscript
     class ImpactResult extends RefCounted:
         var penetrated: bool = false
         var effective_thickness_mm: float = 0.0
     ```

3. **SurfaceTool Procedural Meshes**:
   * When calling `SurfaceTool.generate_tangents()`, you **MUST** call `st.set_uv(...)` before adding vertices with `st.add_vertex(...)`.
   * Always call both `st.generate_normals()` and `st.generate_tangents()`.

4. **Mesh Coordinate Space Transformation**:
   * When matching world selection positions against local mesh vertices in `MeshEditor`, ALWAYS use `target.to_local(world_pos)` or `target.global_transform.affine_inverse() * world_pos`.
   * **Do NOT** use `basis.inverse() * world_pos` without subtracting global translation, as it misses node origin offset.

5. **UI Control Mouse Filtering (`mouse_filter`)**:
   * Full-screen root `Control` nodes and overlay containers (`UIOverlay`) **MUST** have `mouse_filter = 2` (`MOUSE_FILTER_IGNORE`).
   * Rationale: Godot 4 defaults Control nodes to `mouse_filter = 0` (`MOUSE_FILTER_STOP`), which intercepts and consumes all 3D Viewport mouse clicks, camera drags, and keyboard events across the entire screen.

6. **Windows Batch Launchers (`.bat`)**:
   * Never use `"%~dp0"` directly inside quoted arguments in CMD (e.g., `"--path %~dp0"`), because trailing backslashes `\"` escape closing double-quotes in Windows CLI.
   * Standard pattern:
     ```cmd
     @echo off
     cd /d "%~dp0"
     "C:\Users\user\Documents\gamedev\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" --path .
     ```

---

## 3. Physics & MCP Server Settings

* **Physics Engine**: Jolt 3D (`physics/3d/physics_engine="Jolt"` in `project.godot`).
* **MCP Integration**:
  * CLI Server: `@coding-solo/godot-mcp` configured in `mcp_config.json`.
  * Editor Plugin Bridge: `res://addons/godot_mcp/` listening on TCP port `127.0.0.1:7080`.
