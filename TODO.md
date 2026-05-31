# TODO

- Add an additive merge mode for complementary evidence sets. In cases like `Dog -> Animal` and `Not Dog -> Animal`, the two proofs are split parts of one conditional formula, not independent estimates. If one proof uses `(fact-ev ... d (Dog))` and the other uses `(not-fact-ev ... d (Dog))`, combine the MP-produced strengths additively instead of using `merge/revision` averaging. Also decide how zero-confidence branches should be scheduled once this merge mode exists.
