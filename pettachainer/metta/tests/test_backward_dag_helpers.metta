!(import! &self petta_chainer)

!(test (tv-confidence (STV 0.7 0.35)) 0.35)

!(test (tv-confidence maybeUnknown) 1.0)

!(test (term-confidence (CPU MpFormula ((STV 1.0 0.6) (STV 0.8 0.9)) $out)) 0.54)

!(test (term-confidence (CPU AndFormula ((STV 0.8 0.4) (STV 0.9 0.7)) $out)) 0.4)

!(test (term-confidence (CPU OrFormula ((STV 0.8 0.4) (STV 0.9 0.7)) $out)) 0.7)

!(test (term-confidence (CPU LikelierThanFormula ((STV 0.8 0.4) (STV 0.9 0.7)) $out)) 0.4)

!(test (term-confidence (CPU InversionFormula ($a $b (STV 0.8 0.632121)) $out)) 0.5689089)

!(test
   (premises-expected-confidence
      (cons (CPU MpFormula ((STV 1.0 0.2) (STV 1.0 1.0)) $tv1)
         (cons (CPU MpFormula ((STV 1.0 0.55) $tv1) $tv2) ())))
   0.18000000000000002)

!(test
   (premises-expected-confidence
      (cons ((Animal #) (kb MAIN Nil) $prfA $tvA)
         (cons ((Creature #) (kb MAIN Nil) $prfB $tvB)
            (cons (CPU InversionFormula ($tvA $tvB (STV 0.8 0.632121)) $iitv)
               (cons ((Creature #) (kb MAIN Nil) $prfC $tvB) (cons (CPU MpFormula ($iitv $tvB) $tvA) ()))))))
   0.5689089)

(= (clear-backward-state)
   (progn
      (foreach-flat remove-all-atoms (() &goal &goal_lookup &goal_waiter &aggregate &proof &proof_live_cache &goal_live_cache))
      (change-state! bwd_live_epoch 0)
      ()))

!(test
   (let*
      (($_clear (clear-backward-state))
        ($_gidreset (change-state! bwd_gid 0))
        ($_pidreset (change-state! bwd_pid 0))
        ($gid (ensure-goal-at-depth ((Goal) (kb MAIN ()) $prf (STV 1.0 1.0)) 0))
        ($pid
           (store-proof-candidate $gid
              (proof-candidate (leaf ((Goal) (kb MAIN ()) factA (STV 1.0 0.8)))
                 0.8
                 ((fact-ev (kb MAIN ()) factA (Goal)))
                 ()))))
      (proof-term-evidence-list (proof-ref $pid)))
   ((fact-ev (kb MAIN ()) factA (Goal))))

!(test
   (let*
      (($_clear (clear-backward-state))
        ($_gidreset (change-state! bwd_gid 0))
        ($_pidreset (change-state! bwd_pid 0))
        ($gid (ensure-goal-at-depth ((Goal) (kb MAIN ()) $prf (STV 1.0 1.0)) 0))
        ($pid-a
           (store-proof-candidate $gid
              (proof-candidate (leaf ((Goal) (kb MAIN ()) (bench-base-fact demo 1 1) (STV 1.0 0.8)))
                 0.8
                 ((fact-ev (kb MAIN ()) (bench-base-fact demo 1 1) (Goal)))
                 ())))
        ($pid-b
           (store-proof-candidate $gid
              (proof-candidate (leaf ((Goal) (kb MAIN ()) (bench-base-fact demo 1 2) (STV 1.0 0.7)))
                 0.7
                 ((fact-ev (kb MAIN ()) (bench-base-fact demo 1 2) (Goal)))
                 ()))))
      (evidence-sets-overlap? (snd (proof-stats-by-id $pid-a)) (snd (proof-stats-by-id $pid-b))))
   false)

!(test
   (let*
      (($_clear (clear-backward-state))
        ($_gidreset (change-state! bwd_gid 0))
        ($_pidreset (change-state! bwd_pid 0))
        ($gid (ensure-goal-at-depth ((Goal) (kb MAIN ()) $prf (STV 1.0 1.0)) 0))
        ($pid
           (store-proof-candidate $gid
              (proof-candidate (leaf ((Goal) (kb MAIN ()) factA (STV 1.0 0.8)))
                 0.8
                 ((fact-ev (kb MAIN ()) factA (Goal)))
                 ()))))
      (materialize-proof $pid))
   factA)

!(test (proof-term-children (custom-proof left right)) ())

!(test (proof-term-evidence-list (rule-proof own_have (fact-ev (kb MAIN ()) i_have_max (Have (i max)))))
   ((fact-ev (kb MAIN ()) i_have_max (Have (i max)))))

!(test
   (let*
      (($_clear (clear-backward-state))
        ($_gidreset (change-state! bwd_gid 0))
        ($_pidreset (change-state! bwd_pid 0))
        ($agg-gid (ensure-goal-at-depth (CPU FoldAllCompiled dummy-agg-args $out) 0))
        ($child-gid (ensure-goal-at-depth ((Child) (kb MAIN ()) $prf (STV 1.0 1.0)) 1))
        ($pid-old
           (store-proof-candidate $agg-gid
              (leaf-result-candidate (CPU FoldAllCompiled dummy-agg-args 1) ())))
        ($_agg1 (add-atom &aggregate ($agg-gid $child-gid dummy-agg-args 1.0 0.0 $pid-old)))
        ($pid-new
           (store-proof-candidate $agg-gid
              (leaf-result-candidate (CPU FoldAllCompiled dummy-agg-args 2) ())))
        ($_agg2
           (progn
              (remove-atom &aggregate ($agg-gid $child-gid dummy-agg-args 1.0 0.0 $pid-old))
              (add-atom &aggregate ($agg-gid $child-gid dummy-agg-args 1.0 0.0 $pid-new))
              (invalidate-proof-live-caches))))
      ((proof-live? $pid-old) (proof-live? $pid-new)))
   (false true))

!(test
   (let*
      (($_clear (clear-backward-state))
        ($_gidreset (change-state! bwd_gid 0))
        ($_pidreset (change-state! bwd_pid 0))
        ($agg-gid (ensure-goal-at-depth (CPU FoldAllCompiled dummy-agg-args $out) 0))
        ($child-gid (ensure-goal-at-depth ((Child) (kb MAIN ()) $prf (STV 1.0 1.0)) 1))
        ($pid-old
           (store-proof-candidate $agg-gid
              (leaf-result-candidate (CPU FoldAllCompiled dummy-agg-args 1) ())))
        ($_agg1 (add-atom &aggregate ($agg-gid $child-gid dummy-agg-args 1.0 0.0 $pid-old)))
        ($pid-new
           (store-proof-candidate $agg-gid
              (leaf-result-candidate (CPU FoldAllCompiled dummy-agg-args 2) ())))
        ($_agg2
           (progn
              (remove-atom &aggregate ($agg-gid $child-gid dummy-agg-args 1.0 0.0 $pid-old))
              (add-atom &aggregate ($agg-gid $child-gid dummy-agg-args 1.0 0.0 $pid-new))
              (invalidate-proof-live-caches))))
      (waiter-live? (frontier-waiter 99 bundle 1.0 () ($pid-old))))
   false)

!(test
   (let*
      (($_clear (clear-backward-state))
        ($_gidreset (change-state! bwd_gid 0))
        ($_pidreset (change-state! bwd_pid 0))
        ($agg-gid (ensure-goal-at-depth (CPU FoldAllCompiled dummy-agg-args $out) 0))
        ($child-gid (ensure-goal-at-depth ((Child) (kb MAIN ()) $prf (STV 1.0 1.0)) 1))
        ($pid-old
           (store-proof-candidate $agg-gid
              (leaf-result-candidate (CPU FoldAllCompiled dummy-agg-args 1) ())))
        ($_agg1 (add-atom &aggregate ($agg-gid $child-gid dummy-agg-args 1.0 0.0 $pid-old)))
        ($_prime-proof (proof-live? $pid-old))
        ($_prime-goal (goal-live-proof-ids $agg-gid))
        ($pid-new
           (store-proof-candidate $agg-gid
              (leaf-result-candidate (CPU FoldAllCompiled dummy-agg-args 2) ())))
        ($_invalidate (invalidate-proof-live-caches))
        ($_agg2
           (progn
              (remove-atom &aggregate ($agg-gid $child-gid dummy-agg-args 1.0 0.0 $pid-old))
              (add-atom &aggregate ($agg-gid $child-gid dummy-agg-args 1.0 0.0 $pid-new)))))
      ((proof-live? $pid-old) (proof-live? $pid-new) (length (goal-live-proof-ids $agg-gid))))
   (false true 1))
