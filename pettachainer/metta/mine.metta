!(import! &self petta_chainer)

!(import! &data data_test)

!(compileadd kb (get-atoms &data))

!(collapse (query 100 kb (: $prf (XYZSample $sample) $tv)))

!(let*
   (($jointDist
        (ParticleFromPairs
           (((Pair (XY 10.0 100.0) 20.0) 1.0)
            ((Pair (XY 10.0 100.0) 21.0) 1.0)
            ((Pair (XY 10.0 100.0) 19.0) 1.0)
            ((Pair (XY 10.0 2.0) 49.0) 1.0)
            ((Pair (XY 10.0 2.0) 50.0) 1.0)
            ((Pair (XY 10.0 2.0) 51.0) 1.0))))
    ($xdist (PointMass 10.0))
    ($ydist (PointMass 100.0))
    ($xydist (DistMap2Formula XY $xdist $ydist))
    ($zdist (CondDistFromJoint $jointDist $xydist 5.0)))
   (ParticlePairs $zdist))

!(let*
   (($jointDist
        (ParticleFromPairs
           (((Pair (XY 10.0 100.0) 20.0) 1.0)
            ((Pair (XY 10.0 100.0) 21.0) 1.0)
            ((Pair (XY 10.0 100.0) 19.0) 1.0)
            ((Pair (XY 10.0 2.0) 49.0) 1.0)
            ((Pair (XY 10.0 2.0) 50.0) 1.0)
            ((Pair (XY 10.0 2.0) 51.0) 1.0))))
    ($xdist (PointMass 10.0))
    ($ydist (PointMass 2.0))
    ($xydist (DistMap2Formula XY $xdist $ydist))
    ($zdist (CondDistFromJoint $jointDist $xydist 5.0)))
   (ParticlePairs $zdist))
