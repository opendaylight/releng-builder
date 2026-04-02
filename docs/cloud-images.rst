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
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20251201-160153.193
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20251222-132742.475
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260101-004259.058
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260101-160145.340
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260106-082118.087
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260201-160148.214
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260301-160145.480
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260401-134916.347
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260401-160128.618
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20251201-160219.325
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20251222-042625.232
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260101-160222.557
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260201-160216.532
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
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20251112-123720.826
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20251112-140553.200
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20251201-010221.432
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20251218-031852.668
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20251218-074549.736
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20251219-003333.969
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20251221-131340.331
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20251222-013609.601
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260101-010223.593
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260109-084045.554
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260130-072415.125
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260131-081949.159
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260131-082035.554
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260201-010217.481
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260206-132531.854
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260301-010217.216
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260401-010115.623
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20251201-170117.678
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20251218-074548.712
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260101-170116.289
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260106-081619.527
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260122-064915.039
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260122-100236.109
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260128-013330.800
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260201-170120.782
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
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250917-133034.654
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260106-220203.734
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
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260107-112904.805
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260112-133959.552
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260206-132525.392
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260401-134551.965
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260401-134626.525
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20251113-144314.961
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20251201-000243.318
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20251218-021127.121
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260101-000218.322
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260111-003617.173
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260122-064921.352
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260128-013334.838
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260128-071531.791
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260201-000216.767
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260301-000148.812
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260401-000118.941
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260107-112911.047
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260310-104039.598
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260310-104043.896
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260327-035946.131
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260401-134331.239
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260401-134351.152
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260401-134801.935
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260107-112924.635
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260111-213636.378
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260112-015616.267
* ZZCI - Ubuntu 25.04 - builder - x86_64 - 20260110-020626.069
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260110-023738.938
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260110-073610.713
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260128-071530.935
