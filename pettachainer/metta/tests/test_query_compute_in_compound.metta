!(import! &self petta_chainer)

!(test
   (== (length (compile-query-adds
      (: (kbctx queryComputeKb) $prf (And (P $x) (Compute + ($x 1) $y) (P $y)) $tv))) 1)
   true)

!(compileadd queryComputeKb (: p1 (P 1) (STV 1.0 1.0)))

!(compileadd queryComputeKb (: p2 (P 2) (STV 1.0 1.0)))

!(compileadd queryComputeKb (: p3 (P 3) (STV 1.0 1.0)))

!(test
   (collapse (query 50 queryComputeKb (: $prf (And (P $x) (Compute + ($x 1) $y) (P $y)) $tv)))
   ((: (rule-proof query-compound (rule-proof conjunction p1 cpu p2))
       (And (P 1) (Compute + (1 1) 2) (P 2))
       (STV 1.0 0.9))
    (: (rule-proof query-compound (rule-proof conjunction p2 cpu p3))
       (And (P 2) (Compute + (2 1) 3) (P 3))
       (STV 1.0 0.9))))
