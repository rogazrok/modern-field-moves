# Релизный отчёт Modern Field Moves v1.0.0

## Что изменено

Gold: включён в manifest; используется общий Gen 2 adapter. Контекстный puzzle
FLASH и callback стены Aerodactyl ограничены Crystal. Проверены семь HM,
MAP/Map Card, LIGHT, все настройки и отдельный набор тестов под GameVersion=gold.

Silver: те же изменения через общий код, отдельный прогон GameVersion=silver.
Отдельных silver.lua/gold.lua и новых HM-механик нет.

Общий код: gen2.lua (полевые действия, требования, сообщения, подтверждения),
town_map.lua (MAP и Fly), lighting.lua (палитра/освещение), field_user.lua
(настройки). Внутренние функции карты переименованы в hasGen2Map/maps.gen2.
Публичное имя, внутренний ID, defaults и ключи настроек сохранены.

Поведение RBY не изменено. Crystal сохраняет отдельную механику загадки Flash.

## Проверенные различия по исходникам

- Gen1recomp FieldMoves.bindEngineFlags читает engineFlagOrder выбранной игры:
  Crystal сдвигает блоки значков/посещений относительно Gold/Silver. Мод использует
  штатные проверки по именам; собственные адреса RAM и таблицы числовых флагов
  не добавлены. Проверены numeric-only состояния посещения и отсутствие ложной Map Card.
- Map Card от Guide Gent устанавливает ENGINE_MAP_CARD; World.engineFlagId
  разрешает имя по таблице данных. Номер события Crystal не подставляется в G/S.
- Pokégear берёт индексы landmarks из данных версии; наличие Battle Tower в
  Crystal сдвигает индексы относительно G/S. Мод не хранит собственный список
  координат/городов; ограничения карты и Fly обслуживает движок.
- В исходниках G/S Flash проверяет Zephyr и DARKNESS_PALSET. Вызова специальной
  стены Aerodactyl там нет. Общий World gen1recomp предоставляет этот callback
  независимо от версии; адаптер удаляет его из копии контекста только для G/S
  перед проверкой Flash, включая путь из меню покемона и UNRESTRICTED.
- AUTO использует чистую проверку Palettes.isDarkness и штатное состояние света;
  ни одна версия не запускает сюжетный callback через AUTO.
- Исправление Surf перед NPC относится к Crystal. GameVersion.fixes().surfOntoNpc
  остаётся под управлением движка: сторонние gameplay-исправления в G/S не внесены.

Исходники движка: commit e2114f7c85795d52903ea98deab493a4f181bace.

- [FieldMoves: флаги, HM, различие Surf](https://github.com/bryanthaboi/gen1recomp/blob/e2114f7c85795d52903ea98deab493a4f181bace/src/world/gen2/FieldMoves.lua)
- [World: fieldContext, engineFlagId](https://github.com/bryanthaboi/gen1recomp/blob/e2114f7c85795d52903ea98deab493a4f181bace/src/world/gen2/World.lua)
- [Pokégear: индексы и регионы](https://github.com/bryanthaboi/gen1recomp/blob/e2114f7c85795d52903ea98deab493a4f181bace/src/ui/gen2/Pokegear.lua)
- [G/S: FlashFunction](https://github.com/pret/pokegold/blob/master/engine/events/overworld.asm)
- [G/S: выдача Map Card](https://github.com/pret/pokegold/blob/master/maps/CherrygroveCity.asm)
- [G/S: комната Aerodactyl](https://github.com/pret/pokegold/blob/master/maps/RuinsOfAlphAerodactylChamber.asm)
- [G/S: engine flags](https://github.com/pret/pokegold/blob/master/constants/engine_flags.asm)
- [Crystal: engine flags](https://github.com/pret/pokecrystal/blob/master/constants/engine_flags.asm)

## Автоматическая проверка

| Игра | Успешных проверок |
| --- | ---: |
| Red | 528 |
| Blue | 528 |
| Yellow | 541 |
| Gold | 956 |
| Silver | 956 |
| Crystal | 944 |
| Всего | 4453 |

LuaJIT 2.1, настоящий код движка и sandbox мода; синтетические данные/save,
заглушки графики и отдельных анимационных эффектов. Проверены три режима
требований, три исполнителя, ON/OFF, реальные текстовые сообщения, длины
GENERIC-строк, штатные менеджер настроек, карты и подтверждения, HM в PC,
различия версий, старые настройки, новые defaults, повторная загрузка значений,
числовые engine flags, отсутствие записи посторонних флагов, QoL 1.3.0.
Отдельно проверено отсутствие Crystal callback в G/S при всех режимах требований.

## Ручная проверка и готовность

Полный игровой runtime-прогон с ROM Gold/Silver НЕ выполнялся. Не проверены
визуально реальные графические данные, анимации и все переходы карт в этих ROM.
MANUAL_CHECKLIST_RU.md содержит отдельные колонки Gold и Silver и регрессионные
пункты для RBY/Crystal. Все ручные пункты пока не отмечены.

Функциональный scope реализован, manifest и комплект выпуска имеют версию 1.0.0,
автоматические проверки прошли. По фактическому состоянию это готовая сборка
для ручной приёмки 1.0.0, но не доказанно завершённый полноценный игровой QA.
Для заявления о полностью проверенном стабильном релизе нужен ручной прогон.
Известных ошибок по выполненным тестам нет; внутренние API новых сборок движка
и несовместимые моды могут потребовать адаптации.
