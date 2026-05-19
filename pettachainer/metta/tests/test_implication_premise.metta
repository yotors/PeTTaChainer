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
