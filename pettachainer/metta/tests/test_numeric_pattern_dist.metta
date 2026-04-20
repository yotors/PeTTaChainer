!(import! &self petta_chainer)

!(compileadd kb (: fx1 (AtTime (FeatureX 10.0) 1) (STV 1.0 0.9)))
!(compileadd kb (: fy1 (AtTime (FeatureY 100.0) 1) (STV 1.0 0.9)))
!(compileadd kb (: fz2 (AtTime (FeatureZ 20.0) 2) (STV 1.0 0.9)))

!(compileadd kb (: fx3 (AtTime (FeatureX 10.0) 3) (STV 1.0 0.9)))
!(compileadd kb (: fy3 (AtTime (FeatureY 100.0) 3) (STV 1.0 0.9)))
!(compileadd kb (: fz4 (AtTime (FeatureZ 21.0) 4) (STV 1.0 0.9)))

!(compileadd kb (: fx5 (AtTime (FeatureX 10.0) 5) (STV 1.0 0.9)))
!(compileadd kb (: fy5 (AtTime (FeatureY 100.0) 5) (STV 1.0 0.9)))
!(compileadd kb (: fz6 (AtTime (FeatureZ 19.0) 6) (STV 1.0 0.9)))

!(compileadd kb (: fx7 (AtTime (FeatureX 10.0) 7) (STV 1.0 0.9)))
!(compileadd kb (: fy7 (AtTime (FeatureY 2.0) 7) (STV 1.0 0.9)))
!(compileadd kb (: fz8 (AtTime (FeatureZ 49.0) 8) (STV 1.0 0.9)))

!(compileadd kb
   (: sampleRule
      (Implication
         (Premises
            (AtTime (FeatureX $xv) $t)
            (AtTime (FeatureY $yv) $t)
            (Compute + ($t 1) -> $t1)
            (AtTime (FeatureZ $zv) $t1))
         (Conclusions (XYZSample (Pair (XY $xv $yv) $zv))))
      (STV 1.0 1.0)))

!(test
   (fold-flat (|-> ($acc $_item) (+ $acc 1)) 0 (collapse (query 100 kb (: $prf (XYZSample $sample) $tv))))
   4)

!(test (struct-distance2 (XY 10.0 100.0) (XY 10.0 100.0)) 0.0)

!(test (car-atom (collapse (struct-distance2 (XY 10.0 100.0) (XY 10.0 2.0)))) 9604.0)

!(test
   (ParticlePairs (DistMap2Formula XY (PointMass 10.0) (PointMass 2.0)))
   (((XY 10.0 2.0) 1.0)))

!(test
   (joint-cond-add-sample (XY 10.0 100.0) 1.0 (Pair (XY 10.0 100.0) 20.0) 1.0 5.0 ())
   ((20.0 1.0)))
