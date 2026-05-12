(= (normalize-proof-output-atom-kind $term $pid)
   (if (= $term ($type ($kbid $_ctx $_vars) $_prf $tv)) ($type ($kbid $_ctx $_vars) (proof-ref $pid) $tv)
      $term))

(= (proof-output-atom-kind (leaf $term) $pid) (normalize-proof-output-atom-kind $term $pid))
(= (proof-output-atom-kind (rule $term) $pid) (normalize-proof-output-atom-kind $term $pid))

(= (proof-output-atom $pid) (match &proof ($pid $_gid $output $_kind $_score $_ev $_children) $output))

(= (candidate-output-key ($type $kb $_prf $_tv)) ($type $kb))
(= (candidate-output-key $term) $term)

(= (proof-output-key-by-id $pid)
   (candidate-output-key (proof-output-atom $pid)))

(= (materialize-proof-refs $term)
   (if (= $term (proof-ref $pid)) (materialize-proof-refs (materialize-proof $pid))
      (if (is-expr $term)
         (cons (materialize-proof-refs (car-atom $term)) (map-flat materialize-proof-refs (cdr-atom $term)))
         $term)))

(= (materialize-result-atom $atom)
   (if (= $atom ($type $kb $prf $tv)) ($type $kb (materialize-proof-refs $prf) $tv) $atom))

(= (materialize-proof-kind (leaf $raw) $_pid)
   (if (= $raw (CPU $_fun $_args $_res)) cpu (if (= $raw ($_type ($_kbid $_ctx $_vars) $prf $_tv)) $prf $raw)))
(= (materialize-proof-kind (rule ($_type $_kb $prf $_tv)) $_pid)
   (cons rule-proof
      (cons (materialize-proof-refs (car-atom $prf)) (map-flat materialize-proof-refs (cdr-atom $prf)))))
(= (materialize-proof-kind (rule $term) $_pid) $term)

(= (materialize-proof $pid)
   (match &proof ($pid $_gid $_output $kind $_score $_ev $_children)
      (materialize-proof-kind $kind $pid)))

(= (goal-proof-ids $gid)
   (collapse (match &proof ($pid $gid $_output $_kind $_score $_ev $_children) $pid)))

(= (proof-goal-id $pid)
   (match &proof ($pid $gid $_output $_kind $_score $_ev $_children) $gid))

(= (proof-children-by-id $pid)
   (match &proof ($pid $_gid $_output $_kind $_score $_ev $children) $children))

(= (proof-live-cache-epoch)
   (let $n (get-state bwd_live_epoch) (if-error $n 0 $n)))

(= (clear-proof-live-caches)
   (progn
      (remove-all-atoms &proof_live_cache)
      (remove-all-atoms &goal_live_cache)
      ()))

(= (invalidate-proof-live-caches)
   (let $epoch (proof-live-cache-epoch)
      (progn
         (change-state! bwd_live_epoch (+ $epoch 1))
         (clear-proof-live-caches))))

(= (cache-proof-live! $pid $alive)
   (add-atom &proof_live_cache ((proof-live-cache-epoch) $pid $alive)))

(= (cached-proof-live? $pid)
   (match &proof_live_cache ((proof-live-cache-epoch) $pid $alive) $alive))

(= (goal-live-cache-store! $gid $pids)
   (add-atom &goal_live_cache ((proof-live-cache-epoch) $gid $pids)))

(= (goal-live-cache-remove! $gid $pids)
   (remove-atom &goal_live_cache ((proof-live-cache-epoch) $gid $pids)))

(= (cached-goal-live-proof-ids $gid)
   (match &goal_live_cache ((proof-live-cache-epoch) $gid $pids) $pids))

(= (append-goal-live-cache! $gid $pid)
   (let*
      (($hits (collapse (once (match &goal_live_cache ((proof-live-cache-epoch) $gid $pids) $pids)))))
      (if (== $hits ())
         ()
         (let*
            (($pids (car-atom $hits))
             ($npids (append $pids ($pid))))
            (progn
               (goal-live-cache-remove! $gid $pids)
               (goal-live-cache-store! $gid $npids))))))

(= (proof-live-compute $pid)
   (let*
      (($gid (proof-goal-id $pid))
       ($current-hits
          (collapse
             (once
                (match &aggregate ($gid $_child $_args $_base $_pending $current-pid)
                   $current-pid)))))
      (if (== $current-hits ())
         (proof-list-live? (proof-children-by-id $pid))
         (== (car-atom $current-hits) $pid))))

(= (proof-list-live? ())
   true)
(= (proof-list-live? (cons $pid $rest))
   (and (proof-live? $pid) (proof-list-live? $rest)))

(= (proof-live? $pid)
   (let*
      (($hits (collapse (once (cached-proof-live? $pid)))))
      (if (== $hits ())
         (let*
            (($alive (proof-live-compute $pid))
             ($_cache (cache-proof-live! $pid $alive)))
            $alive)
         (car-atom $hits))))

(= (goal-live-proof-step $acc $pid)
   (if (proof-live? $pid) (append $acc ($pid)) $acc))

(= (goal-live-proof-ids-compute $gid)
   (fold-flat goal-live-proof-step () (goal-proof-ids $gid)))

(= (goal-live-proof-ids $gid)
   (let*
      (($hits (collapse (once (cached-goal-live-proof-ids $gid)))))
      (if (== $hits ())
         (let*
            (($pids (goal-live-proof-ids-compute $gid))
             ($_cache (goal-live-cache-store! $gid $pids)))
            $pids)
         (car-atom $hits))))

(= (goal-results $gid)
   (let*
      (($pids (goal-live-proof-ids $gid))
        (($_depth $goal $_expanded $_pending) (goal-by-id $gid)))
      (if (goal-has-type-vars? $goal) (map-flat materialize-result-atom (map-flat proof-output-atom $pids))
         (case $pids (
              (() ())
              ((cons $pid $rest)
                 (let $merged
                    (fold-flat (|-> ($acc $next-pid) (merge-proof-atoms $acc (proof-output-atom $next-pid)))
                       (proof-output-atom $pid)
                       $rest)
                    (if (== $merged ()) () ((materialize-result-atom $merged))))))))))

(= (leaf-evidence-for-result $result)
   (if (= $result ($type ($kbid $_ctx $_vars) $prf $_tv))
      (if (contains-hash? $type) () ((fact-ev ($kbid $_ctx $_vars) $prf $type)))
      ()))

(= (proof-overlap-dominates-score? $old-ev $old-score $new-ev $new-score)
   (and (evidence-sets-overlap? $old-ev $new-ev)
      (or (> $old-score $new-score) (and (== $old-score $new-score) (evidence-subset? $new-ev $old-ev)))))

(= (goal-proof-candidate-comparable? false $_outkey $_oldpid) true)
(= (goal-proof-candidate-comparable? true $outkey $oldpid)
   (== (proof-output-key-by-id $oldpid) $outkey))

(= (goal-proof-candidate-step $_open $_outkey $ev $score false $_oldpid) false)
(= (goal-proof-candidate-step $open $outkey $ev $score true $oldpid)
   (if (goal-proof-candidate-comparable? $open $outkey $oldpid)
      (let ($old-score $old-ev) (proof-stats-by-id $oldpid)
         (if (and (== $old-score $score) (== $old-ev $ev)) false
            (if (proof-overlap-dominates-score? $old-ev $old-score $ev $score) false true)))
      true))

(= (classify-goal-proof-candidate $gid $result $ev $score)
   (let*
      ((($_depth $goal $_expanded $_pending) (goal-by-id $gid))
       ($open (goal-has-type-vars? $goal))
       ($outkey (candidate-output-key $result)))
      (fold-flat (goal-proof-candidate-step $open $outkey $ev $score)
      true
      (goal-live-proof-ids $gid))))

(= (store-proof-candidate $gid (proof-candidate $kind $score $ev $children))
   (let*
      (($pid (next-pid))
        ($output (proof-output-atom-kind $kind $pid))
        ($_1 (add-atom &proof ($pid $gid $output $kind $score $ev $children)))
        ($_2 (cache-proof-live! $pid true))
        ($_3 (append-goal-live-cache! $gid $pid)))
      $pid))

(= (proof-atom-candidate ($type $kb $prf $tv) $ev)
   (proof-candidate (leaf ($type $kb $prf $tv)) (term-confidence ($type $kb $prf $tv)) $ev ()))

(= (leaf-result-candidate $result $ev)
   (if (= $result ($type $_kb $_prf $_tv)) (proof-atom-candidate $result $ev)
      (proof-candidate (leaf $result) (term-confidence $result) $ev ())))

(= (proof-depends-on-goal-seen? $pid $gid $open-goal $seen-pids)
   (if (is-member $pid $seen-pids) false
      (or (and (not $open-goal) (== (match &proof ($pid $proof-gid $_output $_kind $_score $_ev $_children) $proof-gid) $gid))
         (fold-flat
            (|-> ($acc $child-pid)
               (or $acc (proof-depends-on-goal-seen? $child-pid $gid $open-goal (cons $pid $seen-pids))))
            false
            (match &proof ($pid $_proof-gid $_output $_kind $_score $_ev $kids)
               $kids)))))

(= (candidate-is-cyclic? $gid ()) false)
(= (candidate-is-cyclic? $gid (cons $pid $pids))
   (let*
      ((($_depth $goal $_expanded $_pending) (goal-by-id $gid))
       ($open-goal (goal-has-type-vars? $goal)))
      (or (proof-depends-on-goal-seen? $pid $gid $open-goal ()) (candidate-is-cyclic? $gid $pids))))

(= (wake-proof-commit-heap $agenda $gid $pid)
   (let*
      (($waiters (collapse (match &goal_waiter ($gid $waiter) $waiter)))
       ($agenda1
          (fold-flat (|-> ($acc $waiter) (advance-frontier-waiter-heap $acc $waiter $pid))
             $agenda
             (foldr-flat frontier-waiter-step () $waiters)))
       ($agenda2
          (fold-flat (|-> ($acc $agg-gid) (schedule-aggregate-heap $acc $agg-gid))
             $agenda1
             (foldr-flat aggregate-waiter-step () $waiters))))
      $agenda2))

(= (commit-proof-candidate-heap $agenda $gid $accepted (proof-candidate $kind $score $ev $children))
   (if (== $accepted false) $agenda
      (if (candidate-is-cyclic? $gid $children) $agenda
         (let $pid (store-proof-candidate $gid (proof-candidate $kind $score $ev $children))
            (wake-proof-commit-heap $agenda $gid $pid)))))

(= (aggregate-snapshot-changed? () $_result $_ev)
   true)
(= (aggregate-snapshot-changed? $current-pid $result $ev)
   (let*
      (($current-output (proof-output-atom $current-pid))
       (($_current-score $current-ev) (proof-stats-by-id $current-pid)))
      (or (not (== $current-output $result)) (not (== $current-ev $ev)))))

(= (commit-aggregate-snapshot-heap $agenda $agg-gid $result $ev)
   (let*
      ((($child-gid $args $base-score $pending $current-pid) (aggregate-by-id $agg-gid))
       ($pid (store-proof-candidate $agg-gid (leaf-result-candidate $result $ev)))
       ($_set
          (progn
             (remove-atom &aggregate ($agg-gid $child-gid $args $base-score $pending $current-pid))
             (add-atom &aggregate ($agg-gid $child-gid $args $base-score $pending $pid))))
       ($_cache-invalidate (invalidate-proof-live-caches))
       ($nagenda (wake-proof-commit-heap $agenda $agg-gid $pid)))
      $nagenda))
