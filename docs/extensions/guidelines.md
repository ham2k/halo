# Guidelines

The reference pages say what each hook **can** do. This page says what an
operator expects an extension of each shape **to** do: the checks, the
alerts, the prefilled fields, the files, the polish that separates an
extension that installs from one people keep. Every item names the hook,
field or call that does it and links to where that is documented.

Ham2K's own extensions in
[ham2k/extensions](https://github.com/ham2k/extensions) do all of it, and
are the place to see each guideline as code. The extension named beside a
guideline is a good one to read.

Not every guideline fits every program. Where the rules you are
implementing say otherwise, the rules win; where they are silent, these are
the defaults operators expect.

## Every extension

- **Work offline, and say so when you cannot.** A park list, a contest's
  rules and a call history belong in a [`dataFile`](activities.md#datafile)
  or in the bundle, not behind a fetch on every keystroke. When a network
  call fails, answer with what you have (`[]`, `null`, the last good
  result) and keep the hook alive; an error the operator must act on goes
  through [`host.statusBar`](host.md#hoststatusbar) or a `userMessage`.
- **Look like the program.** The manifest's `icon` and `accentColor` are
  the program's own glyph and color, on the extension's row and on your
  references' chips; give your logging controls the same `icon` and
  `color`, which the activity picker and the spot rows carrying your
  references draw.
- **Pick an icon that names the program at a glance.** A
  [Material Design Icons](https://pictogrammers.com/library/mdi/) name, or
  a FontAwesome solid name prefixed `fa-`, showing what the program is
  about: a lighthouse for lighthouses, a summit for summits, a trophy or a
  stopwatch for a contest. It is drawn small, beside other programs' icons,
  so choose a simple, filled shape that reads at that size, and one no
  other program you would be listed with already uses. Check the name: an
  unknown one draws a placeholder.
- **Pick a color that is the program's and reads everywhere.** The
  program's own color where it has one, from its logo or website, so
  operators recognize it; otherwise one that suits the subject (green for
  parks, blue for water). It tints small chips and icons on light and dark
  backgrounds alike, so choose a mid-tone with enough contrast against
  both, not a pale pastel or a near-black, and one distinct from the
  programs it will sit beside on the same spots board.
  `shortName` is the name where there is no room: a logging control's
  label, and the locked assistance and self-spotting switches, which name
  it as the rules they follow. Keep it to what operators call the program
  ([The manifest](manifest.md#listing)).
- **Be found by every name.** `keywords` carry the names and
  abbreviations operators search for beyond `name` and `description`, and
  `translations` give the name, description and keywords in each language
  you support. They are what the Extensions panel and the catalog search,
  separately from the names your `suggest` answers to.
- **Say what it is.** An `ABOUT.md` beside the manifest is the longer
  story `description` has no room for: what the program is, what the
  extension does, what it needs from the operator and where its rules are.
  It shows on the install screen, in the extension's details and on its
  catalog page
  ([The manifest](manifest.md#about)).
- **Show it.** A `screenshots/` folder published with the extension shows
  on its row in the activity search, on the install consent screen and in
  its details: an operator deciding whether to install sees what they get
  ([Publishing](publishing.md#screenshots)).
- **Say where, when and for whom it matters.** The manifest's
  [`relevance`](manifest.md#relevance) ranks your extension in the catalog
  for each operator's own callsign: a regional program lists its
  `countries`, `entities`, `continents` or `ituRegions`, an event lists the
  `dates` it starts on, and an extension dedicated to one mode, band group
  or style lists that `interest`. It ranks and never hides, so an operator
  elsewhere still finds it; without it, your extension is listed as
  worldwide and undated, behind the ones that say they are for this
  operator.
- **Ask for the least.** `domains`, `webSockets` and every `requires*`
  grant are read by the operator at install. Name exactly the hosts and
  capabilities the code uses ([The manifest](manifest.md)).
- **Stay out of the way of operations that are not yours.** An `activity`
  hook asked about an operation that does not carry your reference returns
  nothing, and decides that first, before any other work: the operator may
  have twenty extensions on, and every one is asked. Scope a scorer to your
  reference types with `scope: { refTypes }` so it is never asked at all.
- **Keep the log's data stable.** A reference type, a control key, a spot
  `source` and an export type end up in logs, layouts and settings. Choose
  them once; renaming one orphans everything written under the old name.
- **Speak the operator's language.** Translate every string the operator
  reads ([Text and locale](localization.md)), format distances in
  `ctx.distanceUnits` and numbers with the operator's separators, and name
  the app to services as `ctx.appName`.
- **Settings under the heading for what the extension is.** The app groups
  extensions' settings under headings by purpose (`activities`, `hunting`,
  `contests`, `lookups`, `spotting`, `dashboard`), and that is where yours
  go, rather than in a category of their own. Place them in another
  category (`logging`, `radio`, `map`, `exports`) only when the extension
  tunes what that category holds ([Settings
  panels](settings.md#where-an-extensions-settings-go)). A switch the
  operator flips mid-operation also takes `target: 'logging'`, which puts it
  under the logging view's tune icon as well. Every setting has a default
  that works, so an extension is useful the moment it is installed.
- **Logins as accounts, checked when entered.** A login or an API key is an
  [`account`](accounts.md), never a settings field, and its
  `testCredentials` tries it when the operator connects and answers a
  sentence they can act on. A key that is wrong is found while they are
  typing it, not at their first spot from a summit.

## Activities

An award program: parks, summits, islands, lighthouses, castles, tiles.
Most of what follows comes free with the
[`referenceActivity` factory](activities.md#the-referenceactivity-factory)
and [`activityScorer`](scoring.md#scoring-an-activity); the list is also
what to check when you go past them. Read `ham2k-wwbota` for the factory in
use, `ham2k-pota` for everything at once.

### Finding a reference

- **Offer what is nearby.** A [`suggest`](activities.md#suggestions) call
  with no `searchTerm` answers the references around `location`, each with
  its `distance`, so an operator setting up in the field taps the one they
  are standing in. When the results map is panned, answer every reference
  inside `bounds`. `nearbyLookupRows` reads both cases from your
  `dataFile`.
- **Find by code and by name.** A `searchTerm` matches the reference code
  (`US-1234`, `us1234`, `1234`) and words of the name ("bear mountain").
  Rank with `relevance` so an exact code beats a name that merely contains
  the term.
- **Offer the code the operator typed, listed or not.** A scoped search for
  a code your list lacks answers that code anyway, labeled unknown or
  invalid. A reference handed to the operator on the air must never meet
  "no results".
- **Show the shape in the results.** Each suggestion carries its point
  (`lat`/`lon`) and, where the program has one, its
  `activationRadiusInMeters`, because a suggestion is stored as you return
  it and the results map circles it from there. `geojsonUrlForRef` answers
  for a suggestion as it does for a decorated reference: the results map
  draws the outline of the one whose card is open, and the rest once the
  operator zooms in. An operator choosing between two parks a mile apart
  chooses by where the boundary runs.
- **Keep the list fresh.** Set the `dataFile`'s `maxAgeInDays` to how often
  the program publishes, and mark retired references with `flags: 0` rather
  than dropping them, so an old log still decorates. A settings panel with
  `dataFilesSection: true` puts your list in the Data Files screen too,
  where operators go to refresh lists before a trip.

### Describing a reference

- **Name it, place it, link it.** [`decorateRef`](activities.md#reftype)
  fills `name`, `lat`/`lon` or `grid`, and `state` where the reference sits
  in exactly one; `linkForRef` points at the program's page for it.
- **Draw it.** Set `activationRadiusInMeters` (or feet) where the program
  has an activation zone, `geojsonUrlForRef` where it publishes boundaries,
  and `largeArea: true` on a reference whose point is only representative.
- **Title the operation.** `suggestOperationTitle` answers the `at`
  fragment for an activation ("at Bear Mountain SP"), so the operation list
  reads well without the operator typing a title.

### Logging

- **A hunting control, when the program credits hunters.** A `refList`
  logging control with the program's `pattern`, a `placeholder` showing the
  code's shape, and a `numbersRowKey` of `-` where codes carry one. A value
  that fails the pattern is tinted, never refused.
- **Reformat as the operator types.** `transforms` turn what is quick to
  type into the code the program writes: a bare `1234` into `US-1234`, a
  space between two codes into a comma. `refInput` makes the prefix and
  the placeholder follow the station being worked, or the operator's own
  station, so digits typed while working a VE station become `CA-` codes.
- **Place the station at its reference.** A
  [`lookup`](lookups.md#lookup) that answers for the contact being logged
  gives the hunted reference's grid, location and state as where the other
  station is, more precise than their home address. Distance, bearing and
  every state-based contest and award then read the right place. Answer it
  from your offline list.
- **Prefill what the operator is about to type.** A spot that carries the
  reference in `refs` is how a hunter's contact gets it filled in: a
  [`recentContextLookup`](lookups.md#recentcontextlookup) source reads the
  recent spots for the call being typed (`ctx.getSpotsForCall`) and offers
  their references, so the activator the operator clicked arrives with
  their park. A spot feed that leaves `refs` empty leaves every hunter to
  type it.
- **Recognize park-to-park.** A contact that carries a hunted reference
  while the operation activates one is a P2P; let the scorer say so
  (`p2pLabel`) and let the export write both sides.

### Rules, dupes and alerts

- **Score the activation.** `qsosToActivate`, `activates` and `uniquePer`
  give the operator a running "7 of 10" and the moment the activation
  counts, per reference and per UTC day as the program counts them.
- **Judge repeats by the program's rules, not the app's.** A station worked
  again on a new band, a new day or from a new park may count again; a
  verdict that rules on it carries `dupe` (`false` included) and a
  `newBand`, `newDay` or `newRef` notice, so the app's own call-band-mode
  rule never contradicts yours ([Worked-before is
  shared](scoring.md#scoring)).
- **Flag the reference worth chasing.** A [`chasing`](scoring.md#chasing)
  program for the hunting side keeps the operator's checklist, ranks spots
  by what working them would add, and marks a new reference as it is typed.
  Word its notices in the program's terms (`refLabel`, `notices`: "New
  park", not "New reference"), and let `importClaims` read the program's
  own hunter export, so the checklist starts from the operator's real
  record rather than from the first contact logged in the app. The
  [Award checklists](#award-checklists) section has the rest.
- **Show the history that matters.** `ctx.getHistoryForCall` with
  `refType` and `refPrefix` answers "worked this activator at this park
  before" in one call, without reading the whole log
  ([The hook context](host.md#the-hook-context)).

### Spots

- **Both directions, when the program has a spotting service.** A
  [`spots`](spots.md#spots) source feeds the board with each spot's
  references, and posts the operator's self-spot from the operation's own
  reference and frequency.
- **Offer self-spotting only where it applies.** `isSelfSpotEnabled` answers
  `enabled: true` only for an operation that activates one of your
  references. The app already withholds spots and self-spots from an
  operation whose rules forbid them.
- **Report what happened.** A post that fails answers `ok: false` with a
  `userMessage` the operator can act on ("the API key was refused"), not a
  silent drop.

### Exports

- **The files the sponsor requires.** An
  [`export`](import-export.md#export) option for each file the program's
  submission asks for, in the shape its upload takes, named with
  `exportFilename` and carrying `refType` (and `ref` where a file covers one
  reference of several). `activityExportHook` builds it.
- **Only the fields the sponsor reads.** A submission carries the contact
  and the references, not the operator's notes about who they met. Declare
  the type with `includePrivateData: false` and forward the request's
  settings when you delegate to `adifForExport`, so an operator who chooses
  otherwise is honored. A field only your own submission needs (both
  gridsquares, say) goes out when `mainHandler` is true, and stays out of
  the full export.
- **Records the way the sponsor counts them.** Where the program wants
  one record per hunted reference, `splitRecordsPerHuntedRef` (or
  `fieldCombinationsForOneQSO`) writes that many in your own submission;
  where it does not, one contact is one record. An uploader that requires
  `OPERATOR` on every record gets it through `operatorFallback`.
- **Settings for your file types, and the right one selected.**
  `getExportTypes` lists your types in the export settings, where the
  operator chooses file names, titles and whether private data goes out;
  an exporter without it has no entry there. The file the operator submits
  every time is `selectedByDefault`.
- **Write your references on every ADIF file, and read them back.**
  [`adifFields`](import-export.md#adiffields) answers `SIG`/`SIG_INFO` and
  your `*_REF` fields as whole pairs; [`adifImport`](import-export.md#adifimport)
  reads both spellings back, so a log moved between apps keeps its parks.

## Contests

A contest, a sprint, a QSO party, a field day. Read `ham2k-simple-contest`
for the smallest one, `ki2d-ssb-sprint` and `ham2k-cqww` for whole ones.

### Finding the contest

- **Find it by any name it is known by.** The full name, the short name,
  the sponsor's abbreviation, the spellings operators use, and for a
  regional event the state or province it covers: an operator looks for a
  QSO party by where it is.
- **Rank by how soon it runs.** `relevance` follows how close in time the
  next running is, highest while it runs, so the weekend's contest leads
  the list and one eleven months off stays out of the way.
- **Tag the dates and the region in the manifest.** The next runnings'
  start days in `relevance.dates`, and the region a regional event covers,
  so the catalog puts it in front of the operators it is for in the weeks
  it matters.
- **Put the date in the suggestion.** The next running's date goes in the
  suggestion's `name`, after the contest's name: an operator choosing
  between runnings, or between the parties of one weekend, chooses by
  when.
- **Do not offer it twice.** An operation already running the contest is
  offered nothing from `suggest`; changing its setup is the setup form's
  job.

### Setup

The setup is a [`form` control](activities.md#controls) in
`operationControls`, and it is where the Cabrillo header and the rules come
from.

- **Ask for everything the log submission needs, and nothing else.** The
  entry's categories as the sponsor's rules define them, the operators, the
  club, the location, and the exchange the station sends (zone, state,
  section, name, power, a starting serial). A field the sponsor never asks
  for is a field the operator must skip.
- **Ask in the sponsor's terms, and derive the Cabrillo from them.** The
  rules offer "Single Operator Assisted", not four header lines. One
  well-chosen question answers `CATEGORY-OPERATOR`, `CATEGORY-ASSISTED`,
  `CATEGORY-TRANSMITTER` and `CATEGORY-STATION` together, and the export
  writes only the combinations the rules allow: an overlay only for an
  entry that may claim one, an all-band entry for a category that has no
  other.
- **Ask what decides the rules.** The category that determines whether
  spotting assistance and self-spotting are allowed is a setup field, and
  [`decorateRef`](activities.md#what-a-reference-forbids) states the result
  on the reference as `assistance: false` or `selfSpotting: false`. The app
  then turns those off for the whole operation and shows why. Show the
  result in the form too, beside the category, so the operator sees the
  consequence of the choice before saving.
- **Seed the setup from what is known.** The categories start from the
  operator's previous participation in this contest and in similar ones:
  remember the entry they declared (in your settings, through
  `host.setSettings`) and offer it again, and leave a category "not
  declared" only when there is nothing to go on. The sent exchange starts
  from what the app already knows: the zone or state from the station call
  and its location, the name, email and club from the operator's profile
  through `host.getSettings`, the running nearest on the calendar.
- **Link the rules and title the operation.** `linkForRef` points at the
  sponsor's rules; `suggestOperationTitle` answers `for` with the contest
  and a `subtitle` with the sent exchange, the line an operator re-reads
  all weekend.

### Logging

- **Only the exchange fields, and only while the contest runs.** A logging
  control per part of the received exchange, returned only for an operation
  carrying your reference, in the order the exchange is sent.
- **Prefill the exchange, from the best source first.** `suggestedValue`
  fills a field the operator has not typed into. Take the first of these
  that answers:
  1. what the same station sent most recently earlier in this contest
     (`ctx.getHistoryForCall` with your `refType` and the `operation`);
  2. a call history file (a [`dataFile`](activities.md#datafile) with an
     `n1mm-history:` URL);
  3. what the station sent in past operations of this contest and similar
     ones (`ctx.getHistoryForCall` with their reference types);
  4. the lookup's guess (`qso.their.guess`: state, zone, name) and the
     country file.

  A `placeholder` shows a real candidate value, never a format hint like
  "1-40" that reads as one.
- **Validate without refusing.** `pattern` tints an exchange that does not
  fit; an `options` field with the contest's multipliers (sections,
  counties, prefectures) offers completions as the operator types, with
  `allowFreeform` where the list may be incomplete.
- **Serials the app keeps.** A `serial` control allocates the sent number at
  commit; mark it `skipFocus` so Space and Tab go from call to exchange.
- **Record what was logged.** [`processQsoBeforeSave`](activities.md#processqsobeforesave)
  writes the exchange the scorer used onto the contact, guesses resolved,
  and mirrors it into `their.exchange` (and a varying sent part into
  `our.exchange`), so the QSO list and a plain ADIF show it.

### Dupes, multipliers and alerts

- **Dupe-check by the contest's rules.** Once per band, per band and mode,
  per period, per county line: whatever the rules say, in `scoreQso`. Emit
  `dupe` every time the test runs, `false` included, so the operator sees
  your verdict before pressing Enter and the app's own rule never
  contradicts it.
- **Announce what a contact is worth.** A `newMult` notice for a new
  multiplier, `invalidBand` or `invalidMode` alerts for a contact the
  contest does not score, all on the call being typed, live.
- **Hold back a contact that is missing its exchange.** The live verdict
  names the fields still empty in `incomplete` (extension API 15), and the
  app keeps Enter from logging until they are filled, while a `?` or
  Shift+Enter still logs it as it stands. Name only what is missing; an
  exchange that is present but wrong is an `invalidExchange` alert, shown
  and logged ([Scoring & chasing](scoring.md#scoring)).
- **Mark the spots worth working.** The verdict for a spot candidate names
  an `icon` and `color` for a multiplier, so the spots board shows the
  operator where the points are.
- **Say the score the way the sponsor computes it.** `contestSummary` with
  a `contestArithmetic` line: contacts, points, multipliers, total.
- **Remind the operator of the rules the log can see.** A QSY rule, an
  off-time minimum, a band-change limit, a period about to end: a
  [`host.fyi`](host.md#hostfyi) message on the line under the call, with
  `radio` set under SO2R so each radio shows its own (extension API 14).
  `ki2d-ssb-sprint` does this for the Sprint's QSY rule.

### Cabrillo and contest ADIF

- **The Cabrillo the sponsor accepts.** Header lines from the setup form
  (categories, operators, club, location, the operator's name and email),
  QSO lines in the sponsor's column template, the exchange exactly as the
  scorer resolved it, and a transmitter column for a two-transmitter entry.
  A category the setup leaves undeclared is left out of the header, never
  invented at export.
- **A contest ADIF beside it.** `CONTEST_ID`, `STX`/`SRX` or
  `STX_STRING`/`SRX_STRING` through [`adifFields`](import-export.md#adiffields),
  so the same log goes to an uploader or another logger with its exchange.
- **Named for the event.** `exportFilename` with the contest's tag as
  `activity` (`CQ-WW-CW`), and the request's `compactFilenames` passed
  through, so the file sits beside the operator's others, named the same
  way.
- **Listed in the export settings, and selected.** `getExportTypes` for
  both types, and `selectedByDefault` on the Cabrillo, the file the
  operator submits after every running.

## Award checklists

An award kept as a checklist across every operation: DXCC, WAS, counties,
grid fields, prefixes, a club's members. A [`chasing`](scoring.md#chasing)
program; read `ham2k-was`, then `ham2k-dxcc`.

- **Claims from the contact alone.** `claimsForQsos` answers from each
  contact and your own data, never from the rest of the log: the app asks
  it about spots, about the call being typed, and about contacts on a
  device that holds only part of the log.
- **The granularities the award has.** Claim each slot the award counts: the
  mixed line, each band, each mode group the award recognizes, with `null`
  for "any". A five-band award claims five bands and the mixed line.
- **Worked, confirmed, verified.** `level` follows the QSL the award
  accepts (`qso.qsl`) and the sponsor's own credit (`qso.credits`), so the
  operator sees what is worked and still needs a card.
- **The sponsor's credit, imported.** `importClaims` reads the file the
  sponsor or the QSL service hands out, so the operator's checklist matches
  their award record on the day they install.
- **Notices and spots in the award's words.** `refLabel` and `notices`
  ("New county", "New on 40m"), `supersedes` for the app's own notice your
  verdict replaces, and an `icon` and `color` that mark the spots that
  would add a new entry.
- **Raise `version` when the rules change.** Contacts that would claim
  something different under the new rules are claimed again; the app keeps
  nothing from an older version.
- **Editions as the award runs.** `lifetime`, `annual` for a yearly
  challenge, `event` for one weekend.

## Dashboard panels

A pane the operator places in a view: a rate meter, a band map, a clock, a
propagation chart, a front panel. Read `ki2d-rate-chart` and
`ki2d-band-map` for scenes, `ki2d-weather-panel` for themes and settings.

### Choosing the content

- **A scene for anything live, drawn or interactive.** A
  [scene](scenes.md) keeps values moving under bindings, answers controls
  and scrolls natively, with no bridge call per frame. A meter, a chart, a
  dial, a map of the band: a scene.
- **Markdown for text.** It renders with the app's own typography, theme
  and font scale for free. Reach for `html` only for what neither can do,
  knowing it is not drawn on every platform.

### Looking at home

- **Draw with the app's colors.** A scene's `environment.colors` carries the
  theme's `surface`, `onSurface`, `accent`, `primary`, `error` and the rest,
  and `environment.typography` its fonts and sizes ([The render
  environment](scenes.md#the-render-environment)). Built from those, a panel
  follows light, dark and the operator's accent, and the app re-renders it
  when they change.
- **Then offer a choice.** A theme setting on the panel's `form`,
  Automatic (the app's colors) by default and a few fixed schemes beside
  it, lets one placement stand apart: a dark band map on a light layout, a
  high-contrast meter across the room. Accent colors for series, bands or
  operators are good settings too.
- **Fit any pane.** Size the scene to `environment.width` and `height`,
  respect `safeInsets`, and decide what to drop when the pane is narrow or
  short rather than shrinking everything. Reserve label space with
  `scaledFontSize`.
- **Respect the operator's accessibility settings.** `reducedMotion` turns
  animation off; `highContrast` asks for stronger edges and ink;
  `textDirection` and `locale` lay text out.

### Settings

- **Settings per placement, in the descriptor's `form`.** What to show, the
  range or scale, units, a goal, a theme: the app draws the form behind the
  panel's gear in Layout Setup and hands the values back as `args.config`
  ([Panels](panels.md#the-descriptors-other-fields)). Every field has a
  default that renders something useful.
- **`multiple` where two make sense**, with a `title` on each render so the
  placements can be told apart: two band maps, two clocks in different
  zones.
- **A `preview`** for the list of panels, so the operator knows what they
  are placing.

### Updating cheaply

- **Declare the fewest triggers that keep the panel right.** `qsoLogged`
  for a log summary, `spots` for a spots view, `lookup` rather than `qso`
  for the station being worked, a `tick` no faster than what the panel
  shows changes ([Triggers](panels.md#triggers)).
- **Bind rather than re-render.** A frequency readout binds to
  `radio.frequencyHz`; a needle binds its rotation to a value. Only a
  change of layout needs a render.

### Saying what is going on

- **An empty state for every absence.** No operation, no contacts yet, no
  radio connected, no network, a setting needed: the pane says which, in a
  sentence, rather than drawing an empty chart.
- **Act where the operator expects it.** A tap on a spot in a band map puts
  the station in the logging fields through `host.suggestQso` (extension
  API 12, `requiresRadioWrite`); hovering a chart inspects its points.
