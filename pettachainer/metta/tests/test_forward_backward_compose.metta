!(import! &self petta_chainer)

!(compileadd bwdOnlyKb (: a0 (A) (STV 1.0 1.0)))

!(compileadd bwdOnlyKb (: r1 (Implication (Premises (A)) (Conclusions (B))) (STV 1.0 1.0)))

!(compileadd bwdOnlyKb (: r2 (Implication (Premises (B)) (Conclusions (Goal))) (STV 1.0 1.0)))

!(test (not (== (collapse (query 2 bwdOnlyKb (: $p (Goal) $tv))) ())) false)

!(test (not (== (collapse (query 4 bwdOnlyKb (: $p (Goal) $tv))) ())) true)

!(test
   (let (: $prf (Implication (Premises (A)) (Conclusions (Goal))) (STV 1.0 1.0))
      (superpose (collapse
                  (query 100 bwdOnlyKb (: $p (Implication (Premises (A)) (Conclusions (Goal))) $tv))))
      true)
   true)

!(compileadd transitiveClosedKb
   (: ax-tr
      (Implication
         (Premises (Provable (→ $psi $chi)) (Provable (→ $phi $psi)))
         (Conclusions (Provable (→ $phi $chi))))
      (STV 1.0 1.0)))

!(compileadd transitiveClosedKb (: given-imp1 (Provable (→ (PropP) (PropQ))) (STV 1.0 1.0)))

!(compileadd transitiveClosedKb (: given-imp2 (Provable (→ (PropQ) (PropT))) (STV 1.0 1.0)))

!(test
   (not
      (== (collapse (query 20 transitiveClosedKb (: $p (Provable (→ (PropP) (PropT))) $tv)))
         ()))
   true)

!(compileadd openImplicationKb (: r1 (Implication (Premises (A)) (Conclusions (B))) (STV 1.0 1.0)))

!(test
   (let (: (rule-proof r1 (ctx proof $_ctx))
           (Implication (Premises (A)) (Conclusions (B)))
           (STV 1.0 1.0))
      (superpose
         (collapse
            (query 100 openImplicationKb
               (: $p (Implication (Premises ($premise)) (Conclusions (B))) $tv))))
      true)
   true)

!(compileadd openHashImplicationKb (: r2 (Implication (Premises (A)) (Conclusions (C))) (STV 1.0 0.5)))

!(compileadd openHashImplicationKb (: r3 (Implication (Premises (C)) (Conclusions (B))) (STV 1.0 0.5)))

!(test
   (not
      (== (collapse
            (query 100 openHashImplicationKb
               (: $p (Implication (Premises (#)) (Conclusions (B))) $tv)))
         ()))
   true)

!(compileadd openHashPatternImplicationKb
   (: featureRule (Implication (Premises (Feature a)) (Conclusions (Target))) (STV 1.0 0.5)))

!(test
   (let (: (rule-proof featureRule (ctx proof $_ctx))
           (Implication (Premises (Feature #)) (Conclusions (Target)))
           (STV 1.0 0.5))
      (superpose
         (collapse
            (query 100 openHashPatternImplicationKb
               (: $p (Implication (Premises (Feature #)) (Conclusions (Target))) $tv))))
      true)
   true)

!(compileadd openVariableConclusionImplicationKb (: tallAlice (Tall alice) (STV 0.9 0.5)))

!(compileadd openVariableConclusionImplicationKb (: femaleAlice (Female alice) (STV 0.9 0.5)))

!(compileadd openVariableConclusionImplicationKb (: tallMary (Tall mary) (STV 0.9 0.5)))

!(compileadd openVariableConclusionImplicationKb (: femaleMary (Female mary) (STV 0.9 0.5)))

!(compileadd openVariableConclusionImplicationKb
   (: copyPredicate
      (Implication
         (Premises (And ($p1 $x) ($p2 $x)) ($p1 $y))
         (Conclusions ($p2 $y)))
      (STV 1.0 1.0)))

!(test
   (not
      (==
         (collapse
            (let (: (rule-proof copyPredicate
                       (rule-proof conjunction
                          (ctx proof $_ctx)
                          (rule-proof disjunction $_left $_right)))
                    (Implication (Premises (Tall $x)) (Conclusions (Female $x)))
                    (STV 0.9639 0.48195))
               (superpose
                  (collapse
                     (query 100 openVariableConclusionImplicationKb
                        (: $p (Implication (Premises (Tall $x)) (Conclusions (Female $x))) $tv))))
               true))
         ()))
   true)

!(test
   (length
      (collapse
         (query 100 openVariableConclusionImplicationKb
            (: $p (Implication (Premises (Tall $x)) (Conclusions (Female $x))) $tv))))
   1)

!(test
   (not
      (==
         (collapse
            (let (: (ctx proof $_ctx)
                    (Implication (Premises ($p $x)) (Conclusions ($p $x)))
                    (STV 1.0 1.0))
               (superpose
                  (collapse
                     (query 100 openVariableConclusionImplicationKb
                        (: $proof (Implication (Premises ($p1 $x)) (Conclusions ($p2 $x))) $tv))))
               true))
         ()))
   true)

!(test
   (not
      (==
         (collapse
            (let (: $_proof
                    (Implication (Premises (Female $x)) (Conclusions (Tall $x)))
                    (STV 0.9639 0.48195))
               (superpose
                  (collapse
                     (query 100 openVariableConclusionImplicationKb
                        (: $proof (Implication (Premises ($p1 $x)) (Conclusions ($p2 $x))) $tv))))
               true))
         ()))
   true)

!(compileadd existentialDisjunctionKb (: pa (P a) (STV 0.8 0.5)))

!(compileadd existentialDisjunctionKb (: pb (P b) (STV 0.6 0.7)))

!(compileadd existentialDisjunctionKb
   (: pToT (Implication (Premises (P $x)) (Conclusions (T))) (STV 1.0 1.0)))

!(test
   (collapse (query 100 existentialDisjunctionKb (: $prf (T) $tv)))
   ((: (rule-proof pToT (rule-proof disjunction pa pb)) (T) (STV 0.9199999999999999 0.45999999999999996))))

!(compileadd composeKb (: a0 (A) (STV 1.0 1.0)))

!(compileadd composeKb (: r1 (Implication (Premises (A)) (Conclusions (B))) (STV 1.0 1.0)))

!(compileadd composeKb (: r2 (Implication (Premises (B)) (Conclusions (Goal))) (STV 1.0 1.0)))

!(test (let $_ (forward-chain 1 composeKb) (not (== (collapse (query 2 composeKb (: $p (Goal) $tv))) ())))
   true)

!(compileadd composeKbShort (: a0 (A) (STV 1.0 1.0)))

!(compileadd composeKbShort (: r1 (Implication (Premises (A)) (Conclusions (B))) (STV 1.0 1.0)))

!(compileadd composeKbShort (: r2 (Implication (Premises (B)) (Conclusions (Goal))) (STV 1.0 1.0)))

!(test
   (let $_ (forward-chain 1 composeKbShort)
      (not (== (collapse (query 1 composeKbShort (: $p (Goal) $tv))) ())))
   false)

!(compileadd noReuseKb (: x (X) (STV 1.0 1.0)))

!(compileadd noReuseKb (: ra (Implication (Premises (X)) (Conclusions (A))) (STV 1.0 1.0)))

!(compileadd noReuseKb (: rb (Implication (Premises (X)) (Conclusions (B))) (STV 1.0 1.0)))

!(compileadd noReuseKb (: rc (Implication (Premises (A) (B)) (Conclusions (C))) (STV 1.0 1.0)))

!(test (== (collapse (query 100 noReuseKb (: $p (C) $tv))) ()) true)

!(compileadd independentKb (: x (X) (STV 1.0 1.0)))

!(compileadd independentKb (: b (B) (STV 1.0 1.0)))

!(compileadd independentKb (: ra (Implication (Premises (X)) (Conclusions (A))) (STV 1.0 1.0)))

!(compileadd independentKb (: rc (Implication (Premises (A) (B)) (Conclusions (C))) (STV 1.0 1.0)))

!(test (not (== (collapse (query 100 independentKb (: $p (C) $tv))) ())) true)

!(compileadd derivedAndRuleKb (: yearsRule (Implication (Premises (YearsExp $p 10)) (Conclusions (IndustryVeteran $p))) (STV 1.0 1.0)))

!(compileadd derivedAndRuleKb (: expertRule (Implication (Premises (And (IndustryVeteran $p) (ManagedTeam $p))) (Conclusions (Expert $p))) (STV 1.0 0.95)))

!(compileadd derivedAndRuleKb (: seniorRule (Implication (Premises (And (Expert $p) (CertifiedEthical $p))) (Conclusions (SeniorExpert $p))) (STV 1.0 1.0)))

!(compileadd derivedAndRuleKb (: yearsFact (YearsExp kebede 10) (STV 1.0 1.0)))

!(compileadd derivedAndRuleKb (: mgmtFact (ManagedTeam kebede) (STV 1.0 1.0)))

!(compileadd derivedAndRuleKb (: ethicsFact (CertifiedEthical kebede) (STV 1.0 1.0)))

!(test
   (not (== (collapse (query 50 derivedAndRuleKb (: $p (Expert kebede) $tv))) ()))
   true)

!(test
   (not (== (collapse (query 50 derivedAndRuleKb (: $p (SeniorExpert kebede) $tv))) ()))
   true)
