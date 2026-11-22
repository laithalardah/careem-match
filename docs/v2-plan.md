# Careem Match v2: group rooms, drill-down swiping, history-aware matching

Supersedes the two-player REST contract in CLAUDE.md. The hub screen is unchanged.

## 1. Flow
1. **Mode**: Match tile -> two cards: Food, Dine Out.
2. **Invite**: host gets a join link; people open it, type a name, and appear live in the list. Host has a crown.
3. **Lobby -> Settings**: when everyone is in, host taps Next and picks the meal: Breakfast, Lunch, Dinner, Dessert.
4. **Swipe, level 1 (categories)**: Shawarma, Burger, Pizza, Sushi, Breakfast, Healthy...
5. **Swipe, level 2 (restaurants)**: restaurants inside liked categories, each with a short description. Same deck for everyone.
6. **Dispute (only if there is no consensus)**: everyone votes how to settle it: **Spin the wheel** (one restaurant, picked at random, slices sized by supporters) or **Split** (separate group orders, one per restaurant bloc; people can switch group). See section 3b.
7. **Matching**: waiting screen with live progress per person, then the agent runs (once per group).
8. **Result**: restaurant (or one per group), who gets what, total, one-sentence reasoning, agent trace.
9. **Group order**: host approves, one basket per group is built, everybody is taken to their restaurant. No checkout.

## 2. Constraints found in the MCP (read before building)
| Ask | Reality | Decision |
| --- | --- | --- |
| Order history of every participant | MCP is single-user. `get_activities` returns only the authenticated user's orders. Sandbox has one persona (900000001) with 1-2 past food orders. | **Decided:** the host's history is real (MCP). Everyone else is a **mock participant ("demo friend")** with a seeded taste persona and seeded history, flagged `is_bot` and `source:"demo"`. Production later: each participant signs in (OAuth) and we use their token. |
| Group order | No group-cart or multi-user tool. `cart_add_items` builds ONE basket for the authenticated user. | Build one basket under the host's account, each line commented "for NAME". Host approves it. Never call checkout unless the user says so. |
| Dine Out | No DineOut tools in the MCP. | Same flow and matching; result has no basket, the final step is "Go there" (restaurant link). Label it as a suggestion. |
| Meal settings | Sandbox has 5 restaurants, 10 dishes, no dessert place. | Map meal -> cuisines. Empty meal = friendly empty state, or labelled demo entries in fallback.json. |
| Join links across devices | A link only works if other devices can reach the app and backend. | `PUBLIC_APP_URL` env/dart-define. Run backend on 0.0.0.0. Use LAN IP or a tunnel for the demo. |

## 3. Matching algorithm
Signals per participant p:
- **Swipes**: s_p(category) and s_p(restaurant) in {+1 like, -1 skip}, 0 if unseen.
- **History** (from `get_activities`, food, past): per cuisine and per restaurant, recency-weighted `w = 0.5^(age_days/30)`, normalised to 0..1 as h_p.
- **Settings**: meal -> allowed cuisines.
- **Quality**: rating and ETA from the menu call, normalised to 0..1 as q(r).

Steps:
1. **Candidates**: restaurants that are open, serve the chosen meal, and have an orderable dish.
2. **Level 1 deck**: categories of the candidates, ordered by group history prior.
3. **Level 2 deck**: top 8 restaurants inside categories liked by at least one person, ordered by group prior.
4. **Per-person utility**: `u_p(r) = 0.5*s_p(r) + 0.2*s_p(cat(r)) + 0.2*h_p(r,cuisine) + 0.1*q(r)`
5. **Group utility (fair)**: `U(r) = mean_p u_p(r) - 0.5 * std_p u_p(r)`. The std term penalises splitting the group.
6. **Veto**: drop r if anyone skipped both the restaurant and its category. If that empties the list, relax the veto and flag "compromise".
7. **Shortlist**: top 3 by U, with every person's score kept for the explanation.
8. **Bedrock agent** (Converse API, tool use, max 8 iterations): receives the shortlist plus evidence (votes, history, scores) and read-only MCP tools. It picks the winner from the shortlist only, checks open/menu/options, builds one or two dishes per person (prefers dishes liked or ordered before, resolves required options to the cheapest default), prices the basket, and returns a structured plan with a one-sentence reason and a "why" per person. It re-plans on failures (closed, dish unavailable, options required, no overlap).
9. **Validator** (code, not the model): winner must be in the shortlist, items must exist and be active, every person has at least one item, total is recomputed from menu prices. Anything else is rejected.
10. **Fallback**: if Bedrock errors (expired token) or loops out, the deterministic planner returns top-1 with default options, so the demo never dies.

## 3b. Disputes (no clear winner)
**Consensus** = some restaurant is liked by at least `CONSENSUS_THRESHOLD` of people (default 0.6) and nobody vetoed it. Checked when everyone finishes level 2, or when the host taps "Help us decide" after `DISPUTE_MIN_SWIPES` (default 5) swipes each. Nobody liked anything = `no_match`, not a dispute.

**Dispute** otherwise. Blocs = people grouped by their own top choice among the contenders (max 3 blocs). Everyone votes `wheel` or `split`; majority wins, ties go to the host's vote.
- **Spin the wheel**: server draws the winner (weighted by supporters, `secrets` module), so all devices land on the same slice. Clients animate from `spin_started_at_ms`, `duration_ms`, `final_angle_deg`. Winner is forced into the agent, which then builds the basket for everyone.
- **Split**: one group per bloc. Neutral people go to the bloc with their highest utility. Anyone can move themselves until the host confirms. The agent runs once per group; the result has one basket per group and the host's order creates one basket per restaurant (still no checkout).

**Demo friends** (`DEMO=1`): `POST /rooms/{code}/demo-friends` adds 1-4 bots with names, taste personas and seeded history (labelled demo). Bots swipe with 1.5-4 s delays, vote on the dispute method and join groups on their own. Scenario `dispute` picks personas that split the group, `consensus` picks matching tastes.

## 4. API v2.1 (single source of truth)
```
Base http://HOST:8000, JSON, CORS *. No real auth: participant_id acts as the token.
Stages: lobby -> settings -> swiping -> dispute (only if no consensus) -> matching -> result -> ordered

POST /rooms {mode:"food"|"dineout", host_name} -> {room_code, participant_id, join_url}
POST /rooms/{code}/join {name} -> {participant_id}           (409 unless stage == lobby)
GET  /rooms/{code}?participant_id= -> Room                   (clients poll every 1s)
  Room = {room_code, mode, stage, version, host_id, join_url, level:"category"|"restaurant"|null,
          settings:{meal:"breakfast"|"lunch"|"dinner"|"dessert"|null},
          participants:[{id,name,is_host,is_bot,progress:{level,swiped,total,done}}],
          dispute:null|{reason:"no_consensus"|"host_requested",
            contenders:[{restaurant_id,name,image_url,cuisine,supporter_ids:[id]}],
            method_votes:{participant_id:"wheel"|"split"}, method:null|"wheel"|"split",
            wheel:null|{segments:[{restaurant_id,name,weight}], spin_id, spin_started_at_ms, duration_ms, final_angle_deg, winner_restaurant_id},
            split:null|{groups:[{restaurant_id,name,image_url,participant_ids:[id]}], confirmed}}}
POST /rooms/{code}/demo-friends {participant_id, count:1..4, scenario:"consensus"|"dispute"|"random"}  host only, needs DEMO=1
POST /rooms/{code}/dispute/start   {participant_id}   host: swiping -> dispute early (after DISPUTE_MIN_SWIPES each)
POST /rooms/{code}/dispute/vote    {participant_id, method:"wheel"|"split"}
POST /rooms/{code}/dispute/spin    {participant_id}   host, method=="wheel"; server picks winner, then moves to matching after duration_ms + 2 s
POST /rooms/{code}/dispute/move    {participant_id, restaurant_id}   method=="split", before confirm: move yourself
POST /rooms/{code}/dispute/confirm {participant_id}   host, method=="split": -> matching (one plan per group)
POST /rooms/{code}/next     {participant_id}                 host only: lobby -> settings
PUT  /rooms/{code}/settings {participant_id, meal}           host only
POST /rooms/{code}/start    {participant_id}                 host only: settings -> swiping (level category)
GET  /rooms/{code}/cards?participant_id= -> {level, cards:[Card]}
  Category card   = {id, level:"category",   title, subtitle, image_url}
  Restaurant card = {id, level:"restaurant", title, description, cuisine, rating, eta_minutes, image_url, top_dishes:[str]}
POST /rooms/{code}/swipe {participant_id, level, card_id, liked} -> {ok, level_done}
  When EVERY participant finished a level the server advances everyone. After the restaurant level the stage becomes
  "matching" and the agent starts automatically.
GET  /rooms/{code}/result -> {status:"running"|"ready"|"no_match"|"failed",
  resolution:{type:"consensus"|"wheel"|"split"},
  groups:[{group_id, restaurant:{id,name,image_url,cuisine,rating,link}, participant_ids:[id],
           basket:[{participant_id,name,dish_name,price,image_url,options:[str]}], total_price, currency,
           reasoning, per_person:[{participant_id,name,why}]}],       // always present; length 1 unless split
  restaurant, basket, total_price, currency, reasoning, per_person,   // mirror groups[0] when length 1; restaurant=null when split
  scores:[{restaurant_id,restaurant_name,group_score,per_person:{participant_id:score}}],
  agent_trace:[{iteration,tool,input,output_summary,failed}]}
POST /rooms/{code}/order {participant_id}   host approval; one basket per group (cart_add_items per merchant), NEVER checks out
  -> {status:"basket_ready"|"go"|"failed", groups:[{group_id,status,price_breakdown,restaurant_link,message}]}   ("go" for dine out)
GET  /health -> {status:"ok", demo:bool}
```
Join link: `{PUBLIC_APP_URL}/#/join/{room_code}`.

## 5. Prompt for Antigravity (front end)
See `docs/prompt-antigravity.md`.

## 6. Prompt for Claude (backend)
See `docs/prompt-backend.md`.
