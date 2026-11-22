"""Scoring: utility, fairness, veto, history, empty list."""
import scoring
from catalog import Catalog, load_cache
from scoring import Signals

CAT = Catalog(load_cache(), "cache")
SHAWARMA = CAT.by_id(30101)
PIZZA = CAT.by_id(30103)
SUSHI = CAT.by_id(30102)


def sig(pids, **kw):
    return Signals(participant_ids=pids, **kw)


def test_quality_range_and_defaults():
    assert scoring.quality(5.0, 0) == 1.0
    assert scoring.quality(3.5, 60) == 0.0
    assert 0 < scoring.quality(None, None) < 1


def test_utility_formula():
    s = sig(["a"], swipe_r={"a": {30101: 1}}, swipe_c={"a": {"Shawarma": 1}}, hist_r={"a": {30101: 1.0}})
    u = scoring.utility(s, "a", 30101, "Shawarma", 4.0, 30)
    q = scoring.quality(4.0, 30)
    assert abs(u - (0.5 + 0.2 + 0.2 + 0.1 * q)) < 1e-9


def test_category_history_counts_less_than_same_restaurant():
    same = sig(["a"], hist_r={"a": {30101: 1.0}})
    kind = sig(["a"], hist_c={"a": {"Shawarma": 1.0}})
    assert scoring.utility(same, "a", 30101, "Shawarma", 4, 30) > scoring.utility(kind, "a", 30101, "Shawarma", 4, 30)


def test_fairness_penalises_a_split_group():
    # same mean utility, but one restaurant divides the group
    assert scoring.group_utility([0.5, 0.5]) > scoring.group_utility([1.0, 0.0])
    assert scoring.group_utility([]) == 0.0


def test_unanimous_beats_polarising():
    s = sig(["a", "b", "c"],
            swipe_r={"a": {30101: 1, 30103: 1}, "b": {30101: 1, 30103: -1}, "c": {30101: 1, 30103: -1}})
    ranked = scoring.rank([SHAWARMA, PIZZA], s)
    assert ranked[0].restaurant.id == 30101
    assert ranked[0].likes == 3 and ranked[1].likes == 1


def test_veto_needs_both_restaurant_and_category_skip():
    s = sig(["a", "b"], swipe_r={"a": {30101: -1}, "b": {30101: 1}}, swipe_c={"a": {"Shawarma": -1}, "b": {"Shawarma": 1}})
    assert scoring.rank([SHAWARMA], s)[0].vetoed_by == ["a"]
    s2 = sig(["a", "b"], swipe_r={"a": {30101: -1}, "b": {30101: 1}}, swipe_c={"a": {"Shawarma": 1}, "b": {"Shawarma": 1}})
    assert scoring.rank([SHAWARMA], s2)[0].vetoed_by == []


def test_history_breaks_a_tie():
    s = sig(["a", "b"],
            swipe_r={"a": {30101: 1, 30103: 1}, "b": {30101: 1, 30103: 1}},
            swipe_c={"a": {"Shawarma": 1, "Pizza": 1}, "b": {"Shawarma": 1, "Pizza": 1}},
            hist_r={"a": {30103: 1.0}, "b": {30103: 0.8}})
    ranked = scoring.rank([SHAWARMA, PIZZA], s)
    # Shawarma has the better rating, so without history it would win; history flips it
    no_hist = sig(["a", "b"], swipe_r=s.swipe_r, swipe_c=s.swipe_c)
    assert scoring.rank([SHAWARMA, PIZZA], no_hist)[0].restaurant.id == 30101
    assert ranked[0].restaurant.id == 30103


def test_shortlist_skips_vetoed_and_flags_compromise():
    s = sig(["a", "b"],
            swipe_r={"a": {30101: -1, 30103: 1}, "b": {30101: 1, 30103: 1}},
            swipe_c={"a": {"Shawarma": -1, "Pizza": 1}, "b": {"Shawarma": 1, "Pizza": 1}})
    short, comp = scoring.shortlist(scoring.rank([SHAWARMA, PIZZA, SUSHI], s))
    assert 30101 not in [r.restaurant.id for r in short] and comp is False
    # everyone vetoed -> relax
    allveto = sig(["a"], swipe_r={"a": {30101: -1}}, swipe_c={"a": {"Shawarma": -1}})
    short, comp = scoring.shortlist(scoring.rank([SHAWARMA], allveto))
    assert [r.restaurant.id for r in short] == [30101] and comp is True


def test_empty_list():
    assert scoring.rank([], sig(["a"])) == []
    assert scoring.shortlist([]) == ([], True)
    assert scoring.public_scores([]) == []
