import unittest

from pettachainer import PeTTaChainer


class TestPeTTaChainer(unittest.TestCase):
    def test_forward_chain_derives_fact_visible_to_backward_query(self):
        handler = PeTTaChainer()
        handler.add_atom("(: edge_ab (Edge A B) (STV 1.0 1.0))")
        handler.add_atom("(: edge_bc (Edge B C) (STV 1.0 1.0))")
        handler.add_atom(
            "(: edge_to_path (Implication (Premises (Edge $x $y)) (Conclusions (Path $x $y))) (STV 1.0 1.0))"
        )
        handler.add_atom(
            "(: path_step (Implication (Premises (Path $x $y) (Edge $y $z)) (Conclusions (Path $x $z))) (STV 1.0 1.0))"
        )

        result = handler.forward_chain(steps=50)

        self.assertIn("true", str(result))
        proofs = handler.query("(: $prf (Path A C) $tv)", steps=10, timeout_sec=0)
        self.assertTrue(proofs)

    def test_forward_chain_can_start_from_selected_term(self):
        handler = PeTTaChainer()
        handler.add_atom("(: high_fact (HighPriority) (STV 1.0 1.0))")
        handler.add_atom("(: low_fact (LowPriority) (STV 1.0 0.8))")
        handler.add_atom(
            "(: low_to_goal (Implication (Premises (LowPriority)) (Conclusions (DeltaGoal))) (STV 1.0 1.0))"
        )

        result = handler.forward_chain(steps=1, term="(LowPriority)")

        self.assertIn("true", str(result))
        proofs = handler.query("(: $prf (DeltaGoal) $tv)", steps=10, timeout_sec=0)
        self.assertTrue(proofs)


if __name__ == "__main__":
    unittest.main()
