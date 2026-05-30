!(import! &self petta_chainer)

!(test (tv-confidence (STV 0.7 0.35)) 0.35)

!(test (tv-confidence maybeUnknown) 1.0)

!(test (term-confidence (CPU MpFormula ((STV 1.0 0.6) (STV 0.8 0.9)) $out)) 0.48)

!(test (MpFormula (STV 1.0 0.6) (STV 0.0 1.0)) (STV 0.0 0.0))

!(test (term-confidence (CPU NotFormula ((STV 0.75 0.6)) $out)) 0.6)

!(test (term-confidence (CPU AndFormula ((STV 0.8 0.4) (STV 0.9 0.7)) $out)) 0.4)

!(test (term-confidence (CPU OrFormula ((STV 0.8 0.4) (STV 0.9 0.7)) $out)) 0.4)

!(test (OrProjection (STV 0.75 0.9) (STV 0.5 1.0)) (STV 0.5 0.9))

!(test (LikelierThanFormula (STV 0.9 0.6) (STV 0.4 0.8)) (STV 0.5 0.6))

!(test (LikelierThanFormula (STV 0.4 0.6) (STV 0.9 0.8)) (STV 0.0 0.6))

!(test (term-confidence (CPU LikelierThanFormula ((STV 0.8 0.4) (STV 0.9 0.7)) $out)) 0.4)

!(test (term-confidence (CPU InversionFormula ($a $b (STV 0.8 0.632121)) $out)) 0.5689089)

!(test
   (premises-expected-confidence
      (cons (CPU MpFormula ((STV 1.0 0.2) (STV 1.0 1.0)) $tv1)
         (cons (CPU MpFormula ((STV 1.0 0.55) $tv1) $tv2) ())))
   0.2)

!(test
   (premises-expected-confidence
      (cons (CPU MpFormula ((STV 1.0 0.8) (STV 0.25 1.0)) $tv) ()))
   0.2)

!(test
   (premises-expected-confidence
      (cons (CPU NotFormula ((STV 0.75 1.0)) $not-tv)
         (cons (CPU MpFormula ((STV 1.0 0.8) $not-tv) $tv) ())))
   0.2)

!(test
   (premises-expected-confidence
      (cons ((Animal #) (kb MAIN Nil) $prfA $tvA)
         (cons ((Creature #) (kb MAIN Nil) $prfB $tvB)
            (cons (CPU InversionFormula ($tvA $tvB (STV 0.8 0.632121)) $iitv)
               (cons ((Creature #) (kb MAIN Nil) $prfC $tvB) (cons (CPU MpFormula ($iitv $tvB) $tvA) ()))))))
   0.5689089)

!(test
   (let*
      (($heap0 (empty_heap))
       ($heap1 (add_to_heap $heap0 3.0 low))
       ($heap2 (add_to_heap $heap1 1.0 high))
       ($heap3 (add_to_heap $heap2 2.0 mid))
       ($pruned (heap-prune-to-size 2 $heap3))
       ($rest (get_from_heap $pruned $key1 $item1))
       ($_empty (get_from_heap $rest $key2 $item2)))
      ($item1 $item2 (heap_size $rest)))
   (high mid 1))

!(test
   (let*
      (($heap0 (empty_heap))
       ($heap1 (add_to_heap $heap0 1.0 high))
       ($heap2 (add_to_heap $heap1 2.0 low))
       ($kept (bounded-agenda-prune 1 $heap2)))
      (heap_size $kept))
   2)

!(test
   (let*
      (($heap0 (empty_heap))
       ($heap1 (add_to_heap $heap0 1.0 high))
       ($empty (bounded-agenda-prune 0 $heap1)))
      (heap_size $empty))
   1)

!(test
   (let*
      (($heap0 (empty_heap))
       ($heap1 (add_to_heap $heap0 1.0 high))
       ($_disable (set-bounded-agenda-pruning false))
       ($kept (bounded-agenda-prune 0 $heap1))
       ($_enable (set-bounded-agenda-pruning true)))
      (heap_size $kept))
   1)

(= (clear-backward-state)
   (progn
      (foreach-flat remove-all-atoms (() &goal &goal_lookup &goal_waiter &aggregate &proof &proof_live_cache &goal_live_cache))
      (change-state! bwd_live_epoch 0)
      ()))

!(test
   (let*
      (($_clear (clear-backward-state))
       ($_gidreset (change-state! bwd_gid 0))
       ($open-a (ensure-goal-at-depth ((Pet $a) (kb MAIN ()) $prf $tv) 0))
       ($open-x (ensure-goal-at-depth ((Pet $x) (kb MAIN ()) $p $t) 0))
       ($closed (ensure-goal-at-depth ((Pet max) (kb MAIN ()) $p2 $t2) 0)))
      ((== $open-a $open-x) (== $open-a $closed)))
   (true false))

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
