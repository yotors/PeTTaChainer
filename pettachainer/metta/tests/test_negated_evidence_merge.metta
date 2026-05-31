!(import! &self petta_chainer)

!(test
   (evidence-negate (fact-ev (kb MAIN Nil) d (Dog)))
   (not-fact-ev (kb MAIN Nil) d (Dog)))

!(test
   (evidence-sets-overlap?
      ((fact-ev (kb MAIN Nil) d (Dog)))
      ((not-fact-ev (kb MAIN Nil) d (Dog))))
   false)

!(compileadd negEvidenceMergeKb
   (: nd_a (Implication (Premises (Not (Dog))) (Conclusions (Animal))) (STV 0.75 0.5)))

!(compileadd negEvidenceMergeKb
   (: d_a (Implication (Premises (Dog)) (Conclusions (Animal))) (STV 0.25 0.5)))

!(compileadd negEvidenceMergeKb (: d (Dog) (STV 0.5 1.0)))

!(test (collapse (query 100 negEvidenceMergeKb (: $prf (Animal) $tv)))
   ((: (rule-proof d_a d) (Animal) (STV 0.5 0.5))))

!(test (length (collapse (query 100 negEvidenceMergeKb (: $prf (Animal) $tv)))) 1)

!(compileadd totalMpFallbackKb (: d (Dog) (STV 0.5 1.0)))

!(compileadd totalMpFallbackKb
   (: d_a (Implication (Premises (Dog)) (Conclusions (Animal))) (STV 0.8 0.6)))

!(test (collapse (query 100 totalMpFallbackKb (: $prf (Animal) $tv)))
   ((: (rule-proof d_a d) (Animal) (STV 0.4 0.3))))

!(compileadd totalMpNegOnlyKb (: d (Dog) (STV 0.5 1.0)))

!(compileadd totalMpNegOnlyKb
   (: nd_a (Implication (Premises (Not (Dog))) (Conclusions (Animal))) (STV 0.8 0.6)))

!(test (collapse (query 100 totalMpNegOnlyKb (: $prf (Animal) $tv)))
   ((: (rule-proof nd_a (negated d)) (Animal) (STV 0.4 0.3))))
