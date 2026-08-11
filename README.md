# Composite — Modern Armored Vehicle Simulator

**Composite** — современный симулятор-песочница бронетехники в стиле *Sprocket*, посвящённый конструированию и испытаниям основных боевых танков (ОБТ), БМП и БТР периода с 1950 по 2026 год.

---

## 🚀 Как запустить игру

1. **Запуск игры (1 клик)**: Двойной клик по **`RUN_GAME.bat`** в корневой папке проекта.
2. **Открытие в редакторе Godot 4.7.1**: Двойной клик по **`OPEN_EDITOR.bat`**.

---

## 🛠️ Текущий статус разработки: MVP Этап 2 (3D Редактор Танков Сдан)

Проект находится на этапе активной реализации ключевых систем редактора и физического полигона.

### ✅ Что уже реализовано:

1. **3D-Редактор Танков (Sprocket-Style Editor)**:
   * **[tank_editor.tscn](file:///C:/Users/user/Documents/gamedev/Composite/scenes/tank_editor/tank_editor.tscn)** — Сцена редактора с полным пользовательским интерфейсом.
   * **Орбитальная & WASD камера ([editor_camera.gd](file:///C:/Users/user/Documents/gamedev/Composite/scripts/editor/editor_camera.gd))**: Захват мыши (ПКМ/СКМ), зум колесом, полёты на WASD+QE, фокусировка по клавише `F`.
   * **Режимы отображения вьюпорта**:
     * `[Solid]` — PBR-текстурирование с процедурным трипланарным наложением (сталь, износ граней).
     * `[Armor Heatmap]` — Градиентная карта бронирования (Синий <40мм, Зеленый 100мм, Красный >350мм, Фиолетовый Композит NERA).
     * `[X-Ray]` — Голографический прозрачный корпус для инспекции внутренних модулей.
   * **Инспекция брони в реальном времени**: Вывод приведенной толщины RHA по нормали при наведении курсора.

2. **Процедурные генераторы мешей**:
   * **Корпус ([hull_builder.gd](file:///C:/Users/user/Documents/gamedev/Composite/scripts/procedural/hull_builder.gd))**: Генерация формы корпуса, вычисление объема $V$, массы $M$ и коллизий Jolt.
   * **Башня и Орудие ([turret_builder.gd](file:///C:/Users/user/Documents/gamedev/Composite/scripts/procedural/turret_builder.gd))**: Генерация скосов лобовой брони, маски орудия, наведение по азимуту (Yaw) и углу возвышения (Pitch).
   * **Ходовая и Гусеницы ([track_generator.gd](file:///C:/Users/user/Documents/gamedev/Composite/scripts/procedural/track_generator.gd))**: Генерация катков, звездочек и гусеничной ленты.

3. **Физика, Баллистика и СУО**:
   * **[raycast_suspension.gd](file:///C:/Users/user/Documents/gamedev/Composite/scripts/physics/raycast_suspension.gd)** — Кастомная Raycast-подвеска над Godot-Jolt Physics с бортовым поворотом (Skid Steering).
   * **[armor_calculator.gd](file:///C:/Users/user/Documents/gamedev/Composite/scripts/ballistics/armor_calculator.gd)** — Расчёт приведенной брони по нормали $T_{eff} = T / \cos(\theta)$, RHA-коэффициенты и ДЗ (Контакт-5 / Реликт).
   * **[thermal_fcs.gd](file:///C:/Users/user/Documents/gamedev/Composite/scripts/fcs/thermal_fcs.gd)** — СУО с оптикой (День, FLIR White/Black Hot, ПНВ) и лазерным дальномером.

4. **Интерфейс и Главное меню**:
   * **[main_menu.tscn](file:///C:/Users/user/Documents/gamedev/Composite/scenes/main_menu/main_menu.tscn)** — Стартовое меню с выбором режимов, окном настроек (экран, MSAA, звук) и выходом.

---

## 💻 Технологический стек

* **Движок**: Godot Engine 4.7.1 (Forward+ Renderer)
* **Язык**: GDScript 2
* **Физический движок**: Godot-Jolt 3D Physics
* **Интеграция ИИ**: Godot MCP Server (`@coding-solo/godot-mcp` + TCP `127.0.0.1:7080` Editor Bridge)
