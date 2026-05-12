(= (goal-by-id $gid) (match &goal ($gid $depth $goal $expanded $pending) ($depth $goal $expanded $pending)))

(= (aggregate-by-id $agg-gid)
   (match &aggregate ($agg-gid $child-gid $args $base-score $pending $current-pid)
      ($child-gid $args $base-score $pending $current-pid)))

(= (ensure-goal-at-depth $goal $depth)
   (let*
      (($stored-goal (copy_term $goal))
       ($goal-key (goal-key $stored-goal))
       ($hits
          (collapse
             (once
                (match &goal_lookup ($stored-key $gid)
                   (if (=alpha $stored-key $goal-key) $gid (empty)))))))
      (if (== $hits ())
         (let*
            (($gid (next-gid))
             ($_1 (add-atom &goal ($gid $depth $stored-goal false 0.0)))
             ($_2 (add-atom &goal_lookup ($goal-key $gid))))
            $gid)
         (car-atom $hits))))

(= (schedule-goal-heap $agenda $score $gid)
   (let*
      ((($depth $goal $expanded $current) (goal-by-id $gid)))
      (if $expanded $agenda
         (if (>= $current $score) $agenda
            (let*
               (($closed-proof-bonus (if (goal-has-type-vars? $goal) 0.0 1.0))
                ($bonus (if (= $goal ($_type ($_kbid $_ctx $_vars) $_prf $_tv)) $closed-proof-bonus 2.0))
                ($priority (+ (* 1000000000.0 $depth) (- 0 (+ (* 1000000.0 $score) $bonus))))
                ($nagenda (add_to_heap $agenda $priority (qgoal $score $gid)))
                ($_set
                   (progn (remove-atom &goal ($gid $depth $goal $expanded $current))
                      (add-atom &goal ($gid $depth $goal $expanded $score)))))
               $nagenda)))))

(= (schedule-aggregate-heap $agenda $agg-gid)
   (let*
      ((($child-gid $args $base-score $current $current-pid) (aggregate-by-id $agg-gid))
       (($depth $_goal $_expanded $_goal-pending) (goal-by-id $agg-gid)))
      (if (>= $current $base-score) $agenda
         (let*
            (($priority (+ (+ (* 1000000000.0 (+ 1 $depth)) (- 0 (* 1000000.0 $base-score))) 0.1))
             ($nagenda (add_to_heap $agenda $priority (qagg $base-score $agg-gid)))
             ($_set
                (progn
                   (remove-atom &aggregate ($agg-gid $child-gid $args $base-score $current $current-pid))
                   (add-atom &aggregate ($agg-gid $child-gid $args $base-score $base-score $current-pid)))))
            $nagenda))))

(=
   (aggregate-child-goal
      (CPU FoldAllCompiled ($kb $pattern $_extractor $_init $_fun $_finish $_tv-mode) $_goalres))
   (let*
      (((compiled-query $child-goal $adds) (mm2compileQuery $kb (: $prf $pattern $tvin)))
       ($_ (inject-compiled-adds $adds)))
      $child-goal))

(= (aggregate-step-value (extract-value $pattern $value) $child-atom $_child-tv)
   (let ($pattern ($_ckbid $_cctx $_cvars) $_cprf $_ctv) (copy_term $child-atom) $value))
(= (aggregate-step-value extract-tv $_child-atom $child-tv) $child-tv)

(= (aggregate-foldall-step-acc $extractor $fun $acc $child-atom $child-tv)
   (eval ($fun $acc (aggregate-step-value $extractor $child-atom $child-tv))))

(= (aggregate-finish identity $acc) $acc)
(= (aggregate-finish dist-average $acc) (reduce (reduce (DistAverageFromSumCount $acc))))

(= (make-and-bundle $goal $args) (cons and-bundle (cons $goal $args)))
(= (and-bundle-goal $bundle) (car-atom (cdr-atom $bundle)))
(= (and-bundle-premises $bundle) (cdr-atom (cdr-atom $bundle)))

(= (advance-frontier-bundle $bundle $pid)
   (let*
      (($goal (and-bundle-goal $bundle))
       ($premises (and-bundle-premises $bundle)))
      (case $premises (
           (() ())
           ((cons $prem $rest)
              (if (= $prem (proof-output-atom $pid)) (make-and-bundle $goal $rest) ()))))))

(= (waiter-live? (frontier-waiter $_parent-gid $_bundle $_score $_seen $rev-pids))
   (proof-list-live? $rev-pids))

(= (advance-frontier-waiter-heap $agenda (frontier-waiter $parent-gid $bundle $score $seen $rev-pids) $pid)
   (if (not (waiter-live? (frontier-waiter $parent-gid $bundle $score $seen $rev-pids))) $agenda
      (let*
         ((($pscore $pev) (proof-stats-by-id $pid))
          ($overlap (evidence-sets-overlap? $seen $pev))
          ($next-bundle (advance-frontier-bundle (copy_term $bundle) $pid)))
         (if $overlap $agenda
            (if (== $next-bundle ()) $agenda
               (spawn-frontier-heap $agenda
                  $parent-gid
                  $next-bundle
                  (min $score $pscore)
                  (list_to_set (append $seen $pev))
                  (cons $pid $rev-pids)))))))

(= (frontier-waiter-step (@ $waiter (head frontier-waiter)) $rest) (cons $waiter $rest))
(= (frontier-waiter-step $_waiter $rest) $rest)

(= (aggregate-waiter-step (aggregate-waiter $agg-gid) $rest) (cons $agg-gid $rest))
(= (aggregate-waiter-step $_waiter $rest) $rest)

(= (spawn-frontier-goal-heap $agenda $score $gid $waiter)
   (let*
      (($_1 (add-atom &goal_waiter ($gid $waiter)))
       ($agenda1
          (fold-flat (|-> ($acc $pid) (advance-frontier-waiter-heap $acc $waiter $pid))
             $agenda
             (goal-live-proof-ids $gid)))
       ($nagenda (schedule-goal-heap $agenda1 $score $gid)))
      $nagenda))

(= (spawn-aggregate-goal-heap $agenda $score $agg-gid $goal-view)
   (let*
      (($args (copy_term (let (CPU FoldAllCompiled $args $_goalres) $goal-view $args)))
       ($child-goal (aggregate-child-goal $goal-view))
       (($depth $_goal $_expanded $_pending) (goal-by-id $agg-gid))
       ($child-gid (ensure-goal-at-depth $child-goal (+ 1 $depth)))
       ($hits (collapse (once (match &aggregate ($agg-gid $_child $_args $_base $_pending1 $_current) true))))
       ($_agg
          (if (== $hits ())
             (add-atom &aggregate ($agg-gid $child-gid $args $score 0.0 ()))
             ()))
       ($_wait (add-atom &goal_waiter ($child-gid (aggregate-waiter $agg-gid))))
       ($agenda1 (schedule-goal-heap $agenda $score $child-gid))
       ($nagenda (schedule-aggregate-heap $agenda1 $agg-gid)))
      $nagenda))

(= (aggregate-proof-key ($type ($kbid $ctx $vars) $_prf $_tv)) (($kbid $ctx $vars) $type))
(= (aggregate-proof-key $child-atom) $child-atom)

(= (aggregate-proof-fold-step $args (aggregate-state $acc $ev $seen) $pid)
   (let*
      ((($_agg-kb $_agg-pattern $extractor $_agg-init $fun $_agg-finish $_agg-tv-mode) (copy_term $args))
       ($child-atom (proof-output-atom $pid))
       ($child-key (aggregate-proof-key $child-atom))
       (($_pscore $pev) (proof-stats-by-id $pid))
       ($child-tv (if (= $child-atom ($_type $_kb $_prf $tv)) $tv no-tv)))
      (if (is-member $child-key $seen) (aggregate-state $acc $ev $seen)
         (let*
            (($nacc (aggregate-foldall-step-acc $extractor $fun $acc $child-atom $child-tv))
             ($nev (list_to_set (append $ev $pev)))
             ($nseen (cons $child-key $seen)))
            (aggregate-state $nacc $nev $nseen)))))

(= (aggregate-final-state $child-gid $args)
   (let*
      ((($_kb $_pattern $_extractor $init-acc $_fun $_finish $_tv-mode) (copy_term $args)))
      (fold-flat (aggregate-proof-fold-step $args)
         (aggregate-state $init-acc () ())
         (goal-live-proof-ids $child-gid))))

(= (run-aggregate-heap $agenda $agg-gid)
   (let*
      ((($child-gid $args $base-score $pending $current-pid) (aggregate-by-id $agg-gid))
       ($_clear
          (progn
             (remove-atom &aggregate ($agg-gid $child-gid $args $base-score $pending $current-pid))
             (add-atom &aggregate ($agg-gid $child-gid $args $base-score 0.0 $current-pid))))
       ((aggregate-state $acc $ev $_seen) (aggregate-final-state $child-gid $args))
       (($kb $pattern $extractor $init $fun $finish $tv-mode) $args)
       ($result (CPU FoldAllCompiled $args (aggregate-finish $finish $acc))))
      (if (aggregate-snapshot-changed? $current-pid $result $ev)
         (commit-aggregate-snapshot-heap $agenda $agg-gid $result $ev)
         $agenda)))

(= (direct-goal-results-view $steps (CPU $fun $args $_res))
   (CPU $fun $args (reduce (cpu-call $steps $fun $args))))
(= (wildcard-premise-context? $kb)
   (if (is-expr $kb) (not (== (car-atom (cdr-atom $kb)) MAIN)) false))
(= (wildcard-premise-context-active? $kb)
   (not (== (collapse (once (match wildcard_premise_context ($kb) true))) ())))
(= (wildcard-to-query-var $x) (if (== $x #) $any $x))
(= (wildcard-premise-result $type $kb $prf $tv $stored-type)
   (if (contains-hash? $stored-type)
      (let $qtype (map-nested wildcard-to-query-var $stored-type)
         (if (= $type $qtype) ($type $kb $prf $tv) (empty)))
      (empty)))
(= (direct-wildcard-premise-results $type $kb $prf $tv)
   (if (and (wildcard-premise-context? $kb) (wildcard-premise-context-active? $kb))
      (superpose
         ((match wildcard_premise_index (wildcard_any $kb $stored-type $prf $tv)
             (wildcard-premise-result $type $kb $prf $tv $stored-type))
          (if (is-expr $type)
             (let $head (car-atom $type)
                (match wildcard_premise_index ((wildcard_premise_head $head) $kb $stored-type $prf $tv)
                   (wildcard-premise-result $type $kb $prf $tv $stored-type)))
             (empty))))
      (empty)))
(= (direct-goal-results-view $steps ($type $kb $prf $tv))
   (let $qtype (if (contains-hash? $type) (map-nested (|-> ($x) (if (== $x #) $any $x)) $type) $type)
      (superpose
         ((match &kb ($qtype $kb $prf $tv)
             ($qtype $kb $prf $tv))
          (direct-wildcard-premise-results $type $kb $prf $tv)))))

(= (expand-direct-goal-step $gid $_goal $agenda $result)
   (let*
      (($score (term-confidence $result))
       ($ev (leaf-evidence-for-result $result))
       ($accepted (classify-goal-proof-candidate $gid $result $ev $score))
       ($nagenda (commit-proof-candidate-heap $agenda $gid $accepted (leaf-result-candidate $result $ev))))
      $nagenda))

(= (expand-direct-goal-heap $agenda $steps $gid $goal)
   (let*
      (($results (collapse (direct-goal-results-view $steps $goal)))
       ($agenda1 (fold-flat (expand-direct-goal-step $gid $goal) $agenda $results)))
      (expand-rule-goal-heap $agenda1 $gid $goal)))

(= (open-rule-goal? $goal)
   (if (= $goal ($type $_kb $_prf $_tv))
      (or (not (== (extract-vars $type) ())) (contains-hash? $type))
      false))

(= (rule-goal-head-view ($goal $parent-gid))
   (let $key (forward-indexable-premise-key $goal)
      (if (== $key ())
         ()
         (match ccls_head_index ($key $rule-id)
            (match rules ($rule-id $goal $args)
               ($args $goal $parent-gid))))))

(= (rule-goal-view ($goal $parent-gid))
   (if (open-rule-goal? $goal)
      (rule-goal-head-view ($goal $parent-gid))
      (match ccls_index ($goal $rule-id)
         (match rules ($rule-id $goal $args)
            ($args $goal $parent-gid)))))

(= (spawn-frontier-heap $agenda $parent-gid $bundle $score $seen $rev-pids)
   (let*
      (($goal (and-bundle-goal $bundle))
       ($premises (and-bundle-premises $bundle)))
      (case $premises (
           (()
              (let*
                 (($pid-list (reverse $rev-pids)))
                 (commit-proof-candidate-heap $agenda
                    $parent-gid
                    (classify-goal-proof-candidate $parent-gid $goal $seen $score)
                    (proof-candidate (rule $goal) $score $seen $pid-list))))
           ((cons $prem $_rest)
              (let*
                 ((($parent-depth $_goal1 $_expanded $_pending) (goal-by-id $parent-gid))
                  ($gid (ensure-goal-at-depth $prem (+ 1 $parent-depth)))
                  ($stored-bundle (copy_term $bundle)))
                 (spawn-frontier-goal-heap $agenda
                    $score
                    $gid
                    (frontier-waiter $parent-gid
                       $stored-bundle
                       $score
                       $seen
                       $rev-pids))))))))

(= (expand-rule-goal-heap $agenda $parent-gid $goal)
   (fold-flat expand-rule-goal-fold
      $agenda
      (collapse (rule-goal-view ($goal $parent-gid)))))

(= (expand-rule-goal-fold $agenda ($args $goal $parent-gid))
   (let*
      (($bound (premises-expected-confidence $args))
       ($bundle (copy_term (make-and-bundle $goal $args))))
      (spawn-frontier-heap $agenda
         $parent-gid
         $bundle
         $bound
         ()
         ())))

(= (expand-goal-heap $agenda $steps $score $gid)
   (let*
      ((($depth $goal $expanded $pending) (goal-by-id $gid))
       ($_expand
          (progn (remove-atom &goal ($gid $depth $goal $expanded $pending))
             (add-atom &goal ($gid $depth $goal true $pending))))
       ($nagenda0
          (if (and (= $goal (CPU $fun $_args $_res)) (== $fun FoldAllCompiled))
             (spawn-aggregate-goal-heap $agenda $score $gid $goal)
             (expand-direct-goal-heap $agenda $steps $gid $goal)))
       ($nagenda (if (== $nagenda0 ()) (empty_heap) $nagenda0)))
      $nagenda))

(= (search-agenda-step $steps $agenda (qgoal $score $gid))
   (let*
      ((($depth $goal $expanded $pending) (goal-by-id $gid)))
      (if (and (not $expanded) (== $pending $score))
         (let*
            (($_clear
                 (progn (remove-atom &goal ($gid $depth $goal $expanded $pending))
                    (add-atom &goal ($gid $depth $goal $expanded 0.0))))
             ($nagenda (expand-goal-heap $agenda $steps $score $gid)))
            (search-agenda-heap (- $steps 1) $nagenda))
         (search-agenda-heap $steps $agenda))))

(= (search-agenda-step $steps $agenda (qagg $score $agg-gid))
   (let*
      ((($child-gid $args $base-score $pending $current-pid) (aggregate-by-id $agg-gid)))
      (if (== $pending $score)
         (search-agenda-heap (- $steps 1) (run-aggregate-heap $agenda $agg-gid))
         (search-agenda-heap $steps $agenda))))

(= (search-agenda-heap $steps $agenda)
   (if (or (<= $steps 0) (== (heap_size $agenda) 0)) (search-state $steps $agenda)
      (let*
         (($rest (get_from_heap $agenda $_priority $item)))
         (search-agenda-step $steps $rest $item))))

(= (chainer $steps $goal)
   (let*
      (($_clear (foreach-flat remove-all-atoms (&goal &goal_lookup &goal_waiter &aggregate &proof &proof_live_cache &goal_live_cache)))
       ($_reset (foreach-flat (|-> ($key) (change-state! $key 0)) (bwd_gid bwd_pid bwd_live_epoch)))
       ($root-gid (ensure-goal-at-depth $goal 0))
       ($agenda0 (schedule-goal-heap (empty_heap) 1.0 $root-gid))
       ((search-state $_steps-left $_agenda1)
          (once (if (<= $steps 0) (search-state 0 $agenda0) (search-agenda-heap (+ $steps 1) $agenda0)))))
      (once (goal-results $root-gid))))
