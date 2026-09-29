# Lead Collector

A [Tampermonkey](https://www.tampermonkey.net/) userscript that collects prospecting leads into a
session list you can copy out in one click. Two tabs:

- **Servers** — scans Discord web pages for server invite URLs.
- **Creators** — sweeps YouTube or TikTok search for creators and collects them as SpokPayCRM creator
  records.

It is fully self-contained: no API key, no database, no external service. Nothing is ever sent
anywhere — whatever it finds stays in the panel and in `localStorage` until you copy or clear it. The
CRM is fed by pasting, never by an automatic import.

## Install

1. Install the [Tampermonkey](https://www.tampermonkey.net/) browser extension.
2. Click
   **[install the script](https://raw.githubusercontent.com/RDevNeo/spok-lead-collector/main/lead-collector.user.js)**
   — Tampermonkey recognizes the `// ==UserScript==` header and opens its install prompt. (Installing
   from this URL is what registers the auto-update source; a copy-pasted script never updates itself.)
3. Open Discord web (`https://discord.com/*`), YouTube (`https://www.youtube.com/*`) or TikTok
   (`https://www.tiktok.com/*`) — the collector panel is injected on load, opening on whichever tab
   that site can run.

Works on Discord **web** in any desktop browser with a userscript manager. It does not run inside the
Discord desktop app, which has no userscript support.

## Tabs

The panel opens on the tab the current site can actually run: Discord shows **Servers**, YouTube and
TikTok show **Creators**. Selecting the other tab tells you where to go rather than offering controls
that cannot work — server collection drives the Discord DOM, creator collection reads YouTube's or
TikTok's own data.

## Target

Both tabs carry their own **Target** — the count the run stops at. Servers counts invites, Creators
counts creator records, and each tab remembers its own number, so a 100-creator sweep does not also
cap the next server scan. Leave it blank to collect everything the source gives; the `−`/`+` steppers
(and the arrow keys) move it in tens.

## Creators

**Source** picks the platform to sweep. YouTube and TikTok have collectors; the rest are listed as
*soon* and cannot be selected. A sweep runs on the platform's own site — open youtube.com for YouTube,
tiktok.com for TikTok (see [TikTok](#tiktok) below). Type a search term (e.g. `roblox blox fruits`) and
press Start. The YouTube sweep searches
across several surfaces, drops every channel that has not uploaded recently, then opens each
survivor's About data for its stats and profile links.
**Copy** puts the batch on your clipboard as JSONL — one complete JSON record per line — which is what
**SpokPayCRM → Creators → Import** expects. You paste it there yourself; nothing is imported
automatically.

| Field | Notes |
| --- | --- |
| `platform_id` | The `UC…` channel id — the record's stable identity |
| `handle`, `name`, `profile_url`, `avatar_url` | From the channel's canonical About data |
| `subscriber_count`, `video_count`, `view_count` | `null` when the channel hides the count — **not** `0` |
| `description`, `country` | From About |
| `links` | Profile links, with YouTube's `/redirect?q=` wrapper unwrapped |
| `discovered_via`, `captured_at` | Which search found them, and when |

### Dead channels are dropped

**Last upload** sets the freshness window — 7, 14 (default), 30 or 90 days, or *Any time* to turn the
filter off. A channel that has not uploaded inside the window never reaches your clipboard. The check
reads the channel's Atom feed (`/feeds/videos.xml?channel_id=…`), which answers with absolute ISO dates —
unlike the `/videos` tab, whose "3 days ago" is localized to whatever language the session is in.
Shorts count as uploads; they appear in the feed like any other video.

The gate runs **before** enrichment, and the feed is ~21KB against the About page's ~1.3MB, so
filtering makes a sweep cheaper rather than dearer. Every drop is named in the log with its reason —
`DROP <name>: dead - last upload 41 days ago (limit 14 days)` — and a channel whose feed cannot be
read at all is dropped too, logged as `could not check uploads`, since letting it through would
defeat the point. Kept channels record their freshness on the `OK` line. Because drops do not count
toward the Target, the sweep discovers past it to compensate.

On *Any time* the gate is skipped entirely — no feed request per channel, and the sweep behaves as it
did before the filter existed.

### Reaching the Target

One search surface is a shallow vein. The channel filter plus plain video search run dry at ~60
channels for a given term, so a target of 50 used to finish at 34 once the dead ones were dropped.

Discovery therefore walks a **list of surfaces** — channel results by relevance and by view count,
video results filtered to today / this week / this month, video results by view count and by upload
date, channel results by rating — harvesting after each and stopping the moment the target is met.
They rank differently, so they return materially different sets: measured on page 1 alone, *channels
by view count* was 20-for-20 channels the default filter never showed. The date-filtered video passes
run early on purpose: an uploader found under *today* has by definition just uploaded, so it survives
the freshness gate that discards most of the rest.

Each pass sizes itself from the keep rate the sweep has actually observed, so a term full of dead
channels asks for proportionally more. When every surface is exhausted and the target is still not
met, the log says so plainly instead of letting a short finish look like a complete one.

The profile links matter most: that is where a creator's Instagram, TikTok and Discord live. The CRM
flags a creator whose links include a `discord.gg` invite, since someone already running a server is a
materially stronger lead.

### Why the Creators tab reads JSON instead of clicking the page

The Servers tab drives the DOM because Discord only renders invite data in response to clicks. YouTube
does not: every page embeds a `ytInitialData` blob containing the channel list and the whole About
panel, so the sweep reads that. It is language-independent (no wordlists), survives cosmetic layout
changes, never navigates your tab or scrolls the page, and needs no per-channel page load in the UI.

Two traps that cost real bugs while building it, both verified against live YouTube HTML:

- In search results the field names **lie**: `subscriberCountText` holds the *@handle* and
  `videoCountText` holds the *subscriber count*.
- A link's `link.content` is only display text (`twitter.com/BloxFruits`); the real URL lives on the
  tap command and needs unwrapping from the `/redirect?q=` form.

## TikTok

Open `https://www.tiktok.com`, **logged in**, and the Creators tab sweeps TikTok the same way it sweeps
YouTube: discover accounts for the search term, drop the ones that have not posted inside **Last
upload**, read each survivor's profile, and store it as a creator record. Copy and the JSONL format are
the same.

**Where accounts come from**, in order, each harvested before the next runs:

| Pass | Source |
| --- | --- |
| Videos | The general (Top) search — the author of every video in it |
| Hashtag | The term read as a hashtag — `blox fruits` → `#bloxfruits` — skipped if no such tag exists |
| Accounts | TikTok's account search |
| On-screen results | Only when the tab is on a TikTok search or hashtag page: scrolls it and reads the result links |

The first three are TikTok's own `/api/…` endpoints, which only answer requests carrying TikTok's
signatures. The script never computes those itself: TikTok's security code already wraps the page's
`fetch` and signs same-origin calls, and the script runs in the page. When TikTok will not answer — it
replies with an **empty** body, not an error — the log says so, and the fix is to open
`https://www.tiktok.com/search/video?q=<term>` and press Start again: the on-screen pass then reads
the results you can see, which needs no signature.

**Freshness** is read from the account's **creator embed** (`/embed/@handle`) — TikTok's public embed
widget, whose HTML lists the account's newest videos. The embed shows no dates, but a TikTok video id
carries its creation time in its top 32 bits, so each id dates its upload without any localized "2d
ago" text. The same read supplies the three newest videos for the CRM podium (`recent_videos`). A
video the sweep already saw in search counts too. An account neither source can date is dropped as
`could not check uploads`; a private account has no embed and is named as such.

The video-list API (`/api/post/item_list/`) is not used: it answers with an empty body even to
TikTok's own app when that is not signed in, which in live use meant nearly every account went
unchecked.

**Profiles** come from the server-rendered `/@handle` page, which embeds the whole profile as JSON
(`__UNIVERSAL_DATA_FOR_REHYDRATION__`) and needs no signature. Both the profile and the embed are
fetched **without your cookies**: signed in, TikTok served most profile pages without their data,
while the anonymous pages read every time in testing. If a profile page still cannot be read, the
embed's shorter profile (no bio link or video count) stands in and the log says `NOTE … using its
embed instead`, so a live account is never lost to it.

| Field | Notes |
| --- | --- |
| `platform_id` | The numeric account id — stable across handle changes |
| `handle`, `name`, `profile_url`, `avatar_url` | From the profile page. The avatar URL is signed by TikTok's CDN and **expires** |
| `subscriber_count` | Followers, exact (not the rounded `96M` form) |
| `video_count` | Public videos |
| `view_count` | Always `null` — TikTok publishes no lifetime view total |
| `like_count` | Total likes received — TikTok's nearest audience signal (TikTok only) |
| `description` | The bio — where sellers usually put their WhatsApp, email or Discord |
| `links` | The single bio link, when the account has one |
| `country` | `null` unless TikTok includes a region in the profile |

TikTok challenges automated traffic far more readily than YouTube, so the TikTok sweep paces itself
slower. If a verification puzzle appears, solve it and press Start again; the log names it when it can
see it.

## Server modes

| Mode | What it does |
| --- | --- |
| **Sidebar** | Walks every server in the sidebar, opens each member profile and reads invites from status, bio and profile links. |
| **Discover** | Searches Discord's Discover page for a term, opens each result and copies the invite URL from the "Invite to Server" dialog. A **Language** dropdown pins Discord's language filter; it defaults to *Any language*, which leaves the filter untouched. |
| **Reader** | Scrolls the current channel upward and collects invite URLs found in messages. |

Invite URLs are normalized to `https://discord.gg/<code>` and de-duplicated within the session. The log
pane shows only collected invites and failures.

### Servers that will not hand out an invite

Plenty of Discover results reserve "Create Invite" for their own members, so no invite control is
rendered for a visitor at all. Discover skips those the moment it can tell — named in the log as
`SKIP <server>: …` with the reason — and moves straight to the next result, instead of treating the
missing dialog as a fault and reloading Discover to re-run the search.

## Auto-update

`@updateURL`/`@downloadURL` point straight at the raw file on `main` — no proxy, no token, no secrets.
On every push that changes the script, a GitHub Action (`.github/workflows/bump-version.yml`) bumps the
patch version, so Tampermonkey sees a new version on its next check (default: ~daily; forceable from the
dashboard). Push to `main` is all it takes to ship an update.

## Versioning

The script version lives in two places that must stay in sync: the `@version` field in the userscript
metadata header and the `SCRIPT_VERSION` constant in the body. The `bump-version` GitHub Action
increments **both** on each qualifying push, so you do not normally edit them by hand.

## Discover languages

The **Language** dropdown lists Discord's documented locales, each written in its own language, so the
options read the same whatever UI language you run. The list is built into the script rather than read
off the page, because Discord virtualizes its language dropdown — only the options scrolled into view
exist in the DOM at any moment. If Discover does not offer the language you pick, the scan says so in
the log and continues unfiltered instead of stopping.

## Discord UI language

The script drives Discord's DOM, so it prefers structural handles (roles, `data-` attributes,
container relationships) over on-screen text, which differs per language. Where a control has no
structural handle — the member-list toggle, the invite button — it ranks the likely candidates, clicks
one, and keeps it only if the expected thing happened, undoing the click otherwise. Visible labels are
scored as one signal among several, never used as the sole gate, so a language the wordlists do not
cover costs a few extra clicks rather than failing.

## License

[MIT](LICENSE).
