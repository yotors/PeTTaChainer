!(import! &self petta_chainer)

!(compileadd plnLogicKb (: a (A) (STV 1.0 1.0)))

!(test
   (== (collapse (query 20 plnLogicKb (: $prf (Or (A) (B)) $tv))) ())
   true)

!(import! &self logic_configs/predicate_logic)

!(compileadd predicateLogicKb (: a (A) (STV 1.0 1.0)))

!(test
   (not (== (collapse (query 20 predicateLogicKb (: $prf (Or (A) (B)) $tv))) ()))
   true)

!(import! &self logic_configs/pln)

!(compileadd plnAfterSwitchKb (: a (A) (STV 1.0 1.0)))

!(test
   (== (collapse (query 20 plnAfterSwitchKb (: $prf (Or (A) (B)) $tv))) ())
   true)

!(clear-logic-config)
!(set-logic-name CustomLogic)
!(set-compound-connective Either Any NoProjection)

!(compileadd customEitherKb (: a (A) (STV 1.0 1.0)))

!(test
   (not (== (collapse (query 20 customEitherKb (: $prf (Either (A) (B)) $tv))) ()))
   true)

!(clear-logic-config)
!(set-logic-name NoOrLogic)
!(set-compound-connective And All ProjectAll)

!(compileadd noOrKb (: a (A) (STV 1.0 1.0)))

!(test
   (== (collapse (query 20 noOrKb (: $prf (Or (A) (B)) $tv))) ())
   true)

!(import! &self logic_configs/pln)
