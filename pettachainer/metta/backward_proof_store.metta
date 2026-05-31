(= (normalize-proof-output-atom-kind $term $pid)
   (if (= $term ($type ($kbid $_ctx $_vars) $_prf $tv)) ($type ($kbid $_ctx $_vars) (proof-ref $pid) $tv)
      $term))

(= (proof-output-atom-kind (leaf $term) $pid) (normalize-proof-output-atom-kind $term $pid))
(= (proof-output-atom-kind (rule $term) $pid) (normalize-proof-output-atom-kind $term $pid))
(= (proof-output-atom-kind (aggregate $term) $_pid) $term)

(= (proof-output-atom $pid) (match &proof ($pid $_gid $output $_kind $_score $_ev $_children) $output))

(= (candidate-output-key ($type $kb $_prf $_tv)) ($type $kb))
(= (candidate-output-key $term) $term)

(= (proof-output-key-by-id $pid)
   (candidate-output-key (proof-output-atom $pid)))

(= (materialize-proof-refs $term)
   (if (is-expr $term)
      (if (is-var (car-atom $term))
         (cons (car-atom $term) (map-flat materialize-proof-refs (cdr-atom $term)))
         (if (== (car-atom $term) proof-ref)
            (materialize-proof-refs (materialize-proof (car-atom (cdr-atom $term))))
            (cons (materialize-proof-refs (car-atom $term)) (map-flat materialize-proof-refs (cdr-atom $term)))))
      $term))

(= (materialize-result-atom $atom)
   (if (= $atom ($type $kb $prf $tv)) ($type $kb (materialize-proof-refs $prf) $tv) $atom))

(= (materialize-proof-kind (leaf $raw) $_pid)
   (if (= $raw (CPU $_fun $_args $_res)) cpu (if (= $raw ($_type ($_kbid $_ctx $_vars) $prf $_tv)) $prf $raw)))
(= (aggregate-proof-label (CPU FoldAllCompiled $args $_res))
   (if (= $args ($_kb $_pattern $_extractor $_init OrFormula $_finish $_tv-mode))
      disjunction
      foldall))
(= (aggregate-proof-label (CPU GroupedFoldAllCompiled $args $_res))
   (if (= $args ($_kb $_pattern $_group $_extractor $_init OrFormula $_finish $_tv-mode))
      disjunction
      foldall))
(= (proof-ref-list ()) ())
(= (proof-ref-list (cons $pid $rest)) (cons (proof-ref $pid) (proof-ref-list $rest)))
(= (aggregate-child-proof-tokens ()) ())
(= (aggregate-child-proof-tokens (cons $pid $rest))
   (let $output (proof-output-atom $pid)
      (if (or (= $output (CPU FoldAllCompiled $_args $_res)) (= $output (CPU GroupedFoldAllCompiled $_gargs $_gres)))
         (cons (materialize-proof $pid) (aggregate-child-proof-tokens $rest))
         (aggregate-child-proof-tokens $rest))))
(= (replace-cpu-proof-token-list () $proofs) (() $proofs))
(= (replace-cpu-proof-token-list (cons $head $tail) $proofs)
   (let*
      ((($new-head $proofs1) (replace-cpu-proof-token $head $proofs))
       (($new-tail $proofs2) (replace-cpu-proof-token-list $tail $proofs1)))
      ((cons $new-head $new-tail) $proofs2)))
(= (replace-cpu-proof-token $term $proofs)
   (if (is-var $term)
      ($term $proofs)
      (if (== $term cpu)
         (if (= $proofs (cons $proof $rest)) ($proof $rest) (cpu ()))
         (if (is-expr $term)
            (let* ((($new-list $rest-proofs) (replace-cpu-proof-token-list $term $proofs)))
               ($new-list $rest-proofs))
            ($term $proofs)))))
(= (materialize-rule-proof-token $prf $pid)
   (let*
      (($base-prf (materialize-proof-refs $prf))
       ($aggregate-proofs (aggregate-child-proof-tokens (proof-children-by-id $pid)))
       (($new-prf $_unused) (replace-cpu-proof-token $base-prf $aggregate-proofs)))
      $new-prf))
(= (materialize-proof-kind (aggregate $raw) $pid)
   (let $children (proof-children-by-id $pid)
      (if (== $children ()) cpu
         (cons rule-proof
            (cons (aggregate-proof-label $raw)
               (map-flat materialize-proof-refs (proof-ref-list $children)))))))
(= (rule-kind-proof-token $term)
   (if (is-expr $term)
      (let $tail1 (cdr-atom $term)
         (if (== $tail1 ()) $term
            (let $tail2 (cdr-atom $tail1)
               (if (== $tail2 ()) $term
                  (car-atom $tail2)))))
      $term))
(= (materialize-rule-proof-expression $rule-prf)
   (if (is-expr $rule-prf)
      (if (is-var (car-atom $rule-prf))
         (if (== (cdr-atom $rule-prf) ())
            $rule-prf
            (car-atom (cdr-atom $rule-prf)))
         (cons rule-proof
            (cons (car-atom $rule-prf) (cdr-atom $rule-prf))))
      $rule-prf))
(= (materialize-proof-kind (rule $term) $pid)
   (let $prf (rule-kind-proof-token $term)
      (if (== $prf $term) $term
         (let $rule-prf (materialize-rule-proof-token $prf $pid)
            (materialize-rule-proof-expression $rule-prf)))))

(= (materialize-proof $pid)
   (match &proof ($pid $_gid $_output $kind $_score $_ev $_children)
      (materialize-proof-kind $kind $pid)))

(= (goal-proof-ids $gid)
   (collapse (match &proof ($pid $gid $_output $_kind $_score $_ev $_children) $pid)))

(= (proof-goal-id $pid)
   (match &proof ($pid $gid $_output $_kind $_score $_ev $_children) $gid))

(= (proof-children-by-id $pid)
   (match &proof ($pid $_gid $_output $_kind $_score $_ev $children) $children))

(= (proof-kind-by-id $pid)
   (match &proof ($pid $_gid $_output $kind $_score $_ev $_children) $kind))

(= (materializable-proof-kind? (rule $_term)) true)
(= (materializable-proof-kind? $_kind) false)

(= (materializable-proof-output? ($type ($_kbid MAIN Nil) $_prf $_tv))
   (and (== (extract-vars $type) ()) (not (contains-hash? $type))))
(= (materializable-proof-output? $_output) false)

(= (materialize-proof-node-to-kb $pid)
   (let*
      (($kind (proof-kind-by-id $pid))
       ($output (proof-output-atom $pid)))
      (if (and (materializable-proof-kind? $kind) (materializable-proof-output? $output))
         (let $fact (materialize-result-atom $output)
            (progn
               (forward-fact-upsert (empty_heap) $fact)
               (mark-forward-agenda-dirty $fact)))
         ())))

(= (materialize-proof-tree-to-kb $pid)
   (let $_children (materialize-proof-list-to-kb (proof-children-by-id $pid))
      (materialize-proof-node-to-kb $pid)))

(= (materialize-proof-list-to-kb ()) ())
(= (materialize-proof-list-to-kb (cons $pid $rest))
   (let $_head (materialize-proof-tree-to-kb $pid)
      (materialize-proof-list-to-kb $rest)))

(= (materialize-goal-proofs-to-kb $gid)
   (materialize-proof-list-to-kb (goal-live-proof-ids $gid)))

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
   (chainer-add-atom &proof_live_cache ((proof-live-cache-epoch) $pid $alive)))

(= (cached-proof-live? $pid)
   (match &proof_live_cache ((proof-live-cache-epoch) $pid $alive) $alive))

(= (goal-live-cache-store! $gid $pids)
   (chainer-add-atom &goal_live_cache ((proof-live-cache-epoch) $gid $pids)))

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

(= (aggregate-current-pid-live? () $_pid) false)
(= (aggregate-current-pid-live? $current-pid $pid)
   (if (is-expr $current-pid) (is-member $pid $current-pid) (== $current-pid $pid)))

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
         (aggregate-current-pid-live? (car-atom $current-hits) $pid))))

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

(= (proof-candidate-stored-evidence (proof-candidate (rule ($_type $_kb $prf $_tv)) $_score $ev $_children))
   (if (proof-term-contains-negated? $prf)
      (list_to_set (once (proof-term-evidence-list-mode proof-walk-in-kb $prf)))
      $ev))
(= (proof-candidate-stored-evidence (proof-candidate $_kind $_score $ev $_children)) $ev)

(= (normalize-proof-candidate-evidence (proof-candidate $kind $score $ev $children))
   (proof-candidate $kind $score
      (proof-candidate-stored-evidence (proof-candidate $kind $score $ev $children))
      $children))

(= (store-proof-candidate $gid (proof-candidate $kind $score $ev $children))
   (let*
      (($pid (next-pid))
        ($output (proof-output-atom-kind $kind $pid))
        ($stored-ev (proof-candidate-stored-evidence (proof-candidate $kind $score $ev $children)))
        ($_1 (chainer-add-atom &proof ($pid $gid $output $kind $score $stored-ev $children)))
        ($_2 (cache-proof-live! $pid true))
        ($_3 (append-goal-live-cache! $gid $pid)))
      $pid))

(= (proof-atom-candidate ($type $kb $prf $tv) $ev)
   (proof-candidate (leaf ($type $kb $prf $tv)) (term-confidence ($type $kb $prf $tv)) $ev ()))

(= (leaf-result-candidate $result $ev)
   (if (= $result ($type $_kb $_prf $_tv)) (proof-atom-candidate $result $ev)
      (proof-candidate (leaf $result) (term-confidence $result) $ev ())))

(= (aggregate-result-candidate $result $ev $children)
   (proof-candidate (aggregate $result) (term-confidence $result) $ev $children))

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

(= (commit-aggregate-snapshot-heap $agenda $agg-gid $result $ev $children)
   (let*
      ((($child-gid $args $base-score $pending $current-pid) (aggregate-by-id $agg-gid))
       ($pid (store-proof-candidate $agg-gid (aggregate-result-candidate $result $ev $children)))
       ($_set
          (progn
             (remove-atom &aggregate ($agg-gid $child-gid $args $base-score $pending $current-pid))
             (chainer-add-atom &aggregate ($agg-gid $child-gid $args $base-score $pending $pid))))
       ($_cache-invalidate (invalidate-proof-live-caches))
       ($nagenda (wake-proof-commit-heap $agenda $agg-gid $pid)))
      $nagenda))
