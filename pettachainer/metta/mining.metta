!(import! &self (library lib_import))

!(use-module! assoc)

!(import_prolog_function (superpose (empty_assoc put_assoc get_assoc)))

!(bind! &mining_stats (new-space))
!(bind! &mining_index (new-space))

(= (pattern-mining-on-add-key $kb) (atom_concat mining_on_add_ $kb))

(= (set-pattern-mining-on-add $kb $enabled) (change-state! (pattern-mining-on-add-key $kb) $enabled))
(= (enable-pattern-mining-on-add $kb) (set-pattern-mining-on-add $kb true))
(= (disable-pattern-mining-on-add $kb) (set-pattern-mining-on-add $kb false))

(= (pattern-mining-on-add-enabled? $kb)
   (let $menabled (catch (get-state (pattern-mining-on-add-key $kb)))
      (if-error $menabled false $menabled)))

(= (process-on-add-items $kb (: $prf $type $tv)) (process-on-add $kb (: $prf $type $tv)))
(= (process-on-add-items $kb ()) ())
(= (process-on-add-items $kb (cons $stmt $rest))
   (progn (process-on-add-items $kb $stmt) (process-on-add-items $kb $rest)))
(= (process-on-add-items $kb $_other) ())

(= (maybe-process-on-add $kb $stmt)
   (if (pattern-mining-on-add-enabled? $kb)
      (let $_ (collapse (process-on-add-items $kb $stmt)) ())
      ()))

(= (shared-objects () $argsb) ())
(= (shared-objects (cons $h $t) $argsb)
   (let $rst (shared-objects $t $argsb)
      (if (and (is-member $h $argsb) (not (is-member $h $rst))) (cons $h $rst) $rst)))

(= (index-of-arg $arg () $idx) 0)
(= (index-of-arg $arg (cons $h $t) $idx) (if (== $arg $h) $idx (index-of-arg $arg $t (+ $idx 1))))

(= (generalize-args-key () $shared) ())
(= (generalize-args-key (cons $h $t) $shared)
   (let $idx (index-of-arg $h $shared 1)
      (cons (if (> $idx 0) (V $idx) $h) (generalize-args-key $t $shared))))

(= (generalized-terms-key $pa $argsa $pb $argsb)
   (let*
      (($shared (shared-objects $argsa $argsb))
        ($premk (cons $pa (generalize-args-key $argsa $shared)))
        ($conck (cons $pb (generalize-args-key $argsb $shared))))
      (terms $premk $conck)))

(= (rewrite-v-step $expr ($accum $assoc))
   (if (= $expr (V $n))
      (let ($v $nassoc) (case (get_assoc $n $assoc) (($a ($a $assoc)) (Empty ($v (put_assoc $n $assoc $v)))))
         ((cons $v $accum) $nassoc))
      (if (is-expr $expr)
         (let ($nacc $nassoc) (foldr-flat rewrite-v-step (() $assoc) $expr) ((cons $nacc $accum) $nassoc))
         ((cons $expr $accum) $assoc))))

(= (clear-mined-implication-rules $kb $premk $conck)
   (let $_
      (collapse
         (match &kb (rules ($args |- (: ($kb MAIN ()) ((mined_implication $premk $conck) $p) $type $tv)))
            (remove-atom &kb
               (rules
                  ($args |- (: ($kb MAIN ()) ((mined_implication $premk $conck) $p) $type $tv))))))
      (collapse
         (match &kb
            (rules
               ($args |-
                  (: ($kb MAIN ()) ((inverted (mined_implication $premk $conck) with $x1 $x2 $x3 $x4) $p) $type $tv)))
            (remove-atom &kb
               (rules
                  ($args |-
                     (: ($kb MAIN ()) ((inverted (mined_implication $premk $conck) with $x1 $x2 $x3 $x4) $p) $type $tv))))))))

(= (emit-mined-implication $kb $premk $conck $alpha $beta)
   (let ($prem $conc) (fst (foldr-flat rewrite-v-step (() (empty_assoc)) ($premk $conck)))
      (let*
         (($sum (+ $alpha $beta))
           ($s (if (> $sum 0.0) (/ $alpha $sum) 0.5))
           ($c (/ $sum (+ $sum 800.0)))
           ($type (Implication (Premises $prem) (Conclusions $conc)))
           ($stmt (: (mined_implication $premk $conck) $type (STV $s $c)))
           ($_ (clear-mined-implication-rules $kb $premk $conck)))
         (let $_ (collapse (compileadd $kb $stmt)) ()))))

(= (update-directional-by-key $kb $premk $conck $sa $ca $sb $cb)
   (let*
      (($w (min $ca $cb))
        ($ainc (* $w (* $sa $sb)))
        ($binc (* $w (* $sa (- 1.0 $sb))))
        ($m
           (collapse
              (once (match &mining_stats (ind-impl-stats $kb $premk $conck $olda $oldb) (ab $olda $oldb)))))
        ($cur (if (== $m ()) (ab 0.0 0.0) (car-atom $m)))
        ((ab $olda $oldb) $cur)
        ($newa (+ $olda $ainc))
        ($newb (+ $oldb $binc))
        ($_
           (collapse
              (match &mining_stats (ind-impl-stats $kb $premk $conck $olda2 $oldb2)
                 (remove-atom &mining_stats (ind-impl-stats $kb $premk $conck $olda2 $oldb2)))))
        ($_ (add-atom &mining_stats (ind-impl-stats $kb $premk $conck $newa $newb))))
      (ab $newa $newb)))

(= (mine-predicate-pair $kb $pa $argsa (STV $sa $ca) $pb $argsb (STV $sb $cb))
   (let*
      (((terms $premab $concab) (generalized-terms-key $pa $argsa $pb $argsb))
        ((terms $premba $concba) (generalized-terms-key $pb $argsb $pa $argsa)))
      (if (and (== $premab $concab) (== $premba $concba)) (empty)
         (superpose (
              (update-directional-by-key $kb $premab $concab $sa $ca $sb $cb)
              (update-directional-by-key $kb $premba $concba $sb $cb $sa $ca))))))

(= (materialize-mined-implications $kb)
   (collapse
      (match &mining_stats (ind-impl-stats $kb $premk $conck $alpha $beta)
         (emit-mined-implication $kb
            $premk
            $conck
            $alpha
            $beta))))

(= (seen-pair? $stmtid $cid) (not (== (collapse (once (match &kb (ind-seen-pair $stmtid $cid) ok))) ())))

(= (mine-candidate $kb $stmtid $pa $args $tva $cid $pb $argsb $tvb)
   (if (or (== $cid $stmtid) (seen-pair? $stmtid $cid)) (empty)
      (let $_ (add-atom &kb (ind-seen-pair $stmtid $cid))
         (if (== (shared-objects $args $argsb) ()) (empty)
            (mine-predicate-pair $kb
               $pa
               $args
               $tva
               $pb
               $argsb
               $tvb)))))

(= (mine-arg-step (minectx $kb $stmtid $pa $args $tva) $arg)
   (let $_
      (collapse
         (match &mining_index (ind-arg-index $kb $arg $cid $pb $argsb $tvb)
            (mine-candidate $kb
               $stmtid
               $pa
               $args
               $tva
               $cid
               $pb
               $argsb
               $tvb)))
      (minectx $kb
         $stmtid
         $pa
         $args
         $tva)))

(= (index-arg-step (idxctx $kb $stmtid $pa $args $tv) $arg)
   (let $_ (add-atom &mining_index (ind-arg-index $kb $arg $stmtid $pa $args $tv))
      (idxctx $kb
         $stmtid
         $pa
         $args
         $tv)))

(= (process-on-add $kb (: $prf $type $tv))
   (if (= $type (Implication (cons Premises $premises) (cons Conclusions $conclusions))) ()
      (if (and (and (not (is-expr $prf)) (is-expr $type)) (= $tv (STV $s $c)))
         (let*
            (($pa (car-atom $type))
              ($args (cdr-atom $type))
              ($indexed-args (list_to_set $args)))
            (superpose (
                 (let $_ (foldl-atom $indexed-args (minectx $kb $prf $pa $args $tv) mine-arg-step)
                    (collapse
                       (match &kb (ind-seen-pair $prf $cid)
                          (remove-atom &kb (ind-seen-pair $prf $cid)))))
                 (foldl-atom $indexed-args (idxctx $kb $prf $pa $args $tv) index-arg-step))))
         ())))
