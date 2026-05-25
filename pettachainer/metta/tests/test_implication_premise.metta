!(import! &self petta_chainer)

!(compileadd implicationPremiseKb
   (: ab_c
      (Implication
         (Premises
            (Implication (Premises (A)) (Conclusions (B))))
         (Conclusions
            (C)))
      (STV 1.0 1.0)))

!(compileadd implicationPremiseKb
   (: a_b
      (Implication
         (Premises
            (A))
         (Conclusions
            (B)))
      (STV 1.0 1.0)))

!(test
   (not
      (== (collapse
            (query 60 implicationPremiseKb
               (: $prf (Implication (Premises (A)) (Conclusions (B))) $tv)))
         ()))
   true)

!(test
   (not
      (== (collapse
            (query 60 implicationPremiseKb (: $prf (C) $tv)))
         ()))
   true)

!(compileadd multiPremiseImplicationQueryKb
   (: ab_c
      (Implication
         (Premises
            (A)
            (B))
         (Conclusions
            (C)))
      (STV 1.0 1.0)))

!(test
   (let (: (rule-proof ab_c (rule-proof conjunction (ctx proof $_ctx) (ctx proof $_ctx 1)))
           (Implication (Premises (A) (B)) (Conclusions (C)))
           (STV 1.0 0.9))
      (superpose
         (collapse
            (query 60 multiPremiseImplicationQueryKb
               (: $prf (Implication (Premises (A) (B)) (Conclusions (C))) $tv))))
      true)
   true)

!(test
   (not
      (== (collapse
            (query 60 implicationPremiseKb
               (: $prf
                  (Implication
                     (Premises
                        (Implication (Premises (A)) (Conclusions (B)))
                        (A))
                     (Conclusions (B)))
                  $tv)))
         ()))
   true)

!(set-context-polymorphic-facts kbRelativeImplicationQueryKb true)

!(compileadd kbRelativeImplicationQueryKb (: b (B) (STV 1.0 1.0)))

!(compileadd kbRelativeImplicationQueryKb
   (: ab_c
      (Implication
         (Premises
            (A)
            (B))
         (Conclusions
            (C)))
      (STV 1.0 1.0)))

!(test
   (not
      (== (collapse
            (query 60 kbRelativeImplicationQueryKb
               (: $prf (Implication (Premises (A)) (Conclusions (C))) $tv)))
         ()))
   true)

!(test
   (not
      (== (collapse
            (query 10 kbRelativeImplicationQueryKb (: $prf (B) $tv)))
         ()))
   true)

!(compileadd (contextualFactsKb LOCAL Nil) (: local-fact (LocalFact) (STV 1.0 1.0)))

!(test
   (== (collapse
         (query 10 contextualFactsKb (: $prf (LocalFact) $tv)))
      ())
   true)

!(test
   (not
      (== (collapse
            (query 10 (contextualFactsKb LOCAL Nil) (: $prf (LocalFact) $tv)))
         ()))
   true)

!(compileadd biImplicationKb (: a (A) (STV 1.0 1.0)))

!(compileadd biImplicationKb
   (: a_iff_b
      (BiImplication
         (Premises (A))
         (Conclusions (B)))
      (STV 1.0 1.0)))

!(test
   (not
      (== (collapse
            (query 30 biImplicationKb (: $prf (B) $tv)))
         ()))
   true)

!(compileadd biImplicationKb (: b (B2) (STV 1.0 1.0)))

!(compileadd biImplicationKb
   (: a2_iff_b2
      (BiImplication
         (Premises (A2))
         (Conclusions (B2)))
      (STV 1.0 1.0)))

!(test
   (not
      (== (collapse
            (query 30 biImplicationKb (: $prf (A2) $tv)))
         ()))
   true)

!(test
   (not
      (== (collapse
            (query 60 biImplicationKb
               (: $prf
                  (BiImplication
                     (Premises (A))
                     (Conclusions (B)))
                  $tv)))
         ()))
   true)
