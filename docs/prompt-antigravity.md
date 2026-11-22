You are finishing the Flutter Web front end of "Careem Match" (hackathon, demo today). The hub screen is DONE and approved: do not redesign it, only wire the Match tile and the "Can't agree on dinner?" banner into the new flow. Work in `app/` only. Do not touch `backend/` or `sandbox/`. Never put secrets in the app. Commit small and often, run `flutter analyze` and `flutter test` before each commit.

## Product flow (build every screen)
1. **Mode**: tapping Match opens a screen with two large cards: "Food" (delivery) and "Dine Out". Tapping one creates a room (POST /rooms) and goes to Invite.
2. **Invite (host)**: shows the join link with Copy and Share buttons and a QR code, plus a live participants list. The host row has a crown icon on top of the avatar. Names appear as people join (poll). A "Next" button is enabled once at least 2 people are in.
3. **Join (guest)**: opening `/#/join/{room_code}` shows a name prompt (one field, "Join" button, validation inline), calls POST /rooms/{code}/join, then shows the same participants screen without the Next button ("Waiting for the host"). Everyone sees everyone, crown on the host.
4. **Settings (host picks, guests watch)**: choose the meal with large selectable chips: Breakfast, Lunch, Dinner, Dessert. Guests see the host's choice update live. Host taps "Start".
5. **Swipe level 1: categories** (Shawarma, Burger, Pizza, Sushi, Breakfast, Healthy...). Same swipe mechanics as the existing deck (drag, Like/Skip buttons, arrow keys, VoiceOver actions).
6. **Swipe level 2: restaurants**: a drill-down. Show a clear transition from level 1 to 2 (a short "Now pick restaurants" interstitial, then cards that slide in). Each card: image, name, cuisine tag, rating, ETA, a 1-2 line description, and up to 3 top dishes as small chips.
7. **Waiting**: after finishing a level, show "Waiting for the others" with each person's avatar, name and a progress ring/bar (live). The screen advances automatically when the server says so.
8. **Matching**: while the agent runs, show a live "agent is working" screen listing tool calls as they arrive (from agent_trace).
9. **Result**: restaurant hero, one-sentence reasoning, a "Who gets what" list grouped by participant (name + dishes + price), total in the response currency, a collapsible "Agent trace" (failed calls tagged red, the re-plan visible), and an expandable "Why this one" with each person's `why`. For `no_match` and `failed`, friendly states with Retry.
10. **Group order**: host sees "Create group order". Tapping opens a bottom sheet confirming restaurant, items per person and total; the primary button calls POST /rooms/{code}/order. This is the host's explicit approval. NEVER add a checkout/pay button. On success show "Order ready" and, for everyone, a "Go to {restaurant}" screen with a button that opens `restaurant.link` (use url_launcher; if it can't open, copy it). For Dine Out mode there is no basket: the order step becomes "Go there".

## Navigation and transitions (important, it must feel smooth)
- Use `go_router` (hash URL strategy so `/#/join/ABC123` works on Flutter Web). Routes: `/`, `/match`, `/room/:code`, `/join/:code`. The room screen switches its body by `stage` from the polled Room, with one `AnimatedSwitcher` (250 ms, fade + 12 px rise, `Cubic(0.16,1,0.3,1)`).
- Level 1 -> level 2 and screen -> screen use shared, consistent transitions: forward = slide from right + fade; back = reverse. Cards: top card flies out, next scales up (already built, keep it).
- Respect Reduce Motion (`MediaQuery.disableAnimationsOf`): swap slides for crossfades.
- Android/iOS back and browser back must never break the room: from a room, Back asks "Leave this room?" (HIG: confirm only because it is destructive).

## Data layer
- Extend the existing `Api` interface (`lib/api.dart`) with the v2 methods below, keep `HttpApi` (base URL from `--dart-define=API_BASE`) and extend `MockApi`.
- `MockApi` must simulate a full multi-person room with no backend: a "Simulate friends joining" dev button adds 2 fake participants, fake participants finish swiping after a few seconds, and the agent result is faked (include one failed tool call + re-plan in the trace). Mark mock mode with the existing yellow "Mock backend" tag.
- Poll `GET /rooms/{code}` every 1 s while in a room; only rebuild when `version` changes. Stop polling on dispose. Show a small non-blocking banner if the poll fails 3 times in a row.
- Keep your own `participant_id` in memory and in `sessionStorage` so a refresh keeps you in the room.

## Design rules (keep the existing look)
Use the tokens in `lib/theme.dart`: warm off-white canvas, 1 px #EAEAEA borders, near-invisible shadows, Newsreader serif for headings, Geist for UI, Geist Mono for ids and prices, pastel tags only, solid #111 primary button, radius 6 on buttons and 10 on cards. No emojis, no gradients (except the existing hub header), Phosphor icons only. Apple HIG: touch targets >= 44 pt, every control has a semantic label, text scales with system settings, inline validation, undo/confirm only where destructive, clear empty/loading/error states on every screen, skeletons instead of blocking spinners. Show a crown (Phosphor `crown`) above the host's avatar everywhere participants are listed. Names are shown as "Name" with "(you)" for yourself.

## API v2 (fixed contract, do not rename fields)
```
Base http://HOST:8000 (JSON). participant_id acts as the token.
Stages: lobby -> settings -> swiping -> matching -> result -> ordered
POST /rooms {mode:"food"|"dineout", host_name} -> {room_code, participant_id, join_url}
POST /rooms/{code}/join {name} -> {participant_id}
GET  /rooms/{code}?participant_id= -> Room
  Room = {room_code, mode, stage, version, host_id, join_url, level:"category"|"restaurant"|null,
          settings:{meal:"breakfast"|"lunch"|"dinner"|"dessert"|null},
          participants:[{id,name,is_host,progress:{level,swiped,total,done}}]}
POST /rooms/{code}/next {participant_id}                 host only: lobby -> settings
PUT  /rooms/{code}/settings {participant_id, meal}       host only
POST /rooms/{code}/start {participant_id}                host only: settings -> swiping
GET  /rooms/{code}/cards?participant_id= -> {level, cards:[Card]}
  Category card   = {id, level:"category", title, subtitle, image_url}
  Restaurant card = {id, level:"restaurant", title, description, cuisine, rating, eta_minutes, image_url, top_dishes:[str]}
POST /rooms/{code}/swipe {participant_id, level, card_id, liked} -> {ok, level_done}
GET  /rooms/{code}/result -> {status:"running"|"ready"|"no_match"|"failed",
  restaurant:{id,name,image_url,cuisine,rating,link},
  basket:[{participant_id,name,dish_name,price,image_url,options:[str]}], total_price, currency, reasoning,
  per_person:[{participant_id,name,why}],
  scores:[{restaurant_id,restaurant_name,group_score,per_person:{participant_id:score}}],
  agent_trace:[{iteration,tool,input,output_summary,failed}]}
POST /rooms/{code}/order {participant_id} -> {status:"basket_ready"|"go"|"failed", price_breakdown, restaurant_link, message}
```
Join link format: `{origin}/#/join/{room_code}`.

## Done when
- Two browser tabs (host + guest) can run the whole flow against `MockApi`, then against the real backend with `--dart-define=API_BASE=http://127.0.0.1:8000`.
- Widget tests cover: create room, join by link, crown on host, stage switching, level 1 -> level 2 transition, waiting state, result, order sheet.
- `flutter analyze` is clean. Short summary of what you built and what is mocked at the end.
