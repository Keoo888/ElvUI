<!-- ───────────────────────────────────────────────────────────────────────────
     LOGO / BANNER SLOT.  Paste the URL into src="" and delete the two
     comment markers (the line above and the line below).
<p align="center">
  <img width="520" alt="ElvUI — Keoo build" src="">
</p>
──────────────────────────────────────────────────────────────────────────── -->

<p align="center">
  <img src="https://img.shields.io/badge/ElvUI-6.09-1784d1?style=for-the-badge&logo=appveyor" alt="ElvUI 6.09">
  <img src="https://img.shields.io/badge/WotLK-3.3.5a-5ab1d8?style=for-the-badge&logo=appveyor" alt="WotLK 3.3.5a">
  <img src="https://img.shields.io/badge/status-stable-brightgreen?style=for-the-badge&logo=appveyor" alt="stable">
</p>

<h1 align="center">ElvUI 6.09 — Keoo build</h1>

<p align="center">
  <b>The same ElvUI you already use, with the 3.3.5a defects taken out of it.</b><br>
  <i>No new features. No changed defaults. Just fewer broken things and less work per frame.</i>
</p>

<p align="center">
  <a href="#english">English</a> · <a href="#русский">Русский</a>
</p>

---

## English

<a href="#about">About</a> · <a href="#whats-different">What's different</a> · <a href="#screenshots">Screenshots</a> · <a href="#installation">Installation</a> · <a href="#commands">Commands</a> · <a href="#how-this-build-is-made">How this build is made</a> · <a href="#compatibility">Compatibility</a> · <a href="#credits">Credits</a>

### About

**This is not a backport.** ElvUI 6.09 already runs on WoW 3.3.5a — that work was done by the
[ElvUI-WotLK](https://github.com/ElvUI-WotLK/ElvUI) team, and this build starts from their code,
not from retail.

What this fork is: the same 6.09, **audited line by line against the 3.3.5a client**, with three
kinds of thing fixed.

1. **Places that still spoke retail.** Calls to functions the 3.3.5a client does not have, and
   handlers waiting for events it never sends. Each one failed quietly — an indicator that never
   lit, a panel that would not open, a counter that only ever went up.
2. **Work the client paid for and threw away.** Values written to the same bar sixty times a second
   when nothing had changed; events woken on every frame for units a frame does not even show;
   tables rebuilt per update instead of reused.
3. **Four real bugs in the original**, which are bugs on retail too.

What this fork is **not**: it adds no feature, no option, no slash command, and changes no default.
Your profile, your layout, your every setting stay exactly where they were. If you cannot tell this
build from stock ElvUI by looking at it, that is the point — the difference is in what no longer
breaks and what the client no longer does twice.

Against the upstream base (`ElvUI-WotLK/ElvUI` master, commit `58ea24f7` = tag 6.09 plus ten
upstream commits) **49 files differ**: 48 in `ElvUI` and 1 in `ElvUI_OptionsUI`'s bundled Ace3 —
`+1439 / −438` lines, measured 2026-10-13.

### What's different

#### Broken on 3.3.5a, now fixed (12 sites)

- **A raid member who went offline kept showing as online.** The greyed-out name, the dimmed
  health bar and the portrait all hung on an event that does not exist on this client; they now
  follow the roster instead.
- **A shared or imported profile could not be renamed or accepted** once the name was taken — the
  dialog box died the moment it appeared.
- **Nameplate debuff stacks only ever went up.** The handler that takes a stack away was listening
  under a name the client never uses, so the counter grew and stayed.
- **One missing frame aborted the rest of a skin pass.** A frame that does not exist on 3.3.5a
  threw an error, and every frame after it in that pass was left unskinned.
- **The experience bar threw an error at login** when the quest-XP overlay drew before the bar had
  its first values.
- **Multi-line text fields in the options did not draw at all.** Eight fields: every *Visibility
  State* box (the action bars and the bag bar), *Action Paging*, and the *Search Syntax* help in
  Bags. Opening one gave an error instead of a panel.

#### Real bugs of the original (3)

- **A pushed-back channel showed the wrong delay** — the maximum cast time was printed where the
  delay belongs.
- **Faders could stick at the wrong transparency.** A 0.33 s fade was re-armed every 0.2 s by the
  range check and so never finished.
- **A plugin author using a reserved section name** got "bad argument to 'format'" instead of the
  message explaining what was wrong.

#### Less work per frame (119 sites)

No FPS number is promised here, and none should be believed from a README. What changed is
measurable rather than felt: work that produced a result identical to the one already on screen
was removed.

- **Nothing is written twice.** Health and power bars, aura icons and their cooldowns, stack text,
  nameplate glow, data texts — each now compares before it writes, and skips the call when the
  value has not moved. Every place that legitimately repaints (an option change, a template sweep)
  clears the cache, so a setting you change still takes effect at once.
- **Unit events are filtered at the door.** 3.3.5a has no `RegisterUnitEvent`, so every frame woke
  for every unit's event and then checked. A frame now drops an event for a unit that is not its
  own before anything else happens.
- **Nameplates look things up instead of searching.** Finding a plate by GUID was a walk over an
  ever-growing table; it is now two hash reads.
- **Action-bar buttons update only the slot that changed.** `ACTIONBAR_SLOT_CHANGED` was measured
  firing 1416 times in 47 seconds, and each fire swept every button.
- **Aura lists reuse their tables** instead of allocating a new set per update — the garbage
  collector on this client is single-threaded and stops the frame when it runs.
- **Nameplate glow stopped hiding things that were already hidden** sixty times a second, per plate.
- **The aura filter reads your settings once per update, not once per aura.** Working out which
  auras you want shown used to re-read the filter lists and re-parse their priorities for every
  single aura; measured in a raid at 2317 times a second, now 127.
- **Nothing is computed twice.** Frame labels were worked out twice on every event, the action bars
  asked the client who owns the tooltip once per button instead of once per update, and the stance
  bar rebuilt its button names and looked each one up by name on every refresh.
- **Expiring auras cost one clock read, not one per aura.** The aura library re-walked the same
  four-level table path and re-asked the time for every aura in the sweep.
- **A switched-off indicator costs nothing now.** Turning the buff indicator off only hid it — the
  full buff-and-debuff scan behind it kept running on every aura change of that unit.
- **Foreign combat-log lines are dropped first.** The DPS, HPS and coordinate texts used to redraw
  on other people's combat events.

ElvUI's own `/cpuimpact` is the honest way to see the difference on your client, in your raid.

#### Also included, from upstream (credit to the ElvUI-WotLK team)

This build sits on upstream master, so it carries the ten commits made after the 6.09 tag. They are
not my work, but you will notice them:

- the **mover rewrite** — sticky frames, default positions per layout, the nudge window moves a
  frame with the numpad (hold Alt or Ctrl for ten pixels at a time), other frames dim while you
  drag one;
- smoother world-map, threat and tradeskill fades;
- a corrected chat tab font-size key, a microbar default fix, and the quest-XP update flow.

Two honest notes about those: the Healer layout no longer forces frequent health updates on party
and raid frames, and a profile that already carried the old misspelled chat font-size key keeps it
as dead weight while the correct one starts from its default of 12.

### Screenshots

*Screenshots are being prepared — the slots below are ready for them.*

<!-- Each bullet has a commented <img> under it. Paste the URL into src="" and
     delete that bullet's two comment markers; the bullet text becomes the caption. -->

- **The whole UI in a raid** — unit frames, nameplates, action bars, data texts together.
<!--
<img width="900" alt="Full UI in a raid" src="">
-->

- **Unit frames** — player, target, party and the 40-man raid layout.
<!--
<img width="900" alt="Unit frames" src="">
-->

- **Nameplates** — auras, glow, cast bars and style filters.
<!--
<img width="900" alt="Nameplates" src="">
-->

- **Action bars and bags.**
<!--
<img width="900" alt="Action bars and bags" src="">
-->

- **The options window** (`/ec`) — unchanged from stock ElvUI.
<!--
<img width="900" alt="Options window" src="">
-->

- **Move mode** (`/moveui`) — the grid, the nudge window and the per-layout positions.
<!--
<img width="900" alt="Move mode" src="">
-->

### Installation

1. Close the game completely.
2. Download the archive and unpack it.
3. Copy **both** folders — `ElvUI` and `ElvUI_OptionsUI` — into:

```
World of Warcraft\Interface\AddOns\
```

4. Start the game, make sure both are ticked in the AddOns list, and log in. On a fresh profile the
   install wizard runs by itself; type `/ec` to open the options at any time.

If you are replacing another ElvUI build, delete its `ElvUI` and `ElvUI_OptionsUI` folders first
rather than copying over them — a leftover file from a different version is loaded by the `.toc`
just like a current one. Your settings live in `WTF\`, not in the addon folder, and are not touched
by this.

### Commands

| Command | What it does |
| --- | --- |
| `/ec`, `/elvui` | open the options window |
| `/moveui` | move mode — drag frames, numpad to nudge, Alt or Ctrl for ten pixels |
| `/egrid` | the alignment grid on its own |
| `/resetui` | run the install wizard again |
| `/estatus` | a status report you can paste when asking for help |
| `/cpuimpact` | ElvUI's own CPU meter — type it once to start, again to read the result |
| `/kb` | key-binding mode for the action bars |
| `/farmmode` | the farm-mode minimap |
| `/bgstats` | battleground stats in the data text |
| `/luaerror on` \| `off` | turn Lua errors on — **this disables every other addon and reloads**; `off` puts them back |

### How this build is made

Patching by eye is how a 3.3.5a port acquires the defects this one removes: the client reports
almost none of them. A call to a function that does not exist raises an error only when the code
actually reaches that line, and a value written where nothing changed raises nothing at all, ever.
So the work here is an audit with tools rather than a reading.

- **Every edit is marked in the code.** 134 sites carry a `--!` comment saying what was changed and
  why it has to be that way on this client — 119 cost sites, 12 compatibility fixes, 3 bug fixes
  (measured 2026-10-13). Nothing is silently different from upstream.
- **Every finding is in a registry**, with where it is, what the player sees, why it happens, what
  was done and the proof. 83 records as of 2026-10-13: 65 fixed in this tree, 7 of those already confirmed by
  an instrumented in-game run, 6 waiting on a decision because the fix would change something you
  see, 10 still open (five of which are defects of the audit tooling, not of the addon), 1 that
  turned out to be a false alarm of the instrument, and 1 deliberately declined.
- **18 static gates run on every edit.** All 357 Lua files are compiled by the real Lua 5.1, every
  method call is checked for existing anywhere on 3.3.5a at all, every `format()` is checked for
  having as many arguments as it has `%` places, every global read is checked against the client's
  own API list, and each tool must print a phrase it can only reach by finishing its work — a
  checker that died on its first file and exited quietly counts as broken, not as green.
- **Game runs are measured, not eyeballed.** Frame times, memory floors, event rates and per-window
  CPU are recorded in-game and read back from the artifact, so a claim about cost is a number
  somebody measured in a raid rather than an impression.

Three rules this build does not break: the 3.3.5a API is never assumed from memory (it is checked
against a database of the client's own build 12340), a native call is always preferred to a
polyfill, and nothing a player can see is removed or reworded without being asked first.

### Compatibility

- Built and tested on **Warmane**, client 3.3.5a (build 12340, Interface 30300).
- Developed exclusively for **Warmane**. I am not responsible for functionality on other servers.
- **ElvUI plugins keep working.** Nothing was renamed, moved or removed: the module layout, the
  bundled libraries and every public function are upstream's, so anything built for ElvUI 6.09
  loads here unchanged.

### Credits

- **ElvUI** — Elv, Bunny and the ElvUI team · [tukui.org](https://www.tukui.org/)
- **The 3.3.5a port this builds on** — the [ElvUI-WotLK](https://github.com/ElvUI-WotLK/ElvUI) team
- **oUF** — Haste, with the oUF plugin authors
- **This build and its audit** — **Keoo**

Made by Keoo for Warmane.
[Download](https://gitlab.com/keoo88/elvui)

---

## Русский

<a href="#о-сборке">О сборке</a> · <a href="#что-изменилось">Что изменилось</a> · <a href="#скриншоты">Скриншоты</a> · <a href="#установка">Установка</a> · <a href="#команды">Команды</a> · <a href="#как-сделана-эта-сборка">Как сделана эта сборка</a> · <a href="#совместимость">Совместимость</a> · <a href="#благодарности">Благодарности</a>

### О сборке

**Это не бэкпорт.** ElvUI 6.09 и так работает на WoW 3.3.5a — эту работу сделала команда
[ElvUI-WotLK](https://github.com/ElvUI-WotLK/ElvUI), и сборка начинается с их кода, а не с ретейла.

Что такое этот форк: тот же 6.09, **разобранный построчно против клиента 3.3.5a**, с исправлениями
трёх видов.

1. **Места, которые всё ещё говорили на ретейле.** Вызовы функций, которых у клиента 3.3.5a нет, и
   обработчики, ждущие событий, которые он никогда не присылает. Каждое такое место отказывало
   молча — индикатор не загорался, панель не открывалась, счётчик только рос.
2. **Работа, за которую клиент платил впустую.** Значение, записываемое в ту же полоску шестьдесят
   раз в секунду, когда ничего не изменилось; события, будящие каждый фрейм из-за юнитов, которых
   он даже не показывает; таблицы, собираемые заново на каждое обновление вместо переиспользования.
3. **Четыре настоящих бага оригинала** — они баги и на ретейле.

Чего в этом форке **нет**: ни одной новой функции, ни одной новой опции, ни одной новой команды, ни
одного изменённого значения по умолчанию. Профиль, раскладка и все настройки остаются ровно там, где
были. Если на вид эту сборку не отличить от обычного ElvUI — это и есть цель: разница в том, что
перестало ломаться и что клиент перестал делать дважды.

Относительно базы (`ElvUI-WotLK/ElvUI` master, коммит `58ea24f7` = тег 6.09 плюс десять коммитов
апстрима) **различаются 49 файлов**: 48 в `ElvUI` и 1 в вендорной копии Ace3 внутри
`ElvUI_OptionsUI` — `+1439 / −438` строк, замер 2026-10-13.

### Что изменилось

#### Не работало на 3.3.5a — исправлено (12 мест)

- **Ушедший в оффлайн участник рейда продолжал показываться онлайн.** Серое имя, притушенная полоса
  здоровья и портрет держались на событии, которого на этом клиенте нет; теперь они следуют за
  составом группы.
- **Присланный или импортированный профиль нельзя было ни переименовать, ни принять**, если имя уже
  занято — окно умирало в момент появления.
- **Стаки дебаффов на неймплейтах только росли.** Обработчик, снимающий стак, был назван именем,
  которого клиент не присылает, поэтому счётчик рос и оставался.
- **Один отсутствующий фрейм обрывал остаток прохода скинов.** Фрейма, которого на 3.3.5a нет,
  хватало на ошибку — и все фреймы после него в этом проходе оставались без оформления.
- **Полоса опыта давала ошибку при входе в игру**, когда наложение опыта за задания рисовалось
  раньше, чем полоса получала первые значения.
- **Многострочные поля ввода в настройках не рисовались вовсе.** Восемь полей: все поля «Статус
  отображения» (панели команд и панель сумок), «Переключение панелей» и справка «Синтаксис поиска»
  в сумках. Вместо панели открывалась ошибка.

#### Настоящие баги оригинала (3)

- **У отброшенного канала показывалась не та задержка** — на её месте печаталось максимальное время
  каста.
- **Затухание могло застрять не на той прозрачности.** Затухание длиной 0,33 с перезапускалось
  проверкой дистанции каждые 0,2 с и потому никогда не доходило до конца.
- **Автор плагина, занявший зарезервированное имя секции**, получал «bad argument to 'format'»
  вместо сообщения о том, что не так.

#### Меньше работы на кадр (119 мест)

Никаких обещанных FPS здесь нет, и верить таким обещаниям в README не стоит. Изменилось то, что
измеряется, а не то, что кажется: убрана работа, результат которой совпадал с уже нарисованным.

- **Ничего не записывается дважды.** Полосы здоровья и ресурса, иконки аур и их кулдауны, число
  стаков, свечение неймплейтов, тексты данных — каждое место теперь сравнивает перед записью и
  пропускает вызов, если значение не изменилось. Все пути, которые перерисовывают по делу (смена
  опции, проход шаблона), сбрасывают кэш, поэтому изменённая настройка применяется сразу.
- **События юнитов отсеиваются на входе.** `RegisterUnitEvent` на 3.3.5a нет, поэтому каждый фрейм
  просыпался на событие любого юнита и только потом проверял. Теперь событие чужого юнита
  отбрасывается раньше всего остального.
- **Неймплейты ищут по индексу, а не перебором.** Поиск плашки по GUID был проходом по вечно
  растущей таблице — стал двумя обращениями по хэшу.
- **Кнопки панелей обновляют только изменившийся слот.** Измерено: `ACTIONBAR_SLOT_CHANGED` даёт
  1416 срабатываний за 47 секунд, и каждое проходило по всем кнопкам.
- **Списки аур переиспользуют свои таблицы** вместо выделения нового набора на каждое обновление:
  сборщик мусора на этом клиенте однопоточный и останавливает кадр, когда работает.
- **Свечение неймплейтов перестало скрывать то, что уже скрыто** — шестьдесят раз в секунду на
  каждую плашку.
- **Фильтр аур читает настройки один раз на обновление, а не на каждую ауру.** Выяснение того, какие
  ауры вы хотите видеть, перечитывало списки фильтров и разбирало их приоритеты для каждой отдельной
  ауры; в рейде измерено 2317 раз в секунду, стало 127.
- **Ничего не вычисляется дважды.** Подписи рамок считались по два раза на каждое событие, панели
  команд спрашивали клиент о владельце подсказки на каждую кнопку вместо одного раза на обновление,
  а панель стоек каждый раз заново собирала имена своих кнопок и искала каждое по имени.
- **На истечение аур уходит одно чтение часов, а не по одному на ауру.** Библиотека аур на каждую
  проверяемую ауру заново шла по тому же четырёхуровневому пути в таблицах и заново спрашивала время.
- **Выключенный индикатор больше ничего не стоит.** Выключение индикатора бафов только скрывало
  его — полный обход бафов и дебаффов за ним продолжался на каждое изменение аур этого юнита.
- **Чужие строки боевого лога отбрасываются первым делом.** Тексты DPS, HPS и координат
  перерисовывались на чужих боевых событиях.

Честный способ увидеть разницу на своём клиенте и в своём рейде — родная команда ElvUI
`/cpuimpact`.

#### Что ещё вошло — работа апстрима (заслуга команды ElvUI-WotLK)

Сборка стоит на master апстрима, поэтому несёт десять коммитов, сделанных после тега 6.09. Это не
моя работа, но заметно её:

- **переработка муверов** — залипающие фреймы, позиции по умолчанию для каждой раскладки, окно
  наджинга двигает фрейм цифровой клавиатурой (Alt или Ctrl — сразу на десять пикселей), остальные
  фреймы притухают, пока тащишь один;
- более плавное затухание карты мира, индикатора угрозы и окна профессий;
- исправленный ключ размера шрифта вкладок чата, значение по умолчанию у микропанели и поток
  обновления опыта за задания.

Две честные оговорки к этому: раскладка «Лекарь» больше не включает принудительно частое обновление
здоровья для рамок группы и рейда, а профиль, в котором уже лежал старый ключ размера шрифта чата с
опечаткой, сохраняет его мёртвым грузом, пока правильный начинает со значения по умолчанию 12.

### Скриншоты

*Скриншоты готовятся — места под них ниже уже размечены.*

<!-- Под каждым пунктом закомментирован <img>. Вставьте URL в src="" и уберите
     два маркера комментария у этого пункта; текст пункта станет подписью. -->

- **Весь интерфейс в рейде** — рамки, неймплейты, панели команд и тексты данных вместе.
<!--
<img width="900" alt="Весь интерфейс в рейде" src="">
-->

- **Рамки юнитов** — игрок, цель, группа и раскладка на 40 человек.
<!--
<img width="900" alt="Рамки юнитов" src="">
-->

- **Неймплейты** — ауры, свечение, полосы каста и фильтры стиля.
<!--
<img width="900" alt="Неймплейты" src="">
-->

- **Панели команд и сумки.**
<!--
<img width="900" alt="Панели команд и сумки" src="">
-->

- **Окно настроек** (`/ec`) — не отличается от обычного ElvUI.
<!--
<img width="900" alt="Окно настроек" src="">
-->

- **Режим перемещения** (`/moveui`) — сетка, окно наджинга и позиции для раскладки.
<!--
<img width="900" alt="Режим перемещения" src="">
-->

### Установка

1. Полностью закройте игру.
2. Скачайте архив и распакуйте его.
3. Скопируйте **обе** папки — `ElvUI` и `ElvUI_OptionsUI` — в:

```
World of Warcraft\Interface\AddOns\
```

4. Запустите игру, убедитесь, что обе отмечены в списке аддонов, и войдите в мир. На чистом профиле
   мастер установки запустится сам; настройки открываются командой `/ec` в любой момент.

Если вы меняете другую сборку ElvUI — сначала удалите её папки `ElvUI` и `ElvUI_OptionsUI`, а не
копируйте поверх: оставшийся файл от другой версии загружается по `.toc` так же, как актуальный.
Настройки лежат в `WTF\`, а не в папке аддона, и при этом не затрагиваются.

### Команды

| Команда | Что делает |
| --- | --- |
| `/ec`, `/elvui` | открыть окно настроек |
| `/moveui` | режим перемещения — тащить фреймы, цифровая клавиатура для шага, Alt или Ctrl — десять пикселей |
| `/egrid` | только сетка выравнивания |
| `/resetui` | заново запустить мастер установки |
| `/estatus` | отчёт о состоянии — его удобно приложить к вопросу |
| `/cpuimpact` | родной счётчик CPU у ElvUI: первый ввод начинает замер, второй показывает результат |
| `/kb` | режим назначения горячих клавиш для панелей команд |
| `/farmmode` | режим фарма у миникарты |
| `/bgstats` | статистика боя за поле в тексте данных |
| `/luaerror on` \| `off` | включить ошибки Lua — **при этом отключаются все остальные аддоны и идёт перезагрузка**; `off` возвращает их |

### Как сделана эта сборка

Правка на глаз — это то, как порт на 3.3.5a и набирает те дефекты, которые здесь убраны: клиент
почти ни об одном не сообщает. Вызов несуществующей функции даёт ошибку только тогда, когда
управление реально дойдёт до строки, а запись значения там, где ничего не изменилось, не даёт
ошибки вообще никогда. Поэтому работа здесь — аудит инструментами, а не чтение.

- **Каждая правка помечена в коде.** 134 места несут комментарий `--!` с тем, что изменено и почему
  на этом клиенте нужно именно так: 119 мест по стоимости, 12 по совместимости, 3 исправления багов
  (замер 2026-10-13). Ничто не отличается от апстрима молча.
- **Каждая находка лежит в реестре** — где она, что видит игрок, почему так происходит, что
  сделано и доказательство. На 2026-10-13 — 83 записи: 65 исправлено в этом дереве, 7 из них уже
  подтверждены игровым прогоном с приборами, 6 ждут решения, потому что правка изменила бы то, что
  игрок видит, 10 ещё открыты (пять из них — дефекты самих инструментов аудита, а не аддона), 1
  оказалась ложной тревогой прибора и 1 отклонена сознательно.
- **На каждую правку прогоняются 18 статических гейтов.** Все 357 файлов Lua компилируются
  настоящим Lua 5.1, каждый вызов метода проверяется на то, существует ли он на 3.3.5a хоть
  где-нибудь, у каждого `format()` сверяется число аргументов с числом мест `%`, каждое чтение
  глобала сверяется со списком API самого клиента — и каждый инструмент обязан напечатать фразу,
  до которой доходит только закончив работу: проверялка, умершая на первом же файле и тихо
  вышедшая нулём, считается сломанной, а не зелёной.
- **Игровые прогоны измеряются, а не оцениваются на глаз.** Время кадра, полы памяти, частота
  событий и CPU по окнам записываются в игре и читаются из артефакта, поэтому утверждение о
  стоимости — это число, которое кто-то измерил в рейде, а не впечатление.

Три правила, которые эта сборка не нарушает: API 3.3.5a никогда не утверждается по памяти (всё
проверяется по базе собственного билда клиента 12340), нативный вызов всегда предпочтительнее
полифилла, и ничто видимое игроку не удаляется и не переименовывается без отдельного спроса.

### Совместимость

- Собрано и проверено на **Warmane**, клиент 3.3.5a (билд 12340, Interface 30300).
- Разработано исключительно для **Warmane**. За работоспособность на других серверах я не отвечаю.
- **Плагины ElvUI продолжают работать.** Ничто не переименовано, не перенесено и не удалено:
  раскладка модулей, встроенные библиотеки и все публичные функции — апстримовские, поэтому всё
  сделанное под ElvUI 6.09 загружается здесь без изменений.

### Благодарности

- **ElvUI** — Elv, Bunny и команда ElvUI · [tukui.org](https://www.tukui.org/)
- **Порт на 3.3.5a, на котором всё стоит** — команда [ElvUI-WotLK](https://github.com/ElvUI-WotLK/ElvUI)
- **oUF** — Haste и авторы плагинов oUF
- **Эта сборка и её аудит** — **Keoo**

Made by Keoo for Warmane.
[Download](https://gitlab.com/keoo88/elvui)
