Cloud Images
============

Below is the historical list of published images available to Jenkins jobs.
New projects should target the most recent Ubuntu 22.04 (Jammy) images
(builder / docker / devstack / mininet) or CentOS Stream 8 where Ubuntu is not
yet available. We have deprecated CentOS 7 images and plan to remove them
after the final migration (date TBD).

Recommended (current) labels (see Jenkins node labels / job parameters for
exact names):

* Ubuntu 22.04 builder (Java 17 default)
* Ubuntu 22.04 docker
* Ubuntu 22.04 devstack (for OpenStack CSIT)
* Ubuntu 22.04 mininet-ovs-217
* CentOS Stream 8 builder (legacy support / transitional)

Historical inventory:

* ZZCI - OPNFV - apex - compute - 0
* ZZCI - OPNFV - apex - compute - 1
* ZZCI - OPNFV - apex - controller - 0
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260301-160145.480
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260401-134916.347
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260401-160128.618
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260601-160118.057
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260701-160017.910
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260715-122022.792
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260730-074353.456
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260801-160146.975
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260804-002042.610
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260310-104022.702
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260310-104026.015
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260310-104048.259
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260310-212125.165
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260319-083258.658
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260319-091248.153
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260401-134330.404
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260401-134345.507
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260401-134610.289
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260401-160247.443
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260406-133416.603
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260408-112803.799
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260409-214307.895
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260410-113712.784
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260410-113953.653
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260412-072850.851
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260414-124156.236
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260415-122044.148
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260522-150844.632
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260601-160147.776
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260601-165203.785
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260617-113849.035
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260701-160446.741
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260715-122038.658
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260730-124138.114
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260801-010748.470
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260206-132531.854
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260301-010217.216
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260401-010115.623
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260501-010107.869
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260601-010111.551
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260606-125100.778
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260606-125239.586
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260609-014359.318
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260610-001250.246
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260612-183307.150
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260624-204800.828
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260629-200121.975
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260629-204324.166
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260701-010102.703
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260701-133838.371
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260706-003531.179
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260713-122912.952
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260715-122022.931
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260721-145940.619
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260726-142657.676
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260730-070431.412
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260730-074604.947
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260731-103408.357
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260801-010144.193
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260801-015940.106
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260803-101858.806
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260804-002051.555
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260206-133442.297
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260301-170151.303
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260310-104019.460
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260310-104020.563
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260310-104040.674
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260310-212113.971
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260319-083306.732
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260319-091252.679
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260327-075430.593
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260401-134338.413
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260401-134609.862
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260401-170119.641
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260402-130908.084
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260408-112811.737
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260409-214304.246
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260410-113956.421
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260412-072841.881
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260413-213045.461
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260414-124155.019
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260415-122052.915
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260522-150713.490
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260522-150843.205
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260522-151013.103
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260601-170147.838
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260617-113843.285
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260617-113858.604
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260701-170128.430
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260715-121936.720
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260730-124156.863
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260801-014139.633
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260801-170113.612
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260811-083901.394
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250917-133034.654
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260206-132534.928
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260301-010340.912
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260310-104036.448
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260310-104044.782
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260327-035937.980
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260327-075416.929
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260327-075458.141
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260401-010849.477
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260401-134329.749
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260401-134344.385
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260401-134804.767
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260402-130809.282
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260402-130908.022
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260402-130937.422
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260406-133429.986
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260407-103736.004
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260408-112815.109
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260410-113708.815
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260410-113922.255
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260413-213055.769
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260414-124143.568
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260415-122104.144
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260522-151456.219
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260601-165202.564
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260730-124159.338
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260801-010434.012
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260811-083858.899
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260206-132525.392
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260401-134551.965
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260401-134626.525
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260730-074620.666
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260807-085718.212
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260811-083836.261
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260301-000148.812
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260401-000118.941
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260501-000117.569
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260601-000113.797
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260701-000123.299
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260715-122054.769
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260730-074558.958
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260801-000126.112
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260801-023748.913
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260804-002113.048
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260310-104039.598
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260310-104043.896
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260327-035946.131
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260401-134331.239
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260401-134351.152
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260401-134801.935
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260402-130810.683
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260406-133439.137
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260407-103738.086
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260408-112814.425
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260410-113707.504
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260410-113928.926
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260412-072844.925
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260413-213050.482
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260414-124143.245
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260415-122105.590
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260730-124155.792
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260811-083902.137
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260107-112924.635
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260730-074605.995
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260801-015903.674
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260811-083844.010
* ZZCI - Ubuntu 25.04 - builder - x86_64 - 20260110-020626.069
* ZZCI - Ubuntu 25.04 - builder - x86_64 - 20260730-081457.245
* ZZCI - Ubuntu 25.04 - builder - x86_64 - 20260801-031106.933
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260110-073610.713
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260730-074544.250
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260801-021912.436
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260811-083845.548
