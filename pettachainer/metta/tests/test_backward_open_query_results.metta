!(import! &self petta_chainer)

!(compileadd openQueryKb (: d1 (Dog max) (STV 1.0 1.0)))

!(compileadd openQueryKb (: d2 (Dog ann) (STV 1.0 1.0)))

!(compileadd openQueryKb
   (: (no_inverse dog_to_animal) (Implication (Premises (Dog $x)) (Conclusions (Animal $x))) (STV 1.0 1.0)))

!(test (collapse (query 20 openQueryKb (: $prf (Animal $a) $tv)))
   ((: (rule-proof (no_inverse dog_to_animal) d2) (Animal ann) (STV 1.0 1.0))
    (: (rule-proof (no_inverse dog_to_animal) d1) (Animal max) (STV 1.0 1.0))))

!(compileadd openTimeKb (: tx1 (AtTime (FeatureX 0) 1) (STV 1.0 0.9)))

!(compileadd openTimeKb (: ty1 (AtTime (FeatureY 0) 1) (STV 1.0 0.9)))

!(compileadd openTimeKb
   (: timeAndRule
      (Implication
         (Premises (AtTime $x $t) (AtTime $y $t))
         (Conclusions (AtTime (And $x $y) $t)))
      (STV 1.0 1.0)))

!(test
   (collapse (query 50 openTimeKb (: $prf (AtTime $f $t) $tv)))
   ((: tx1 (AtTime (FeatureX 0) 1) (STV 1.0 0.9))
    (: ty1 (AtTime (FeatureY 0) 1) (STV 1.0 0.9))
    (: (rule-proof timeAndRule (rule-proof conjunction tx1 ty1)) (AtTime (And (FeatureX 0) (FeatureY 0)) 1) (STV 1.0 0.9))
    (: (rule-proof timeAndRule (rule-proof conjunction ty1 tx1)) (AtTime (And (FeatureY 0) (FeatureX 0)) 1) (STV 1.0 0.9))))

!(compileadd openAndFairKb (: haveMax (Have (i max)) (STV 1.0 1.0)))

!(compileadd openAndFairKb (: haveAnn (Have (i ann)) (STV 1.0 1.0)))

!(compileadd openAndFairKb (: dogMax (Dog max) (STV 1.0 1.0)))

!(compileadd openAndFairKb (: dogAnn (Dog ann) (STV 1.0 1.0)))

!(compileadd openAndFairKb
   (: ownRule (Implication (Premises (Have (i $x))) (Conclusions (Own (i $x)))) (STV 0.8 1.0)))

!(compileadd openAndFairKb
   (: petRule (Implication (Premises (Dog $x)) (Conclusions (Pet $x))) (STV 0.7 1.0)))

!(compileadd openAndFairKb (: distract1 (Distract1 max) (STV 1.0 1.0)))

!(compileadd openAndFairKb (: distract2 (Distract2 max) (STV 1.0 1.0)))

!(compileadd openAndFairKb (: distract3 (Distract3 max) (STV 1.0 1.0)))

!(compileadd openAndFairKb (: distract4 (Distract4 max) (STV 1.0 1.0)))

!(compileadd openAndFairKb (: distract5 (Distract5 max) (STV 1.0 1.0)))

!(compileadd openAndFairKb (: distract6 (Distract6 max) (STV 1.0 1.0)))

!(compileadd openAndFairKb
   (: distractRule1 (Implication (Premises (Distract1 $x)) (Conclusions (Pet $x))) (STV 1.0 1.0)))

!(compileadd openAndFairKb
   (: distractRule2 (Implication (Premises (Distract2 $x)) (Conclusions (Pet $x))) (STV 1.0 1.0)))

!(compileadd openAndFairKb
   (: distractRule3 (Implication (Premises (Distract3 $x)) (Conclusions (Pet $x))) (STV 1.0 1.0)))

!(compileadd openAndFairKb
   (: distractRule4 (Implication (Premises (Distract4 $x)) (Conclusions (Pet $x))) (STV 1.0 1.0)))

!(compileadd openAndFairKb
   (: distractRule5 (Implication (Premises (Distract5 $x)) (Conclusions (Pet $x))) (STV 1.0 1.0)))

!(compileadd openAndFairKb
   (: distractRule6 (Implication (Premises (Distract6 $x)) (Conclusions (Pet $x))) (STV 1.0 1.0)))

!(test
   (collapse (query 30 openAndFairKb (: $prf (And (Own (i $a)) (Pet $a)) $tv)))
   ((: (rule-proof conjunction (rule-proof ownRule haveMax) (rule-proof distractRule6 distract6))
       (And (Own (i max)) (Pet max))
       (STV 0.8 1.0))
      (: (rule-proof conjunction (rule-proof ownRule haveMax) (rule-proof distractRule5 distract5))
         (And (Own (i max)) (Pet max))
         (STV 0.8 1.0))
      (: (rule-proof conjunction (rule-proof ownRule haveMax) (rule-proof distractRule4 distract4))
         (And (Own (i max)) (Pet max))
         (STV 0.8 1.0))
      (: (rule-proof conjunction (rule-proof ownRule haveMax) (rule-proof distractRule3 distract3))
         (And (Own (i max)) (Pet max))
         (STV 0.8 1.0))
      (: (rule-proof conjunction (rule-proof ownRule haveMax) (rule-proof distractRule2 distract2))
         (And (Own (i max)) (Pet max))
         (STV 0.8 1.0))
      (: (rule-proof conjunction (rule-proof ownRule haveMax) (rule-proof distractRule1 distract1))
         (And (Own (i max)) (Pet max))
         (STV 0.8 1.0))
      (: (rule-proof conjunction (rule-proof ownRule haveMax) (rule-proof petRule dogMax))
         (And (Own (i max)) (Pet max))
         (STV 0.5599999999999999 1.0))
      (: (rule-proof conjunction (rule-proof ownRule haveAnn) (rule-proof petRule dogAnn))
         (And (Own (i ann)) (Pet ann))
         (STV 0.5599999999999999 1.0))))
