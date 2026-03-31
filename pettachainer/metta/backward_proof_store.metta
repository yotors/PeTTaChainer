(= (proof-goal-by-id $pid) (match &proof_goal ($pid $gid) $gid))

(= (proof-output-term $pid $term)
   (if (= $term ($type ($kbid $_ctx $_vars) $_prf $tv))
      ($type ($kbid $_ctx $_vars) (proof-ref $pid) $tv)
      $term))

(= (proof-output-atom $pid)
   (case (proof-kind-by-id $pid) (
        ((leaf $term) (proof-output-term $pid $term))
        ((rule $aid $term) (proof-output-term $pid $term))
        ($other (empty)))))

(= (materialize-proof-refs $term)
   (if (= $term (proof-ref $pid)) (materialize-proof-refs (materialize-proof $pid))
      (if (is-expr $term)
         (cons (materialize-proof-refs (car-atom $term))
            (map-flat materialize-proof-refs (cdr-atom $term)))
         $term)))

(= (materialize-result-atom $atom)
   (if (= $atom ($type $kb $prf $tv)) ($type $kb (materialize-proof-refs $prf) $tv)
      $atom))

(= (materialize-rule-proof $aid $pid-list)
   (case
      (instantiate-and-bundle
         (copy_term (match &and_node ($aid $_parent $_rule $_bound $bundle) $bundle))
         $pid-list) (
        ((and-bundle ($_type $_kb $prf $_tv) $_rest)
           (cons rule-proof
              (cons (materialize-proof-refs (car-atom $prf))
                 (map-flat materialize-proof-refs (cdr-atom $prf)))))
        ($other $other))))

(= (materialize-proof $pid)
   (case (proof-kind-by-id $pid) (
        ((leaf (CPU $_fun $_args $_res)) cpu)
        ((leaf $raw) (if (= $raw ($_type ($_kbid $_ctx $_vars) $prf $_tv)) $prf $raw))
        ((rule $aid $_term)
           (materialize-rule-proof $aid (match &proof_children ($pid $kids) $kids)))
        ($other $other))))

(= (goal-proof-pids $gid)
   (collapse (match &goal_proof ($gid $pid) $pid)))

(= (goal-proof-atoms $pids)
   (if (== $pids ()) () (map-flat proof-output-atom $pids)))

(= (goal-merged-proof-atom $gid)
   (let $pids (goal-proof-pids $gid)
      (if (== $pids ()) ()
         (fold-flat
            (|-> ($acc $pid) (merge-proof-atoms $acc (proof-output-atom $pid)))
            (proof-output-atom (car-atom $pids))
            (cdr-atom $pids)))))

(= (materialize-result-atoms $atoms)
   (if (== $atoms ()) () (map-flat materialize-result-atom $atoms)))

(= (goal-results $gid)
   (if (goal-has-type-vars? $gid)
      (materialize-result-atoms (goal-proof-atoms (goal-proof-pids $gid)))
      (let $merged (goal-merged-proof-atom $gid)
         (if (== $merged ()) ()
            ((materialize-result-atom $merged))))))

(= (leaf-evidence-for-result $result)
   (if (= $result ($type ($kbid $_ctx $_vars) $prf $_tv))
      (if (contains-hash? $type) () ((fact-ev ($kbid $_ctx $_vars) $prf $type)))
      ()))

(= (proof-overlap-dominates-score? $old-ev $old-score $new-ev $new-score)
   (and (evidence-sets-overlap? $old-ev $new-ev)
      (or (> $old-score $new-score)
         (and (== $old-score $new-score) (evidence-subset? $new-ev $old-ev)))))

(= (goal-proof-candidate-step $ev $score false $_oldpid) false)
(= (goal-proof-candidate-step $ev $score true $oldpid)
   (let ($old-score $old-ev) (proof-stats-by-id $oldpid)
      (if (proof-overlap-dominates-score? $old-ev $old-score $ev $score) false true)))

(= (classify-goal-proof-candidate $gid $ev $score)
   (fold-flat (goal-proof-candidate-step $ev $score)
      true
      (collapse (match &goal_proof ($gid $oldpid) $oldpid))))

(= (store-proof-candidate $gid (proof-candidate $kind $tv-state $score $ev $children))
   (let*
      (($pid (next-pid))
        ($_1 (add-atom &proof_goal ($pid $gid)))
        ($_2 (add-atom &proof_kind ($pid $kind)))
        ($_3 (add-atom &proof_stats ($pid $score $ev)))
        ($_4 (add-atom &proof_children ($pid $children))))
      $pid))

(= (proof-atom-candidate ($type $kb $prf $tv) $ev)
   (proof-candidate (leaf ($type $kb $prf $tv))
      (with-tv $tv)
      (term-confidence ($type $kb $prf $tv))
      $ev
      ()))

(= (leaf-result-candidate $result $ev)
   (if (= $result ($type $_kb $_prf $_tv))
      (proof-atom-candidate $result $ev)
      (proof-candidate (leaf $result) no-tv (term-confidence $result) $ev ())))

(= (proof-depends-on-goal-seen? $pid $gid $seen-pids)
   (if (is-member $pid $seen-pids) false
      (or (== (proof-goal-by-id $pid) $gid)
         (fold-flat
            (|-> ($acc $child-pid)
               (or $acc
                  (proof-depends-on-goal-seen? $child-pid $gid (cons $pid $seen-pids))))
            false
            (match &proof_children ($pid $kids)
               $kids)))))

(= (candidate-is-cyclic? $gid ()) false)
(= (candidate-is-cyclic? $gid (cons $pid $pids))
   (or (proof-depends-on-goal-seen? $pid $gid ()) (candidate-is-cyclic? $gid $pids)))

(=
   (commit-proof-candidate-heap $agenda
      $gid
      $accepted
      (proof-candidate $kind $tv-state $score $ev $children))
   (if (== $accepted false) $agenda
      (if (candidate-is-cyclic? $gid $children) $agenda
         (let $pid
            (store-proof-candidate $gid
               (proof-candidate $kind $tv-state $score $ev $children))
            (progn
               (add-atom &goal_proof ($gid $pid))
               (fold-flat
                  (|-> ($acc $waiter) (advance-goal-waiter-heap $acc $waiter $pid))
                  $agenda
                  (collapse (match &goal_waiter ($gid $waiter) $waiter))))))))

(=
   (commit-proof-candidate $gid
      $accepted
      (proof-candidate $kind $tv-state $score $ev $children))
   (if (== $accepted false) ()
      (let $_
         (commit-proof-candidate-heap (empty_heap)
            $gid
            $accepted
            (proof-candidate $kind $tv-state $score $ev $children))
         ())))
