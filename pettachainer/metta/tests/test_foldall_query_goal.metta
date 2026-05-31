!(import! &self petta_chainer)

!(compileadd kb (: prfA (Score A 1) (STV 1.0 1.0)))
!(compileadd kb (: prfB (Score B 2) (STV 1.0 1.0)))
!(compileadd kb (: prfC (Score C 3) (STV 1.0 1.0)))

!(compileadd kb (: sampleA (XYZSample (Pair (XY 10.0 100.0) 20.0)) (STV 1.0 1.0)))
!(compileadd kb (: sampleB (XYZSample (Pair (XY 10.0 100.0) 21.0)) (STV 1.0 1.0)))
!(compileadd kb (: seed1 (Seed (Pair alpha 1)) (STV 1.0 1.0)))
!(compileadd kb (: seed2 (Seed (Pair beta 2)) (STV 1.0 1.0)))
!(compileadd kb
   (: seedRule
      (Implication
         (Premises (Seed $p))
         (Conclusions (PairFact $p)))
      (STV 1.0 1.0)))

!(test
   (collapse
      (query 30 kb
         (: $prf
            (FoldAll (Score $name $n) $n 0 (|-> ($acc $elem) (+ $acc $elem)) -> $total)
            $tv)))
   ((: (rule-proof foldall prfA prfB prfC) (FoldAll (Score $_name $_n) $_n 0 lambda_20 -> 6) (STV 1.0 1.0))))

!(test
   (collapse
      (query 30 kb
         (: $prf
            (FoldAll (XYZSample (Pair $xy $z))
               (Pair $xy $z)
               (PairCounts ())
               DistValueCountAcc
               ->
               $counts)
            $tv)))
   ((: (rule-proof foldall sampleA sampleB)
       (FoldAll (XYZSample (Pair $_xy $_z)) (Pair $_xy $_z) (PairCounts ()) DistValueCountAcc -> (PairCounts (((Pair (XY 10.0 100.0) 20.0) 1.0) ((Pair (XY 10.0 100.0) 21.0) 1.0))))
       (STV 1.0 1.0))))

!(test
   (collapse
      (query 30 kb
         (: $prf
            (FoldAll (PairFact $p)
               $p
               (PairCounts ())
               DistValueCountAcc
               ->
               $counts)
            $tv)))
   ((: (rule-proof foldall (rule-proof seedRule seed2) (rule-proof seedRule seed1))
       (FoldAll (PairFact $_p) $_p (PairCounts ()) DistValueCountAcc -> (PairCounts (((Pair beta 2) 1.0) ((Pair alpha 1) 1.0))))
       (STV 1.0 1.0))))
