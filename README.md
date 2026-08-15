# 🛡️ Composite — Advanced 3D Tank Physics, Ballistics & Modular Armor Sandbox

<div align="center">

[![Godot Engine](https://img.shields.io/badge/Godot-4.7%2B-478CBF?style=flat-square&logo=godotengine&logoColor=white)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/Language-GDScript_2.0-blue?style=flat-square)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
[![Jolt Physics](https://img.shields.io/badge/Physics_Engine-Jolt_3D-orange?style=flat-square)](https://github.com/godot-jolt/godot-jolt)
[![Status: Paused](https://img.shields.io/badge/Status-Paused%20%2F%20Archived-lightgrey?style=flat-square)](#-project-status)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

**A high-fidelity 3D military vehicle simulation, procedural mesh editor, and modular ballistics sandbox featuring dynamic ERA reactive armor, spall fragment dispersion, raycast suspension physics, and interactive track deformation.**

[Project Status](#-project-status) • [Features](#-key-features) • [Architecture](#-architecture) • [Ballistics Physics](#-ballistics--armor-mechanics) • [Quick Start](#-quick-start) • [License](#-license)

</div>

---

## ⏸️ Project Status

> [!NOTE]
> **DEVELOPMENT STATUS: PAUSED / ARCHIVED**
> Active development on this project is currently on hold. The repository is preserved in a working, completed state as an architectural reference and portfolio showcase for complex Jolt 3D vehicle physics, procedural mesh topology manipulation with `SurfaceTool`, and realistic ballistics/damage modeling in Godot 4.

---

## 📖 Overview

**Composite** is an advanced 3D vehicle engineering and combat sandbox built on **Godot 4** and the **Jolt 3D** physics engine. It simulates armored combat with engineering accuracy: projectiles follow realistic ballistic drop trajectories, compute angle-normalized armor penetration, interact with explosive reactive armor (ERA) tiles, and generate volumetric spall damage cones upon full penetration.

The project also includes a real-time **in-viewport 3D mesh editor** enabling players to drag vertices, dynamically reshape hulls and turrets, adjust suspension geometries, and customize modular vehicle loadouts.

---

## ✨ Key Features

- 🎯 **Advanced Modular Ballistics & Armor Physics**
  - **Slope-Normalized Penetration**: Implements projectile kinetic energy equations, velocity drop curves, and impact angle normalization (ricochet checks vs. normalized thickness $T_{\text{eff}} = T / \cos(\theta)$).
  - **Dynamic Explosive Reactive Armor (ERA)**: Individual reactive tiles that detonate upon projectile contact, degrading incoming HEAT/APFSDS penetration values.
  - **Volumetric Spall Cone Dispersion**: Simulates lethal internal fragmentation clouds generated behind penetrated armor plates damaging vehicle modules and crew.
- 🚜 **Raycast Suspension & Dynamic Track Physics**
  - Multi-wheel raycast suspension with independent spring stiffness, rebound damping, center-of-mass balancing, and real-time visual track deformation.
- 📐 **Interactive 3D Procedural Mesh & Topology Editor**
  - Live vertex drag manipulation allowing dynamic reshaping of hull and turret geometry.
  - Built-in `SurfaceTool` procedural mesh generator calculating normal vectors, UV mapping, and tangent spaces on the fly.
- 🔭 **Fire Control System (FCS) & Thermal Optics**
  - Laser rangefinder with automatic sight reticle elevation drop, target lead calculation, thermal imaging shaders, and stabilization modes.
- 🧪 **Automated Headless Test Suite**
  - Integrated headless test runner executing 6 validation suites covering ballistics math, procedural builders, shooting pipelines, topology editing, and card UI.

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                   Composite Sandbox Viewport                     │
│        (Godot 4 Viewport + 3D Viewport Controls + HUD Overlay)   │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ Scene Tree & Signal Bus
┌─────────────────────────────────▼────────────────────────────────┐
│                     Combat & Vehicle Core                        │
│                                                                  │
│  ┌────────────────────────┐  ┌────────────────────────────────┐  │
│  │ Ballistics Calculator  │  │ Raycast Suspension Physics     │  │
│  │ (De Marre, Ricochets)  │  │ (Springs, Dampers, Friction)   │  │
│  └────────────────────────┘  └────────────────────────────────┘  │
│  ┌────────────────────────┐  ┌────────────────────────────────┐  │
│  │ ERA & Spall Damage     │  │ Fire Control System (FCS)      │  │
│  │ (Explosive Tile Array) │  │ (Laser Range, Lead Angle)      │  │
│  └────────────────────────┘  └────────────────────────────────┘  │
│  ┌────────────────────────┐  ┌────────────────────────────────┐  │
│  │ Procedural Topology    │  │ Headless Test Suite Runner     │  │
│  │ (SurfaceTool Builder)  │  │ (6 Automated Validation Suites)│  │
│  └────────────────────────┘  └────────────────────────────────┘  │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ Low-Level Physics Driver
┌─────────────────────────────────▼────────────────────────────────┐
│                    Jolt 3D Physics Engine Core                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📐 Ballistics & Armor Mechanics

### 1. Effective Armor Thickness & Ricochet
Effective thickness ($T_{\text{eff}}$) is calculated using the projectile impact angle ($\theta$) relative to the plate surface normal:

$$T_{\text{eff}} = \frac{T_{\text{nominal}}}{\cos(\theta)}$$

When $\theta > \theta_{\text{critical}}$ (typically $70^\circ$ for APFSDS), guaranteed ricochet occurs regardless of projectile kinetic energy.

### 2. Spall Fragment Dispersion
Upon armor perforation, residual projectile energy ($E_{\text{res}}$) spawns a localized fragmentation cone:

$$N_{\text{fragments}} = k \cdot \sqrt{E_{\text{res}}}, \quad \alpha_{\text{dispersion}} = \arctan\left(\frac{T_{\text{nominal}}}{v_{\text{residual}}}\right)$$

---

## 🛠 Tech Stack

| Domain | Technology | Description |
|---|---|---|
| **Game Engine** | Godot Engine 4.7+ | Modern scene-tree architecture, Vulkan/Forward+ rendering |
| **Scripting** | GDScript 2.0 | Static typing, inner class data structures, `@export_range` |
| **Physics Driver** | Jolt Physics 3D | High-precision multi-threaded rigid body and constraint simulation |
| **Procedural Meshes** | `SurfaceTool`, `ArrayMesh` | Real-time vertex buffer generation and normal/tangent calculation |
| **Shaders** | Godot Shading Language (GLSL) | Thermal sight post-processing and metallic armor surface shaders |

---

## 🚀 Quick Start

### Prerequisites
- **Godot Engine**: `v4.7.1-stable` or higher with Jolt Physics enabled.

### 1. Clone the Repository
```bash
git clone https://github.com/T58574/Composite.git
cd Composite
```

### 2. Run the Game
Open the project in Godot 4 or execute directly via the included batch launcher:
```cmd
RUN_GAME.bat
```

### 3. Run Automated Validation Test Suite (Headless)
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/tests/run_tests.ps1
```

---

## 📁 Project Structure

```
Composite/
├── scenes/                  # Godot .tscn Scene Definitions
│   ├── tank_base.tscn       # Master tank entity & suspension
│   ├── mesh_editor.tscn     # 3D procedural vertex drag workspace
│   └── test_range.tscn      # Ballistics firing range & target plates
├── scripts/                 # GDScript Architecture
│   ├── ballistics/          # Trajectory math, armor penetration formulas
│   ├── combat/              # ERA tiles, spall fragment dispersion, ammo racks
│   ├── fcs/                 # Laser rangefinder, ballistic drop compensation
│   ├── physics/             # Raycast suspension & track animations
│   ├── procedural/          # SurfaceTool procedural hull/turret mesh generator
│   └── tests/               # 6 Automated headless test suites
├── assets/                  # Shaders, textures, and UI icons
├── project.godot            # Godot project manifest & Jolt 3D physics settings
└── LICENSE                  # MIT License
```

---

## 📜 License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for details.
