You are finishing the Flutter Web front end of "Careem Match" (hackathon, demo today). The hub screen is DONE and approved: do not redesign it, only wire the Match tile and the "Can't agree on dinner?" banner into the new flow. Work in `app/` only. Do not touch `backend/` or `sandbox/`. Never put secrets in the app. Commit small and often; run `flutter analyze` and `flutter test` before each commit.

## Product flow (build every screen)
1. **Mode**: tapping Match opens a screen with two large cards: "Food" (delivery) and "Dine Out". Tapping one creates a room (POST /rooms) and goes to Invite.
2. **Invite (host)**: shows the join link with Copy and Share buttons and a QR code, plus a live participants list. The host has a crown icon above the avatar. Names appear as people join (poll). "Next" is enabled once at least 2 people are in. If `/health` says `demo:true`, show an "Add demo friends" button (1-4 friends, scenario picker: Agree / Disagree / Random) that calls POST /rooms/{code}/demo-friends. Bots show a small "Demo" tag.
3. **Join (guest)**: opening `/#/join/{room_code}` shows a name prompt (one field, "Join" button, inline validation), calls POST /rooms/{code}/join, then shows the same participants screen without Next ("Waiting for the host"). Everyone sees everyone, crown on the host.
4. **Settings (host picks, guests watch)**: choose the meal with large selectable chips: Breakfast, Lunch, Dinner, Dessert. Guests see the host's choice update live. Host taps "Start".
5. **Swipe level 1: categories** (Shawarma, Burger, Pizza, Sushi, Breakfast, Healthy...). Same swipe mechanics as the existing deck (drag, Like/Skip buttons, arrow keys, screen-reader actions).
6. **Swipe level 2: restaurants**: a drill-down with a clear transition ("Now pick restaurants" interstitial, then cards slide in). Each card: image, name, cuisine tag, rating, ETA, 1-2 line description, up to 3 top dishes as chips. The host also gets a quiet "Can't decide? Help us decide" text button once they have swiped 5 cards (POST /dispute/start).
7. **Waiting**: after finishing a level, "Waiting for the others" with each person's avatar, name and a live progress bar. The screen advances automatically when the server's stage/level changes.
8. **Dispute (stage "dispute")**: when the room has no clear winner.
   - **Intro**: headline "No clear winner." Show the contenders (`dispute.contenders`) as side-by-side cards, each with its restaurant name and the supporters' avatars underneath (e.g. 2 people vs 2 people). Beneath, a vote: two large cards "Spin the wheel" (one restaurant, picked at random) and "Split into groups" (everyone gets what they want, separate orders). Everyone taps one (POST /dispute/vote); show live vote counts and who voted what. Majority wins; a tie is broken by the host's vote (say so in small text). When `dispute.method` is set, move to that method's screen.
   - **Wheel** (`method == "wheel"`): a custom-painted wheel (CustomPainter) whose slices come from `wheel.segments` sized by `weight`, labelled with restaurant names (small logo/image optional), pointer at the top, a 44 pt+ "Spin" button visible to the host only (guests see "Waiting for the host to spin"). The host taps Spin -> POST /dispute/spin. All devices then animate to the SAME result: when `wheel` appears, animate rotation from 0 to `final_angle_deg + 5 full turns` over `duration_ms`, starting at `spin_started_at_ms` (use the client clock offset from the server `Date` header if you can, otherwise start on receipt), with an ease-out-quart curve, a haptic tick each time a slice boundary passes the pointer, and a reveal of the winner card at the end ("{Restaurant} wins"). Reduce Motion: skip the spin, crossfade to the winner. Provide a "Skip animation" button. Announce the winner to screen readers (live region).
   - **Split** (`method == "split"`): show one card per `split.groups` entry (restaurant, member avatars). Every person sees a "Join this group" button on the other groups and can move themselves any time before the host confirms (POST /dispute/move); the UI updates live and animates the avatar moving. A group with nobody disappears. Host sees "Confirm groups" (POST /dispute/confirm). Guests see "Waiting for the host to confirm".
9. **Matching**: while the agent runs, a live "agent is working" screen listing tool calls as they arrive (from `agent_trace`).
10. **Result**: use `groups` (always present). With one group: restaurant hero, one-sentence reasoning, "Who gets what" grouped by participant (name, dishes, price), total in the response currency, an expandable "Why this one" with each person's `why`, and a collapsible "Agent trace" (failed calls tagged red, the re-plan visible). Show a small tag for `resolution.type` ("Everyone agreed", "Picked by the wheel", "Split into groups"). With several groups (split): a stacked section or segmented control per group with its own restaurant, members, items and total, plus a grand total, and the viewer's own group highlighted. `no_match` and `failed` get friendly states with Retry.
11. **Group order**: the host sees "Create group order" (for split: "Create N orders"). It opens a bottom sheet listing each restaurant, items per person and the total; its primary button calls POST /rooms/{code}/order and is the host's explicit approval. NEVER add a checkout or pay button. On success show "Order ready", then for everyone a "Go to {restaurant}" screen for THEIR group with a button that opens `restaurant_link` (url_launcher; if it can't open, copy it). Dine Out mode has no basket: the step becomes "Go there".

## Navigation and transitions (must feel smooth)
- Use `go_router` with the hash URL strategy so `/#/join/ABC123` works on Flutter Web. Routes: `/`, `/match`, `/room/:code`, `/join/:code`. The room screen switches its body by `stage` from the polled Room with one `AnimatedSwitcher` (250 ms, fade + 12 px rise, `Cubic(0.16,1,0.3,1)`). Forward navigation slides in from the right with a fade, back is the reverse.
- Card swipes: top card flies out, next card scales up (already built, keep it).
- Respect Reduce Motion (`MediaQuery.disableAnimationsOf`): replace slides and the wheel spin with crossfades.
- Back (browser or system) inside a room asks "Leave this room?" (HIG: confirm only because it is destructive). It must never break the room state.

## Data layer
- Extend the existing `Api` interface (`lib/api.dart`) with the v2.1 methods below. Keep `HttpApi` (base URL from `--dart-define=API_BASE`) and extend `MockApi`.
- `MockApi` runs the whole flow with no backend: an "Add demo friends" action adds fake participants, the fakes finish swiping after a few seconds, and the result is faked (include one failed tool call + re-plan in the trace). It must support both scenarios: **agree** (one restaurant wins) and **dispute** (two blocs; use the sandbox restaurants "Shawarma Station" vs "Pizza Piazza", never real third-party brand names), with the fake participants voting for the wheel or split and joining groups on their own. A dev toggle "Force dispute" is fine. Keep the yellow "Mock backend" tag.
- Poll `GET /rooms/{code}` every 1 s while in a room; rebuild only when `version` changes; stop on dispose; show a small non-blocking banner after 3 failed polls in a row. Keep your `participant_id` in memory and `sessionStorage` so a refresh keeps you in the room.

## Design rules (keep the existing look)
Use the tokens in `lib/theme.dart`: warm off-white canvas, 1 px #EAEAEA borders, near-invisible shadows, Newsreader serif for headings, Geist for UI, Geist Mono for ids and prices, pastel tags only, solid #111 primary button, radius 6 on buttons and 10 on cards. No emojis, no gradients (except the existing hub header), Phosphor icons only (crown = `crown`). Apple HIG: touch targets >= 44 pt, a semantic label on every control, text scales with system settings, inline validation, confirmation only where destructive, clear empty/loading/error states on every screen, skeletons instead of blocking spinners. Crown above the host's avatar everywhere participants are listed; "(you)" next to your own name. Distinct avatar colours per participant using the pastel pairs.

## API v2.1 (fixed contract, do not rename fields)
```
Base http://HOST:8000 (JSON). participant_id acts as the token.
Stages: lobby -> settings -> swiping -> dispute (only if no consensus) -> matching -> result -> ordered
POST /rooms {mode:"food"|"dineout", host_name} -> {room_code, participant_id, join_url}
POST /rooms/{code}/join {name} -> {participant_id}
GET  /rooms/{code}?participant_id= -> Room     (poll every 1 s)
  Room = {room_code, mode, stage, version, host_id, join_url, level:"category"|"restaurant"|null,
          settings:{meal:"breakfast"|"lunch"|"dinner"|"dessert"|null},
          participants:[{id,name,is_host,is_bot,progress:{level,swiped,total,done}}],
          dispute:null|{reason:"no_consensus"|"host_requested",
            contenders:[{restaurant_id,name,image_url,cuisine,supporter_ids:[id]}],
            method_votes:{participant_id:"wheel"|"split"}, method:null|"wheel"|"split",
            wheel:null|{segments:[{restaurant_id,name,weight}], spin_id, spin_started_at_ms, duration_ms, final_angle_deg, winner_restaurant_id},
            split:null|{groups:[{restaurant_id,name,image_url,participant_ids:[id]}], confirmed}}}
POST /rooms/{code}/next {participant_id}                  host: lobby -> settings
PUT  /rooms/{code}/settings {participant_id, meal}        host
POST /rooms/{code}/start {participant_id}                 host: settings -> swiping
POST /rooms/{code}/demo-friends {participant_id, count:1..4, scenario:"consensus"|"dispute"|"random"}  host, only when /health demo==true
GET  /rooms/{code}/cards?participant_id= -> {level, cards:[Card]}
  Category card   = {id, level:"category", title, subtitle, image_url}
  Restaurant card = {id, level:"restaurant", title, description, cuisine, rating, eta_minutes, image_url, top_dishes:[str]}
POST /rooms/{code}/swipe {participant_id, level, card_id, liked} -> {ok, level_done}
POST /rooms/{code}/dispute/start   {participant_id}       host: early dispute after 5 swipes
POST /rooms/{code}/dispute/vote    {participant_id, method:"wheel"|"split"}
POST /rooms/{code}/dispute/spin    {participant_id}       host, method=="wheel"
POST /rooms/{code}/dispute/move    {participant_id, restaurant_id}   split mode: move yourself
POST /rooms/{code}/dispute/confirm {participant_id}       host, split mode
GET  /rooms/{code}/result -> {status:"running"|"ready"|"no_match"|"failed",
  resolution:{type:"consensus"|"wheel"|"split"},
  groups:[{group_id, restaurant:{id,name,image_url,cuisine,rating,link}, participant_ids:[id],
           basket:[{participant_id,name,dish_name,price,image_url,options:[str]}], total_price, currency,
           reasoning, per_person:[{participant_id,name,why}]}],
  restaurant, basket, total_price, currency, reasoning, per_person,   // mirror groups[0] when 1 group; restaurant=null when split
  scores:[{restaurant_id,restaurant_name,group_score,per_person:{participant_id:score}}],
  agent_trace:[{iteration,tool,input,output_summary,failed}]}
POST /rooms/{code}/order {participant_id} -> {status:"basket_ready"|"go"|"failed", groups:[{group_id,status,price_breakdown,restaurant_link,message}]}
GET  /health -> {status:"ok", demo:bool}
```
Join link: `{origin}/#/join/{room_code}`.

## Done when
- Two browser tabs (host + guest) run the whole flow against `MockApi`, including a dispute resolved by the wheel and another resolved by a split, then against the real backend with `--dart-define=API_BASE=http://127.0.0.1:8000`.
- Widget tests cover: create room, join by link, crown on host, stage switching, level 1 -> 2 transition, waiting state, dispute vote, wheel result, split move + confirm, result with 1 and 2 groups, order sheet.
- `flutter analyze` is clean. End with a short summary of what is built and what is mocked.
