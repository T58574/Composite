# 🎨 Гайд по ассетам — Composite

Этот документ — шпаргалка по поиску, скачиванию и импорту 3D-моделей, текстур и звуков в проект.

---

## 📂 Структура папок ассетов

```
assets/
├── materials/          ← Готовые текстуры (уже в проекте)
├── shaders/            ← Шейдеры (уже в проекте)
├── models/
│   ├── vehicles/       ← Танки, БТР, самоходки, корпуса
│   ├── weapons/        ← Орудия, пулемёты, стволы
│   ├── props/          ← Бочки, ящики, заграждения, инструменты
│   └── environment/    ← Деревья, здания, рельеф, скалы
├── textures/
│   ├── metal/          ← PBR металлы: сталь, алюминий, ржавчина
│   ├── ground/         ← Земля, грязь, песок, трава
│   ├── concrete/       ← Бетон, асфальт, кирпич
│   └── camo/           ← Камуфляжные паттерны
└── audio/
    ├── engines/        ← Звуки двигателей (дизель, газотурбинный)
    ├── weapons/        ← Выстрелы, перезарядка, затвор
    ├── tracks/         ← Лязг гусениц, скрип
    ├── impacts/        ← Попадания, рикошеты, взрывы
    └── ui/             ← Клики, уведомления, переходы
```

> **Правило именования файлов:**
> - Всё в нижнем регистре, через подчёркивание
> - Формат: `тип_описание_вариант.расширение`
> - Примеры: `t72_turret_lowpoly.glb`, `steel_brushed_albedo.png`, `cannon_fire_01.ogg`

---

## 🔩 1. Текстуры металла и брони

Это самое важное для проекта — реалистичные PBR-текстуры стали, брони, ржавчины.

### Где искать

| Сайт | Прямая ссылка | Лицензия |
|------|---------------|----------|
| **ambientCG** | [Металлы](https://ambientcg.com/list?type=material&q=metal) | CC0 (свободно) |
| **ambientCG** | [Сталь](https://ambientcg.com/list?type=material&q=steel) | CC0 |
| **ambientCG** | [Ржавчина](https://ambientcg.com/list?type=material&q=rust) | CC0 |
| **Poly Haven** | [Металлы](https://polyhaven.com/textures?s=metal) | CC0 |
| **Poly Haven** | [Поцарапанная краска](https://polyhaven.com/textures?s=painted+metal) | CC0 |
| **3D Textures** | [Металлы](https://3dtextures.me/tag/metal/) | CC0 |
| **cgbookcase** | [Металлы](https://www.cgbookcase.com/textures?search=metal) | CC0 |

### Что скачивать

Для каждого материала скачивай набор PBR-карт (обычно ZIP-архив):

| Файл в архиве | Что это | Куда в Godot |
|----------------|---------|--------------|
| `*_Color.png` / `*_Albedo.png` | Базовый цвет | Material → Albedo → Texture |
| `*_NormalGL.png` | Карта нормалей (OpenGL) | Material → Normal Map → Texture |
| `*_Roughness.png` | Шероховатость | Material → Roughness → Texture |
| `*_Metalness.png` | Металличность | Material → Metallic → Texture |
| `*_AmbientOcclusion.png` | Затенение складок | Material → AO → Texture |
| `*_Displacement.png` | Карта высот (опционально) | Material → Height → Texture |

> **⚠ Важно:** На ambientCG выбирай разрешение **2K** (2048×2048) — это оптимальный баланс качества и производительности. 4K и выше нужны только для крупных планов.

### Пошаговый импорт текстуры металла

1. Зайди на [ambientCG → Metal](https://ambientcg.com/list?type=material&q=metal)
2. Выбери текстуру, например **"Metal034"** (матовая сталь)
3. Нажми **Download** → выбери **2K-PNG**
4. Распакуй архив в `assets/textures/metal/`
5. В Godot выбери нужный `MeshInstance3D`
6. В инспекторе: **Surface Material Override → New StandardMaterial3D**
7. Открой материал и назначь текстуры по таблице выше
8. Готово! 🎉

### Рекомендуемые текстуры для танковой тематики

- **Metal034** (ambientCG) — чистая матовая сталь, идеально для базовой брони
- **Metal032** (ambientCG) — грубый прокат, для нижней бронеплиты
- **PaintedMetal** (Poly Haven) — окрашенный металл, для корпуса
- **Rust** (ambientCG) — ржавчина, для повреждённых участков
- **Metal012** (ambientCG) — алюминий, для лёгкой техники

---

## 🚀 2. 3D-модели танковых компонентов

### Где искать

| Сайт | Прямая ссылка | Советы |
|------|---------------|--------|
| **Sketchfab** | [Танки (бесплатные, скачиваемые)](https://sketchfab.com/search?type=models&q=tank&downloadable=true&sort_by=-likeCount) | Фильтр "Downloadable", сортировка по лайкам |
| **Sketchfab** | [Танковые башни](https://sketchfab.com/search?type=models&q=tank+turret&downloadable=true) | Отдельные компоненты |
| **Sketchfab** | [Гусеницы](https://sketchfab.com/search?type=models&q=tank+tracks&downloadable=true) | Траки и катки |
| **Sketchfab** | [Танковые орудия](https://sketchfab.com/search?type=models&q=tank+cannon&downloadable=true) | Стволы, казённики |
| **Turbosquid** | [Бесплатные танки](https://www.turbosquid.com/Search/3D-Models/free/tank) | Проверяй лицензию! |
| **CGTrader** | [Бесплатные военные](https://www.cgtrader.com/free-3d-models/military) | Фильтр "Free" |
| **Quaternius** | [Военная техника](https://quaternius.com) | Low-poly стилизация, CC0 |
| **Kenney** | [Все наборы](https://kenney.nl/assets) | CC0, отличное качество |

### Какой формат скачивать

| Формат | Приоритет | Комментарий |
|--------|-----------|-------------|
| `.glb` | ⭐⭐⭐ Лучший | Бинарный glTF, всё в одном файле, Godot импортирует идеально |
| `.gltf` | ⭐⭐⭐ Отличный | Текстовый glTF + отдельные файлы текстур |
| `.fbx` | ⭐⭐ Хороший | Широко поддерживается, но может потребовать донастройки |
| `.obj` | ⭐ Базовый | Только меш, без анимаций и скелетов |
| `.blend` | ⭐⭐ Хороший | Нужен установленный Blender для импорта в Godot |

> **Совет:** На Sketchfab при скачивании выбирай **"glTF"** — это всегда даёт `.glb` файл.

### Пошаговый импорт 3D-модели

1. Зайди на [Sketchfab](https://sketchfab.com/search?type=models&q=tank&downloadable=true)
2. Найди модель, нажми **Download 3D Model**
3. Выбери формат **glTF** → скачается `.glb` файл
4. Скопируй файл в соответствующую папку:
   - Танк целиком → `assets/models/vehicles/`
   - Башня → `assets/models/weapons/` или `assets/models/vehicles/`
   - Бочка/ящик → `assets/models/props/`
5. В Godot модель появится в FileSystem автоматически
6. **Перетащи** её на 3D-сцену — Godot создаст ноду автоматически
7. При необходимости настрой масштаб в **Import Settings** (двойной клик на файле в FileSystem)

### Настройка импорта в Godot

После импорта модели, двойной клик на файле в FileSystem → вкладка **Import**:

- **Scale**: если модель огромная/крошечная — поменяй множитель (часто нужно `0.01` для моделей в сантиметрах)
- **Generate Tangents**: ✅ включи (нужно для нормал-маппинга)
- **Generate Lightmap UV**: ✅ включи, если планируешь запекать освещение
- Нажми **Reimport** после изменений

---

## 🌍 3. Текстуры грунта и ландшафта

### Где искать

| Сайт | Прямая ссылка | Что есть |
|------|---------------|----------|
| **Poly Haven** | [Земля](https://polyhaven.com/textures?s=ground) | Земля, грязь, камни |
| **Poly Haven** | [Трава](https://polyhaven.com/textures?s=grass) | Разные виды травы |
| **Poly Haven** | [Песок](https://polyhaven.com/textures?s=sand) | Пустынные текстуры |
| **Poly Haven** | [Дороги](https://polyhaven.com/textures?s=road) | Асфальт, гравий |
| **ambientCG** | [Земля](https://ambientcg.com/list?type=material&q=ground) | Грунты |
| **ambientCG** | [Грязь](https://ambientcg.com/list?type=material&q=mud) | Влажная/сухая грязь |
| **ambientCG** | [Песок](https://ambientcg.com/list?type=material&q=sand) | Пустыня |
| **ambientCG** | [Камни](https://ambientcg.com/list?type=material&q=rock) | Скалы, булыжники |
| **3D Textures** | [Грунт](https://3dtextures.me/tag/ground/) | Земля |
| **3D Textures** | [Трава](https://3dtextures.me/tag/grass/) | Трава |

### Рекомендации для военных сцен

| Тип сцены | Какие текстуры нужны |
|-----------|---------------------|
| **Полигон/стрельбище** | Земля, песок, бетон, мишени |
| **Восточная Европа** | Грязь, трава, лесная земля, гравий |
| **Пустыня** | Песок, сухая земля, камни |
| **Городские бои** | Асфальт, бетон, кирпич, щебень |

### Импорт текстур грунта

Процесс такой же, как для металла (раздел 1), но складывай в `assets/textures/ground/`.

Для террейна в Godot 4 текстуры назначаются через **Terrain3D** (плагин) или через `ShaderMaterial` на `MeshInstance3D` с плоскостью.

---

## 🔊 4. Звуки

### Где искать

| Сайт | Прямая ссылка | Лицензия |
|------|---------------|----------|
| **Freesound** | [Выстрелы танка](https://freesound.org/search/?q=tank+cannon+shot) | CC0 / CC-BY (проверяй!) |
| **Freesound** | [Двигатель танка](https://freesound.org/search/?q=tank+engine) | Разная |
| **Freesound** | [Гусеницы](https://freesound.org/search/?q=tank+tracks+treads) | Разная |
| **Freesound** | [Взрывы](https://freesound.org/search/?q=explosion+military) | Разная |
| **Freesound** | [Рикошеты](https://freesound.org/search/?q=ricochet+metal) | Разная |
| **Freesound** | [Попадание по металлу](https://freesound.org/search/?q=metal+impact) | Разная |
| **Freesound** | [UI звуки](https://freesound.org/search/?q=ui+click+menu) | Разная |
| **Pixabay Audio** | [Военные](https://pixabay.com/sound-effects/search/military/) | Бесплатно для коммерции |
| **Mixkit** | [Звуковые эффекты](https://mixkit.co/free-sound-effects/) | Бесплатно |
| **OpenGameArt** | [Звуки](https://opengameart.org/art-search-advanced?keys=tank&type=sounds) | Разная (CC0/CC-BY) |

### Какой формат скачивать

| Формат | Приоритет | Комментарий |
|--------|-----------|-------------|
| `.ogg` (Vorbis) | ⭐⭐⭐ Лучший | Godot рекомендует для SFX, лёгкий, качественный |
| `.wav` | ⭐⭐ Хороший | Без сжатия, большой размер, конвертируй в .ogg |
| `.mp3` | ⭐ Допустимый | Godot поддерживает, но .ogg предпочтительнее |

> **Конвертация WAV → OGG:** Используй [Audacity](https://www.audacityteam.org/) (бесплатно) или [онлайн-конвертер](https://convertio.co/wav-ogg/)

### Пошаговый импорт звука

1. Скачай звук с Freesound (нужна регистрация)
2. Если формат `.wav` — конвертируй в `.ogg` через Audacity:
   - Файл → Импорт → Аудио
   - Файл → Экспорт → Экспорт как OGG
3. Скопируй `.ogg` файл в нужную папку:
   - Выстрел → `assets/audio/weapons/cannon_fire_01.ogg`
   - Двигатель → `assets/audio/engines/diesel_idle_loop.ogg`
   - Гусеницы → `assets/audio/tracks/track_clank_01.ogg`
4. В Godot файл появится автоматически
5. Создай ноду `AudioStreamPlayer3D` (для 3D-звука) или `AudioStreamPlayer` (для UI)
6. Назначь `.ogg` файл в свойство **Stream**

### Рекомендуемые звуки для проекта

| Категория | Что искать на Freesound | Папка |
|-----------|------------------------|-------|
| Выстрел пушки | `tank cannon fire`, `artillery shot` | `audio/weapons/` |
| Пулемёт | `machine gun burst` | `audio/weapons/` |
| Перезарядка | `cannon reload`, `shell loading` | `audio/weapons/` |
| Дизель на холостых | `diesel engine idle loop` | `audio/engines/` |
| Дизель разгон | `diesel engine acceleration` | `audio/engines/` |
| Гусеницы | `tank tracks moving`, `metal tracks` | `audio/tracks/` |
| Попадание | `bullet metal impact`, `armor hit` | `audio/impacts/` |
| Рикошет | `ricochet ping`, `bullet bounce` | `audio/impacts/` |
| Взрыв | `explosion close`, `tank explosion` | `audio/impacts/` |
| UI клик | `button click`, `menu select` | `audio/ui/` |

---

## ⚡ Быстрый чеклист

Когда скачиваешь ассет, пройди по этому списку:

- [ ] **Лицензия** — CC0 или CC-BY? Если CC-BY — запиши автора
- [ ] **Формат** — `.glb` для моделей, PNG для текстур, `.ogg` для звуков
- [ ] **Разрешение** — 2K для текстур (не больше 4K)
- [ ] **Именование** — нижний регистр, подчёркивания, без пробелов и кириллицы
- [ ] **Папка** — положил в правильную подпапку `assets/`
- [ ] **Reimport** — если модель кривая по масштабу, настрой Import и нажми Reimport

---

## 📜 Лицензии — краткая справка

| Лицензия | Можно в игру? | Нужно указывать автора? |
|----------|---------------|------------------------|
| **CC0** | ✅ Да | ❌ Нет (но приятно) |
| **CC-BY** | ✅ Да | ✅ Да, в credits |
| **CC-BY-SA** | ✅ Да | ✅ Да + производные тоже CC-BY-SA |
| **CC-BY-NC** | ⚠ Только некоммерческие | ✅ Да |
| **Editorial / Personal** | ❌ Нет | — |

> Если планируешь продавать игру — используй **только CC0 и CC-BY** ассеты.

---

*Последнее обновление: Август 2026*
