"""Group matching scores. Pure functions, no I/O. See docs/v2-plan.md section 3.

Per person p and restaurant r:
    u_p(r) = 0.5*s_p(r) + 0.2*s_p(cat(r)) + 0.2*h_p(r) + 0.1*q(r)
      s_*  swipe: +1 like, -1 skip, 0 unseen        h_p  order-history weight 0..1       q  quality 0..1
Group utility (fair):   U(r) = mean_p u_p(r) - 0.5 * std_p u_p(r)      (penalises splitting the group)
Veto: someone skipped BOTH the restaurant and its category.
"""
from __future__ import annotations

import statistics
from dataclasses import dataclass, field

W_RESTAURANT, W_CATEGORY, W_HISTORY, W_QUALITY = 0.5, 0.2, 0.2, 0.1
FAIRNESS = 0.5
CATEGORY_HISTORY_DISCOUNT = 0.6  # having ordered the same kind of food counts a bit less than the same place


@dataclass
class Signals:
    """Everything the score needs, keyed by participant id."""
    participant_ids: list[str]
    swipe_r: dict[str, dict[int, int]] = field(default_factory=dict)  # pid -> restaurant id -> +1/-1
    swipe_c: dict[str, dict[str, int]] = field(default_factory=dict)  # pid -> category -> +1/-1
    hist_r: dict[str, dict[int, float]] = field(default_factory=dict)
    hist_c: dict[str, dict[str, float]] = field(default_factory=dict)


@dataclass
class Ranked:
    restaurant: object  # catalog.Restaurant
    per_person: dict[str, float]
    group_score: float
    likes: int
    vetoed_by: list[str]
    liked_by: list[str]


def clip(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, x))


def quality(rating: float | None, eta_minutes: int | None) -> float:
    """0..1 from rating (3.5 -> 0, 5.0 -> 1) and delivery time (0 min -> 1, 60+ min -> 0)."""
    q_rating = clip(((rating if rating is not None else 4.0) - 3.5) / 1.5)
    q_eta = clip(1 - (eta_minutes if eta_minutes is not None else 30) / 60)
    return 0.7 * q_rating + 0.3 * q_eta


def utility(sig: Signals, pid: str, rid: int, category: str, rating: float | None, eta: int | None) -> float:
    s_r = sig.swipe_r.get(pid, {}).get(rid, 0)
    s_c = sig.swipe_c.get(pid, {}).get(category, 0)
    h = max(sig.hist_r.get(pid, {}).get(rid, 0.0), CATEGORY_HISTORY_DISCOUNT * sig.hist_c.get(pid, {}).get(category, 0.0))
    return W_RESTAURANT * s_r + W_CATEGORY * s_c + W_HISTORY * h + 0.1 * quality(rating, eta)


def group_utility(values: list[float]) -> float:
    if not values:
        return 0.0
    return statistics.fmean(values) - FAIRNESS * statistics.pstdev(values)


def vetoes(sig: Signals, pid: str, rid: int, category: str) -> bool:
    return sig.swipe_r.get(pid, {}).get(rid, 0) == -1 and sig.swipe_c.get(pid, {}).get(category, 0) == -1


def rank(restaurants: list, sig: Signals) -> list[Ranked]:
    """Every restaurant scored for the whole group, best first."""
    out = []
    for r in restaurants:
        per = {pid: utility(sig, pid, r.id, r.category, r.rating, r.eta_minutes) for pid in sig.participant_ids}
        out.append(Ranked(
            restaurant=r, per_person=per, group_score=group_utility(list(per.values())),
            likes=sum(1 for pid in sig.participant_ids if sig.swipe_r.get(pid, {}).get(r.id, 0) == 1),
            vetoed_by=[pid for pid in sig.participant_ids if vetoes(sig, pid, r.id, r.category)],
            liked_by=[pid for pid in sig.participant_ids if sig.swipe_r.get(pid, {}).get(r.id, 0) == 1],
        ))
    out.sort(key=lambda x: (-x.group_score, x.restaurant.name))
    return out


def shortlist(ranked: list[Ranked], k: int = 3) -> tuple[list[Ranked], bool]:
    """Top k by group score, skipping vetoed restaurants. If the veto empties the list, relax it
    and flag the result as a compromise."""
    ok = [r for r in ranked if not r.vetoed_by]
    if ok:
        return ok[:k], False
    return ranked[:k], True


def public_scores(ranked: list[Ranked]) -> list[dict]:
    return [
        {
            "restaurant_id": r.restaurant.id, "restaurant_name": r.restaurant.name,
            "group_score": round(r.group_score, 3),
            "per_person": {pid: round(v, 3) for pid, v in r.per_person.items()},
        }
        for r in ranked
    ]
