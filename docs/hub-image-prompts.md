# Hub image prompts (for Nano Banana)

Drop files into `app/assets/hub/` using the exact file names below (PNG). Anything missing
shows a grey icon placeholder, so you can add them one at a time.

## Rules for every image
- Transparent background if possible. If not, **pure white (#FFFFFF) background, nothing else**
  (the background gets cut out afterwards).
- No text, no logos, no brand names, no watermarks.
- Same style across all of them (copy the STYLE line into every prompt).

**STYLE:** glossy 3D-rendered icon, soft studio lighting, smooth plastic and matte materials,
rounded friendly shapes, slight top-down three-quarter view, centered with a little empty margin,
soft contact shadow, clean and modern, consistent with a premium super-app.

## Tiles (square, 1024x1024)
| File | Prompt subject |
| --- | --- |
| `rides.png` | a sleek black four-door electric sedan, front three-quarter view |
| `food.png` | a cheeseburger next to a green takeaway drink cup with a straw |
| `quik.png` | a green shopping basket filled with fresh groceries (milk, bread, apples, greens) |
| `pay.png` | a single large gold coin with an embossed rounded symbol on its face |
| `flowers.png` | a bouquet of purple and white flowers wrapped in paper |
| `hala_taxi.png` | a white and light-blue city taxi with a roof sign, front three-quarter view |
| `box.png` | a green delivery scooter carrying a large green cube-shaped delivery box |
| `electronics.png` | over-ear headphones, a smartphone and a game controller grouped together |
| `home_spa.png` | a washing machine with a mop and a spray bottle beside it |
| `match.png` | two overlapping speech bubbles, one holding a heart and one holding a fork and knife, warm green and cream colors (our feature) |

## Small icon (square, 512x512)
| File | Prompt subject |
| --- | --- |
| `salik.png` | a small road toll tag sticker with a green and white sign |

## Banners
| File | Size | Prompt subject |
| --- | --- | --- |
| `banner_taxis.png` | 800x800 | two white and light-blue taxis stacked diagonally, one behind the other, on a **solid dark green (#123F34)** background, no text |
| `match_banner.png` | 800x1040 (portrait) | a smartphone showing a stack of food cards being swiped, with a heart and a cross floating beside it, cream background (#F7F4EE), no text on the screen |
| `promo_bags.png` | 1024x1024 | two paper grocery bags, one green and one dark green, with a small tag hanging off one handle, no logo |

## Product shots (square, 1024x1024, cream background #F7F4EE is fine)
| File | Prompt subject |
| --- | --- |
| `product_blueberries.png` | a clear plastic punnet of fresh blueberries, plain label with no text |
| `product_bananas.png` | a bunch of ripe yellow bananas |
| `product_tissues.png` | a blue box of facial tissues with one tissue pulled out, no text |

## Prompt template
```
<STYLE>. Subject: <subject from the table>. Transparent background (or pure white). No text, no logos.
```
