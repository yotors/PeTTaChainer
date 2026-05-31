!(import! &self petta_chainer)

!(compileadd materializeKb (: a0 (A) (STV 1.0 1.0)))

!(compileadd materializeKb (: r1 (Implication (Premises (A)) (Conclusions (B))) (STV 1.0 1.0)))

!(compileadd materializeKb (: r2 (Implication (Premises (B)) (Conclusions (Goal))) (STV 1.0 1.0)))

!(test
   (not (== (collapse (query 4 materializeKb (: $p (Goal) $tv))) ()))
   true)

!(test
   (collapse (match &kb ((B) (materializeKb MAIN Nil) $_prf $_tv) true))
   ())

!(test
   (collapse (match &kb ((Goal) (materializeKb MAIN Nil) $_prf $_tv) true))
   ())

!(test
   (not (== (collapse (query-materialize 4 materializeKb (: $p (Goal) $tv))) ()))
   true)

!(test
   (not (== (collapse (match &kb ((B) (materializeKb MAIN Nil) $_prf $_tv) true)) ()))
   true)

!(test
   (not (== (collapse (match &kb ((Goal) (materializeKb MAIN Nil) $_prf $_tv) true)) ()))
   true)

!(test
   (not (== (collapse (query 1 materializeKb (: $p (B) $tv))) ()))
   true)

!(test
   (not (== (collapse (query 1 materializeKb (: $p (Goal) $tv))) ()))
   true)
