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

* ZZCI - CentOS 7 - builder - x86_64 - 20190403-205252.587
* ZZCI - CentOS 7 - builder - x86_64 - 20220101-060058.758
* ZZCI - CentOS 7 - builder - x86_64 - 20220401-060107.331
* ZZCI - CentOS 7 - builder - x86_64 - 20220811-110452.412
* ZZCI - CentOS 7 - builder - x86_64 - 20220830-004905.209
* ZZCI - CentOS 7 - builder - x86_64 - 20220915-210350.650
* ZZCI - CentOS 7 - builder - x86_64 - 20221016-222911.194
* ZZCI - CentOS 7 - builder - x86_64 - 20221201-060105.225
* ZZCI - CentOS 7 - builder - x86_64 - 20230301-060101.869
* ZZCI - CentOS 7 - builder - x86_64 - 20230401-060117.151
* ZZCI - CentOS 7 - builder - x86_64 - 20230501-060110.287
* ZZCI - CentOS 7 - builder - x86_64 - 20231213-090206.813
* ZZCI - CentOS 7 - builder - x86_64 - 20240101-060132.845
* ZZCI - CentOS 7 - builder - x86_64 - 20240201-060121.705
* ZZCI - CentOS 7 - builder - x86_64 - 20240221-041136.622
* ZZCI - CentOS 7 - builder - x86_64 - 20240306-105309.257
* ZZCI - CentOS 7 - builder - x86_64 - 20240401-060133.417
* ZZCI - CentOS 7 - builder - x86_64 - 20240501-060129.055
* ZZCI - CentOS 7 - builder - x86_64 - 20240601-060133.511
* ZZCI - CentOS 7 - builder - x86_64 - 20240701-060130.538
* ZZCI - CentOS 7 - devstack - x86_64 - 20220401-230107.511
* ZZCI - CentOS 7 - devstack - x86_64 - 20220915-220248.057
* ZZCI - CentOS 7 - devstack - x86_64 - 20221016-125752.520
* ZZCI - CentOS 7 - devstack - x86_64 - 20230301-230109.257
* ZZCI - CentOS 7 - devstack - x86_64 - 20230401-230106.445
* ZZCI - CentOS 7 - devstack - x86_64 - 20231213-111336.211
* ZZCI - CentOS 7 - devstack - x86_64 - 20240101-230119.558
* ZZCI - CentOS 7 - devstack - x86_64 - 20240201-230120.693
* ZZCI - CentOS 7 - devstack - x86_64 - 20240306-105306.072
* ZZCI - CentOS 7 - devstack - x86_64 - 20240401-230144.262
* ZZCI - CentOS 7 - devstack - x86_64 - 20240501-230129.155
* ZZCI - CentOS 7 - devstack - x86_64 - 20240601-230133.464
* ZZCI - CentOS 7 - devstack-rocky - 20190601-000116.015
* ZZCI - CentOS 7 - devstack-rocky - 20190628-065204.973
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20191002-183226.559
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20200801-000156.903
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20200811-042113.395
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20200813-042753.841
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20220401-000109.037
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20220811-110620.848
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20220915-220323.497
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20221016-125827.911
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20221101-000109.537
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220401-010109.230
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220811-110634.575
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220915-222435.096
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20221016-222956.928
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20221101-010107.368
* ZZCI - CentOS 7 - docker - x86_64 - 20220401-220102.840
* ZZCI - CentOS 7 - docker - x86_64 - 20220811-110637.413
* ZZCI - CentOS 7 - docker - x86_64 - 20220915-220324.722
* ZZCI - CentOS 7 - docker - x86_64 - 20221016-223020.545
* ZZCI - CentOS 7 - docker - x86_64 - 20221101-220103.978
* ZZCI - CentOS 7 - docker - x86_64 - 20221201-220105.396
* ZZCI - CentOS 7 - docker - x86_64 - 20230301-220107.956
* ZZCI - CentOS 7 - docker - x86_64 - 20230401-220108.252
* ZZCI - CentOS 7 - docker - x86_64 - 20230501-220111.311
* ZZCI - CentOS 7 - docker - x86_64 - 20231213-111103.823
* ZZCI - CentOS 7 - docker - x86_64 - 20240101-220119.494
* ZZCI - CentOS 7 - docker - x86_64 - 20240201-220125.685
* ZZCI - CentOS 7 - docker - x86_64 - 20240306-105301.772
* ZZCI - CentOS 7 - docker - x86_64 - 20240401-220152.097
* ZZCI - CentOS 7 - docker - x86_64 - 20240501-220134.070
* ZZCI - CentOS 7 - docker - x86_64 - 20240601-220142.195
* ZZCI - CentOS 7 - helm - x86_64 - 20220401-000138.473
* ZZCI - CentOS 7 - helm - x86_64 - 20220811-110654.568
* ZZCI - CentOS 7 - helm - x86_64 - 20220915-220356.090
* ZZCI - CentOS 7 - helm - x86_64 - 20221016-223030.291
* ZZCI - CentOS 7 - helm - x86_64 - 20221101-000135.064
* ZZCI - CentOS 7 - helm - x86_64 - 20230301-000133.034
* ZZCI - CentOS 7 - robot - 20190430-080312.962
* ZZCI - CentOS 7 - robot - x86_64 - 20220401-220138.484
* ZZCI - CentOS 7 - robot - x86_64 - 20220915-220357.338
* ZZCI - CentOS 7 - robot - x86_64 - 20221016-223041.341
* ZZCI - CentOS 7 - robot - x86_64 - 20221101-220138.675
* ZZCI - CentOS 7 - robot - x86_64 - 20221201-220143.533
* ZZCI - CentOS 7 - robot - x86_64 - 20230301-220131.480
* ZZCI - CentOS 7 - robot - x86_64 - 20230501-220152.957
* ZZCI - CentOS 7 - robot - x86_64 - 20240101-220154.458
* ZZCI - CentOS 7 - robot - x86_64 - 20240201-220154.217
* ZZCI - CentOS 7 - robot - x86_64 - 20240306-105302.366
* ZZCI - CentOS 7 - robot - x86_64 - 20240401-220244.081
* ZZCI - CentOS 7 - robot - x86_64 - 20240501-220214.317
* ZZCI - CentOS 7 - robot - x86_64 - 20240601-220241.858
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220303-223622.243
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220405-005246.199
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220411-013651.819
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220411-025029.496
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220601-071415.711
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220629-035812.822
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220701-160059.919
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220801-160143.906
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220811-073719.385
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20221016-222440.331
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20221101-160106.524
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20221201-160128.560
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230301-160121.204
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230401-160111.589
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230501-160107.084
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230727-135233.501
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230801-160108.418
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20231213-094027.766
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240117-011746.201
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240201-160121.488
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240309-064327.830
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240401-160147.446
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240501-160131.499
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240601-160217.263
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20220811-231817.668
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20230301-010147.625
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20230401-010209.151
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20231213-111243.663
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20240101-010215.978
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20240116-014504.639
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20240201-010245.776
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20240309-064350.911
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20240401-010224.970
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20240501-010211.041
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20240601-010231.803
* ZZCI - OPNFV - apex - compute - 0
* ZZCI - OPNFV - apex - compute - 1
* ZZCI - OPNFV - apex - controller - 0
* ZZCI - Ubuntu 16.04 - docker - x86_64 - 20190614-042302.610
* ZZCI - Ubuntu 16.04 - gbp - 20190521-223526.319
* ZZCI - Ubuntu 16.04 - kubernetes - 20190206-080347.936
* ZZCI - Ubuntu 16.04 - kubernetes - 20190211-225526.126
* ZZCI - Ubuntu 16.04 - mininet-ovs-25 - 20190416-121328.240
* ZZCI - Ubuntu 16.04 - mininet-ovs-26 - 20190521-223726.040
* ZZCI - Ubuntu 16.04 - mininet-ovs-28 - 20190415-091034.881
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220201-040158.287
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220501-040104.357
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220601-040059.617
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220701-040013.395
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20221001-040106.423
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20221201-040108.330
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230101-040125.332
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230301-040106.351
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230401-040112.177
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230501-040105.925
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240101-040145.675
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240201-040120.975
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240301-040012.681
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240306-000749.151
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240326-112125.840
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240501-040132.905
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240601-040134.455
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240701-040125.149
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240801-040132.691
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240901-040206.174
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20241201-040126.343
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20250201-040221.796
* ZZCI - Ubuntu 18.04 - helm -  - 20210513-214525.779
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220501-140101.102
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220811-112321.717
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220915-235325.735
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20221013-122339.021
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20221101-140104.772
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20221201-140107.142
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20230301-140059.950
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220201-180056.429
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220501-180100.971
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220601-180059.980
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220701-180056.799
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220801-180111.774
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220915-223016.788
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20221013-083654.129
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20221101-180142.920
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20221201-180114.186
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20230301-180106.402
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20230401-180107.945
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20230501-180106.320
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20230601-180106.003
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20240820-011010.709
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20240901-160214.010
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20241101-160217.260
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20241201-160151.330
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20250101-160150.998
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240326-112013.773
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240401-160246.269
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240501-160207.164
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240601-160305.840
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240701-160316.313
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240801-160217.825
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20241101-160234.899
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20241201-160228.779
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250101-160216.847
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250201-160239.450
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250918-232438.133
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20251201-160219.325
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260101-160222.557
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20250201-010426.857
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20250917-133034.447
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20251201-010221.432
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260101-010223.593
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20260109-084045.554
* ZZCI - Ubuntu 22.04 - devstack - x86_64 - 20231031-095146.118
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250201-170115.786
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250918-232437.783
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20251201-170117.678
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260101-170116.289
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20241024-123714.311
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20241101-060158.442
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20241201-060156.310
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250201-060151.911
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250917-133034.654
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20251218-021127.121
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260111-003617.173
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260107-112924.635
* ZZCI - Ubuntu 25.04 - builder - x86_64 - 20260110-020626.069
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260110-073610.713
