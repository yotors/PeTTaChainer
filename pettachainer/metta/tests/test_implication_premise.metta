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
