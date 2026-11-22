# Careem Match v2: group rooms, drill-down swiping, history-aware matching

Supersedes the two-player REST contract in CLAUDE.md. The hub screen is unchanged.

## 1. Flow
1. **Mode**: Match tile -> two cards: Food, Dine Out.
2. **Invite**: host gets a join link; people open it, type a name, and appear live in the list. Host has a crown.
3. **Lobby -> Settings**: when everyone is in, host taps Next and picks the meal: Breakfast, Lunch, Dinner, Dessert.
4. **Swipe, level 1 (categories)**: Shawarma, Burger, Pizza, Sushi, Breakfast, Healthy...
5. **Swipe, level 2 (restaurants)**: restaurants inside liked categories, each with a short description. Same deck for everyone.
6. **Matching**: waiting screen with live progress per person, then the agent runs.
7. **Result**: restaurant, who gets what, total, one-sentence reasoning, agent trace.
8. **Group order**: host approves, a basket is built, everybody is taken to the restaurant. No checkout.

## 2. Constraints found in the MCP (read before building)
| Ask | Reality | Decision |
| --- | --- | --- |
| Order history of every participant | MCP is single-user. `get_activities` returns only the authenticated user's orders. Sandbox has one persona (900000001) with 1-2 past food orders. | `HistoryProvider` interface. Real mode: host's history is real, others have none (swipes dominate). Demo mode: clearly labelled seeded histories per participant. Production later: each participant signs in (OAuth) and we use their token. |
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

## 4. API v2 (single source of truth)
```
Base http://HOST:8000, JSON, CORS *. No real auth: participant_id acts as the token.
Stages: lobby -> settings -> swiping -> matching -> result -> ordered

POST /rooms {mode:"food"|"dineout", host_name} -> {room_code, participant_id, join_url}
POST /rooms/{code}/join {name} -> {participant_id}           (409 unless stage == lobby)
GET  /rooms/{code}?participant_id= -> Room                   (clients poll every 1s)
  Room = {room_code, mode, stage, version, host_id, join_url, level:"category"|"restaurant"|null,
          settings:{meal:"breakfast"|"lunch"|"dinner"|"dessert"|null},
          participants:[{id,name,is_host,progress:{level,swiped,total,done}}]}
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
  restaurant:{id,name,image_url,cuisine,rating,link},
  basket:[{participant_id,name,dish_name,price,image_url,options:[str]}], total_price, currency, reasoning,
  per_person:[{participant_id,name,why}],
  scores:[{restaurant_id,restaurant_name,group_score,per_person:{participant_id:score}}],
  agent_trace:[{iteration,tool,input,output_summary,failed}]}
POST /rooms/{code}/order {participant_id}                    host approval; builds the basket, NEVER checks out
  -> {status:"basket_ready"|"go"|"failed", price_breakdown, restaurant_link, message}   ("go" for dine out)
GET  /health -> {status:"ok"}
```
Join link: `{PUBLIC_APP_URL}/#/join/{room_code}`.

## 5. Prompt for Antigravity (front end)
See `docs/prompt-antigravity.md`.

## 6. Prompt for Claude (backend)
See `docs/prompt-backend.md`.
