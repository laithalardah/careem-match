Change request for the Careem Match Flutter app (backend API v2.2 is done and committed; see `docs/v2-plan.md` section 4a). Work in `app/` only.

## What changed in the product
Swiping now chooses the RESTAURANT only. Nobody picks dishes in our app any more, and our app builds no basket and shows no prices. After the match (and the wheel or split, if the group disagreed) everyone is sent to the chosen restaurant in Careem, where the host starts Careem's normal group order and each person picks their own dishes.

## Backend contract changes (already live in the backend)
- `result.groups[].basket` is always `[]`, `total_price` is `0`. Never show dishes, prices, totals or currency.
- `result.groups[].restaurant.link` is a Careem deep link (`careemfood://restaurants/<id>`). Each group has its own restaurant (a split gives several groups).
- `POST /rooms/{code}/order` (host only) now means "send everyone to the restaurant". It needs NO approval sheet and calls nothing external. Response:
  `{status:"go", message, groups:[{group_id, status:"go", restaurant_name, restaurant_link, message, price_breakdown:null}]}`; the room stage becomes `ordered`.
- `GET /rooms/{code}` has `order: null | {status, message, groups[...]}`, so guests also get the order/hand-off info. Use it for the guest screens.
- Per-person `why` is now one sentence addressed to the person ("You liked ...").

## Screens to change
1. **Result screen**: remove "Who gets what", every dish row, the per-group total and the grand total. Show: resolution tag, restaurant hero, rating, the group's members (avatars, crown on host), the one-sentence `reasoning`, and an expandable "Why this one" with each person's `why`. Keep the collapsible agent trace. For a split, one section per group (restaurant + members), the viewer's own group highlighted. Keep no-match and failed states as they are.
2. **Host button**: replace "Create group order" / "Approve & create group order" with **"Start group order in Careem"** (for a split: **"Send everyone to their restaurant"**). One tap, no confirmation sheet: call `POST /order`, then immediately open the host's group `restaurant_link` (`url_launcher`; if it cannot open, copy the link and show a snackbar "Link copied. Open it in the Careem app.").
3. **Ordered screen (everyone)**: title "Go to {restaurant}." Show the viewer's own group restaurant card and its members. Body text from `order.groups[].message`, with a short hint under it:
   - host: "Open the restaurant in Careem, start a group order and share it with your group."
   - guest: "{host name} starts the group order in Careem and shares it with you. Open the restaurant now and join it."
   Primary button "Open {restaurant} in Careem" (same open-or-copy behaviour), secondary "Back to Careem". Read the data from `room.order` so guests see it too (not only the host who tapped).
4. **Models**: `OrderResult` / `OrderGroupStatus` parse top-level `message` and `restaurant_name`; status values are now `go` or `failed`. Drop price-breakdown UI. `RoomResult` keeps parsing `basket`/`total_price` but nothing renders them.
5. **MockApi**: make it match: `basket: []`, `total_price: 0`, `order` response `status:"go"` with the groups above, and `room.order` filled after the host taps so a second tab (guest) shows the Ordered screen.
6. **Copy**: no emojis, plain words. Remove any text that mentions baskets, prices or "approve".
7. **Tests**: update the widget tests (result without dishes, one-tap host button, ordered screen for host and for a guest, split with two groups and two links). `flutter analyze` must stay clean.

## Keep as is
Everything up to and including the match: lobby, settings, swiping, dispute (wheel and split), matching, waiting screens, the design tokens, Reduce Motion support, routing.
