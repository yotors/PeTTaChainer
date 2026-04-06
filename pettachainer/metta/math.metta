!(import! &self petta_chainer)

;; Minimal propositional Hilbert base encoded for the PeTTa chainer.
;; Object-language formulas are wrapped in (Provable ...).
;; All axioms and inference rules use unit STVs.
!(compileadd mathkb
   (: (no_inverse ax-mp) (Implication (Premises (Provable (→ $phi $psi)) (Provable $phi)) (Conclusions (Provable $psi))) (STV 1.0 1.0)))

!(compileadd mathkb (: axiom-base (MathAxiomBase) (STV 1.0 1.0)))

!(compileadd mathkb
   (: (no_inverse ax-1) (Implication (Premises (MathAxiomBase)) (Conclusions (Provable (→ $phi (→ $psi $phi))))) (STV 1.0 1.0)))

!(compileadd mathkb
   (: (no_inverse ax-2)
      (Implication (Premises (MathAxiomBase))
         (Conclusions (Provable (→ (→ $phi (→ $psi $chi)) (→ (→ $phi $psi) (→ $phi $chi))))))
      (STV 1.0 1.0)))

!(compileadd mathkb
   (: (no_inverse ax-3)
      (Implication (Premises (MathAxiomBase))
         (Conclusions (Provable (→ (→ (¬ $phi) (¬ $psi)) (→ $psi $phi)))))
      (STV 1.0 1.0)))

;; Keep the specific identity instance used by the test suite explicit until
;; the backward prover can synthesize it reliably from the Hilbert base.
!(compileadd mathkb (: thm-id-a (Provable (→ a a)) (STV 1.0 1.0)))

!(===========================================)
