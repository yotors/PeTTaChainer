!(import! &self petta_chainer)

(= (TotalEvidenceOr none $tv) $tv)
(= (TotalEvidenceOr $left $right) (OrFormula $left $right))
(= (TotalEvidenceTv none) (STV 0.0 0.0))
(= (TotalEvidenceTv $tv) $tv)
(= (TotalEvidenceAcc (TotalEvidenceTvs $pos-tv $neg-tv) (EvidenceCase pos $tv))
   (TotalEvidenceTvs (TotalEvidenceOr $pos-tv $tv) $neg-tv))
(= (TotalEvidenceAcc (TotalEvidenceTvs $pos-tv $neg-tv) (EvidenceCase neg $tv))
   (TotalEvidenceTvs $pos-tv (TotalEvidenceOr $neg-tv $tv)))
(= (TotalEvidenceMpFormula $atv $evidence-tvs)
   (if (= $evidence-tvs (TotalEvidenceTvs none none))
      (empty)
      (let (TotalEvidenceTvs $pos-tv $neg-tv) $evidence-tvs
         (TotalMpFormula $atv (TotalEvidenceTv $pos-tv) (TotalEvidenceTv $neg-tv)))))

!(compileadd kb (: ta (Tall alice) (STV 0.9 0.5)))
!(compileadd kb (: fa (Female alice) (STV 0.9 0.5)))
!(compileadd kb (: tm (Tall mary) (STV 0.9 0.5)))
!(compileadd kb (: fm (Female mary) (STV 0.9 0.5)))
!(compileadd kb (: tl (Tall luci) (STV 0.1 0.5)))
!(compileadd kb (: fl (Female luci) (STV 0.9 0.5)))
!(compileadd kb (: tb (Tall bob) (STV 0.5 1.0)))

!(add-to-kb
   (rules
      (((($p1 $x) (kb $ctx $vars) $p1prf $p1tv)
        (($p2 $x) (kb $ctx $vars) $p2prf $p2tv)
        (CPU AndFormula ($p1tv $p2tv) $case-tv))
       |-
       ((TotalEvidence pos $p1 $p2 $x $case-tv)
          (kb $ctx $vars)
          (total-pos (rule-proof conjunction $p1prf $p2prf))
          $case-tv))))

!(add-to-kb
   (rules
      (((($p1 $x) (kb $ctx $vars) $p1prf $p1tv)
        (CPU NotFormula ($p1tv) $not-p1tv)
        (($p2 $x) (kb $ctx $vars) $p2prf $p2tv)
        (CPU AndFormula ($not-p1tv $p2tv) $case-tv))
       |-
       ((TotalEvidence neg $p1 $p2 $x $case-tv)
          (kb $ctx $vars)
          (total-neg (rule-proof conjunction (negated $p1prf) $p2prf))
          $case-tv))))

!(add-to-kb
   (rules
      (((($p1 $y) (kb $ctx $vars) $apr $atv)
        (CPU NotEqual ($p1 $p2) true)
        (CPU FoldAllCompiled
           (kb
              (TotalEvidence $case $p1 $p2 $x $case-tv)
              (extract-value
                 (TotalEvidence $case $p1 $p2 $x $case-tv)
                 (EvidenceCase $case $case-tv))
              (TotalEvidenceTvs none none)
              TotalEvidenceAcc
              identity
              result-tv)
           $evidence-tvs)
        (CPU TotalEvidenceMpFormula ($atv $evidence-tvs) $btv))
       |-
       (($p2 $y)
          (kb $ctx $vars)
          (ii_total $apr cpu)
          $btv))))

!(test
   (collapse (query 50 kb (: $prf (Female bob) $stv)))
   ((: (rule-proof ii_total tb
          (rule-proof foldall
             (rule-proof total-neg (rule-proof conjunction (negated tl) fl))
             (rule-proof total-pos (rule-proof conjunction tl fl))
             (rule-proof total-pos (rule-proof conjunction ta fa))
             (rule-proof total-neg (rule-proof conjunction (negated ta) fa))
             (rule-proof total-pos (rule-proof conjunction tm fm))
             (rule-proof total-neg (rule-proof conjunction (negated tm) fm))))
       (Female bob)
       (STV 0.9049050000000001 0.5))))
