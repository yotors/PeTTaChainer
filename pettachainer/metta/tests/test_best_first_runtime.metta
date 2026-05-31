!(import! &self petta_chainer)

!(compileadd kb (: weakFact (WeakPremise) (STV 1.0 0.1)))

!(compileadd kb (: baseFact (BasePremise) (STV 1.0 1.0)))

!(compileadd kb
   (: ruleHighThenDrop (Implication (Premises (WeakPremise) (BasePremise)) (Conclusions (SwitchGoal))) (STV 1.0 0.9)))

!(compileadd kb
   (: ruleStable (Implication (Premises (BasePremise)) (Conclusions (SwitchGoal))) (STV 1.0 0.7)))

!(test
   (let (: (rule-proof ruleStable baseFact) (SwitchGoal) (STV 1.0 0.7))
      (superpose (collapse
                  (query 10 kb (: $prf (SwitchGoal) $tv))))
      true)
   true)

!(test
   (let (: (rule-proof ruleHighThenDrop (conjunction weakFact baseFact)) (SwitchGoal) (STV 1.0 0.1))
      (superpose (collapse
                  (query 30 kb (: $prf (SwitchGoal) $tv))))
      true)
   ())

!(test (collapse (query 0 kb (: $prf (SwitchGoal) $tv))) ())

!(test (collapse (query 4 kb (: $prf (SwitchGoal) $tv)))
   ((: (rule-proof ruleStable baseFact) (SwitchGoal) (STV 1.0 0.7))))

!(test (collapse (query 7 kb (: $prf (SwitchGoal) $tv)))
   ((: (rule-proof ruleStable baseFact) (SwitchGoal) (STV 1.0 0.7))))

!(test (collapse (query 100 kb (: $prf (SwitchGoal) $tv)))
   ((: (rule-proof ruleStable baseFact) (SwitchGoal) (STV 1.0 0.7))))

!(compileadd priorityStrengthKb (: weakInput (WeakInput) (STV 0.2 1.0)))

!(compileadd priorityStrengthKb (: strongInput (StrongInput) (STV 0.8 1.0)))

!(compileadd priorityStrengthKb
   (: weakRule (Implication (Premises (WeakInput)) (Conclusions (StrengthPriorityGoal))) (STV 1.0 1.0)))

!(compileadd priorityStrengthKb
   (: strongRule (Implication (Premises (StrongInput)) (Conclusions (StrengthPriorityGoal))) (STV 1.0 1.0)))

!(test (collapse (query 2 priorityStrengthKb (: $prf (StrengthPriorityGoal) $tv))) ())

!(test (collapse (query 3 priorityStrengthKb (: $prf (StrengthPriorityGoal) $tv)))
   ((: (rule-proof strongRule strongInput) (StrengthPriorityGoal) (STV 0.8 0.8))))

!(compileadd chainedPriorityKb (: weakEvidence (WeakEvidence) (STV 0.2 1.0)))

!(compileadd chainedPriorityKb (: strongEvidence (StrongEvidence) (STV 0.8 1.0)))

!(compileadd chainedPriorityKb
   (: weakToA (Implication (Premises (WeakEvidence)) (Conclusions (AForPriority))) (STV 0.1 1.0)))

!(compileadd chainedPriorityKb
   (: strongToA (Implication (Premises (StrongEvidence)) (Conclusions (AForPriority))) (STV 1.0 1.0)))

!(compileadd chainedPriorityKb
   (: aToGoal (Implication (Premises (AForPriority)) (Conclusions (ChainedPriorityGoal))) (STV 1.0 1.0)))

!(test (collapse (query 4 chainedPriorityKb (: $prf (ChainedPriorityGoal) $tv))) ())

!(test (collapse (query 5 chainedPriorityKb (: $prf (ChainedPriorityGoal) $tv)))
   ((: (rule-proof aToGoal (rule-proof strongToA strongEvidence))
       (ChainedPriorityGoal)
       (STV 0.8 0.6400000000000001))))

!(compileadd priorityNegKb (: highInput (HighInput) (STV 0.9 1.0)))

!(compileadd priorityNegKb (: lowInput (LowInput) (STV 0.1 1.0)))

!(compileadd priorityNegKb
   (: highNegRule (Implication (Premises (Not (HighInput))) (Conclusions (NegPriorityGoal))) (STV 1.0 1.0)))

!(compileadd priorityNegKb
   (: lowNegRule (Implication (Premises (Not (LowInput))) (Conclusions (NegPriorityGoal))) (STV 1.0 1.0)))

!(test (collapse (query 3 priorityNegKb (: $prf (NegPriorityGoal) $tv))) ())

!(test (collapse (query 4 priorityNegKb (: $prf (NegPriorityGoal) $tv))) ())

!(test (collapse (query 5 priorityNegKb (: $prf (NegPriorityGoal) $tv)))
   ((: (rule-proof lowNegRule (negated lowInput)) (NegPriorityGoal) (STV 0.9 0.9))))

!(compileadd incumbentPriorityKb (: directB (IncumbentB) (STV 1.0 0.9)))

!(compileadd incumbentPriorityKb (: directA (IncumbentA) (STV 1.0 1.0)))

!(compileadd incumbentPriorityKb (: directC (IncumbentC) (STV 1.0 1.0)))

!(compileadd incumbentPriorityKb
   (: bToGoal
      (Implication (Premises (IncumbentB)) (Conclusions (IncumbentGoal)))
      (STV 1.0 0.99)))

!(compileadd incumbentPriorityKb
   (: dToGoal
      (Implication (Premises (IncumbentD)) (Conclusions (IncumbentGoal)))
      (STV 1.0 0.7)))

!(compileadd incumbentPriorityKb
   (: aToB
      (Implication (Premises (IncumbentA)) (Conclusions (IncumbentB)))
      (STV 1.0 1.0)))

!(compileadd incumbentPriorityKb
   (: cToD
      (Implication (Premises (IncumbentC)) (Conclusions (IncumbentD)))
      (STV 1.0 0.7)))

!(test (collapse (query 2 incumbentPriorityKb (: $prf (IncumbentGoal) $tv)))
   ((: (rule-proof bToGoal directB) (IncumbentGoal) (STV 1.0 0.9))))

!(test (collapse (query 6 incumbentPriorityKb (: $prf (IncumbentGoal) $tv)))
   ((: (merge/revision
          (rule-proof bToGoal directB)
          (rule-proof dToGoal (rule-proof cToD directC)))
       (IncumbentGoal)
       (STV 1.0 0.918918918918919))))

!(test
   (collapse
      (query 6 incumbentPriorityKb
         (: (merge/revision (rule-proof bToGoal (rule-proof aToB directA)) $_other)
            (IncumbentGoal)
            $tv)))
   ())
