(= (MpFormula (STV $abs $abc) (STV $as $ac)) (STV (* $abs $as) (* $as (min $abc $ac))))

(= (AndFormula (STV $si $ci) (STV $sa $ca)) (let* (($sb (* $si $sa)) ($cb (min $ci $ca))) (STV $sb $cb)))

(= (OrFormula (STV $si $ci) (STV $sa $ca)) (let* (($sb (- (+ $si $sa) (* $si $sa))) ($cb (min $ci $ca))) (STV $sb $cb)))

(= (LikelierThanFormula (STV $sa $ca) (STV $sb $cb)) (STV (max 0.0 (- $sa $sb)) (min $ca $cb)))

(= (AndProjection (STV $sab $cab) (STV $sa $ca))
   (if (== $sa 0.0)
      (STV 0.0 0.0)
      (STV (min 1.0 (/ $sab $sa)) (min $cab $ca))))

(= (OrProjection (STV $sab $cab) (STV $sa $ca))
   (if (== $sa 1.0)
      (STV 0.0 0.0)
      (STV (min 1.0 (max 0.0 (/ (- $sab $sa) (- 1.0 $sa)))) (min $cab $ca))))

(= (DistGreaterThanFormula (ParticleDist $pid $scale) $threshold)
   (let $pairs (particle-fetch-pairs $pid)
      (STV (* $scale (dist-prob-gt $pairs $threshold)) (particle-confidence-from-pairs $pairs))))

(= (DistGreaterThanDistFormula $pda $pdb)
   (let*
      (($pida (particle-dist-id $pda))
        ($pidb (particle-dist-id $pdb))
        ($scalea (particle-dist-scale $pda))
        ($scaleb (particle-dist-scale $pdb))
        ($pairsa (particle-fetch-pairs $pida))
        ($pairsb (particle-fetch-pairs $pidb))
        ($ca (particle-confidence-from-pairs $pairsa))
        ($cb (particle-confidence-from-pairs $pairsb)))
      (STV (* (* $scalea $scaleb) (dist-prob-gt2 $pairsa $pairsb)) (min $ca $cb))))

(= (NotFormula (STV $s $c)) (STV (- 1 $s) $c))

(= (InversionFormula (STV $sa $ca) (STV $sb $cb) (STV $sab $cab))
   (STV (/ (* $sb $sab) $sa) (* (min-atom ($ca $cb $cab)) 0.9)))

(= (Equal $a $b) (== $a $b))

(= (NotEqual $a $b) (not (== $a $b)))
