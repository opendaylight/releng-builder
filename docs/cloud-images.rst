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
* ZZCI - CentOS 7 - builder - x86_64 - 20220111-144716.525
* ZZCI - CentOS 7 - builder - x86_64 - 20220301-060057.135
* ZZCI - CentOS 7 - builder - x86_64 - 20220401-060107.331
* ZZCI - CentOS 7 - builder - x86_64 - 20220810-225406.343
* ZZCI - CentOS 7 - builder - x86_64 - 20220811-110452.412
* ZZCI - CentOS 7 - builder - x86_64 - 20220819-072649.912
* ZZCI - CentOS 7 - builder - x86_64 - 20220819-080137.911
* ZZCI - CentOS 7 - builder - x86_64 - 20220820-140848.474
* ZZCI - CentOS 7 - builder - x86_64 - 20220822-075914.017
* ZZCI - CentOS 7 - builder - x86_64 - 20220823-013925.749
* ZZCI - CentOS 7 - builder - x86_64 - 20220830-004905.209
* ZZCI - CentOS 7 - builder - x86_64 - 20220901-060109.345
* ZZCI - CentOS 7 - builder - x86_64 - 20220907-132047.940
* ZZCI - CentOS 7 - builder - x86_64 - 20220915-210350.650
* ZZCI - CentOS 7 - builder - x86_64 - 20221014-230023.599
* ZZCI - CentOS 7 - builder - x86_64 - 20221016-222911.194
* ZZCI - CentOS 7 - builder - x86_64 - 20221201-060105.225
* ZZCI - CentOS 7 - builder - x86_64 - 20230101-060216.811
* ZZCI - CentOS 7 - builder - x86_64 - 20230201-060101.214
* ZZCI - CentOS 7 - builder - x86_64 - 20230301-060101.869
* ZZCI - CentOS 7 - builder - x86_64 - 20230401-060117.151
* ZZCI - CentOS 7 - builder - x86_64 - 20230501-060110.287
* ZZCI - CentOS 7 - builder - x86_64 - 20230601-060110.935
* ZZCI - CentOS 7 - builder - x86_64 - 20230704-035758.434
* ZZCI - CentOS 7 - builder - x86_64 - 20230704-231647.894
* ZZCI - CentOS 7 - builder - x86_64 - 20230705-030716.304
* ZZCI - CentOS 7 - builder - x86_64 - 20230727-135136.536
* ZZCI - CentOS 7 - builder - x86_64 - 20230801-060019.513
* ZZCI - CentOS 7 - builder - x86_64 - 20231101-060112.760
* ZZCI - CentOS 7 - builder - x86_64 - 20231201-060138.152
* ZZCI - CentOS 7 - builder - x86_64 - 20231213-090206.813
* ZZCI - CentOS 7 - builder - x86_64 - 20240101-060132.845
* ZZCI - CentOS 7 - builder - x86_64 - 20240113-042050.976
* ZZCI - CentOS 7 - builder - x86_64 - 20240201-060121.705
* ZZCI - CentOS 7 - builder - x86_64 - 20240219-114353.897
* ZZCI - CentOS 7 - builder - x86_64 - 20240221-041136.622
* ZZCI - CentOS 7 - builder - x86_64 - 20240306-105309.257
* ZZCI - CentOS 7 - builder - x86_64 - 20240401-060133.417
* ZZCI - CentOS 7 - builder - x86_64 - 20240501-060129.055
* ZZCI - CentOS 7 - builder - x86_64 - 20240601-060133.511
* ZZCI - CentOS 7 - builder - x86_64 - 20240701-060130.538
* ZZCI - CentOS 7 - devstack - x86_64 - 20220101-230058.589
* ZZCI - CentOS 7 - devstack - x86_64 - 20220201-230056.942
* ZZCI - CentOS 7 - devstack - x86_64 - 20220301-230058.722
* ZZCI - CentOS 7 - devstack - x86_64 - 20220401-230107.511
* ZZCI - CentOS 7 - devstack - x86_64 - 20220811-121546.186
* ZZCI - CentOS 7 - devstack - x86_64 - 20220820-140909.636
* ZZCI - CentOS 7 - devstack - x86_64 - 20220901-230104.671
* ZZCI - CentOS 7 - devstack - x86_64 - 20220915-220248.057
* ZZCI - CentOS 7 - devstack - x86_64 - 20221016-125752.520
* ZZCI - CentOS 7 - devstack - x86_64 - 20221016-222927.029
* ZZCI - CentOS 7 - devstack - x86_64 - 20221101-230058.297
* ZZCI - CentOS 7 - devstack - x86_64 - 20221201-230100.993
* ZZCI - CentOS 7 - devstack - x86_64 - 20230101-230102.471
* ZZCI - CentOS 7 - devstack - x86_64 - 20230301-230109.257
* ZZCI - CentOS 7 - devstack - x86_64 - 20230401-230106.445
* ZZCI - CentOS 7 - devstack - x86_64 - 20230501-230108.249
* ZZCI - CentOS 7 - devstack - x86_64 - 20230601-230111.995
* ZZCI - CentOS 7 - devstack - x86_64 - 20230704-071950.633
* ZZCI - CentOS 7 - devstack - x86_64 - 20230704-231855.554
* ZZCI - CentOS 7 - devstack - x86_64 - 20230705-030745.231
* ZZCI - CentOS 7 - devstack - x86_64 - 20230801-230101.799
* ZZCI - CentOS 7 - devstack - x86_64 - 20230901-230104.760
* ZZCI - CentOS 7 - devstack - x86_64 - 20231101-230112.779
* ZZCI - CentOS 7 - devstack - x86_64 - 20231201-230119.963
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
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20220201-000059.096
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20220401-000109.037
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20220811-110620.848
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20220820-140815.053
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20220901-000115.345
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20220915-220323.497
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20221001-000125.021
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20221016-125827.911
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20221016-222946.596
* ZZCI - CentOS 7 - devstack-rocky - x86_64 - 20221101-000109.537
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220101-010055.379
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220201-010057.671
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220301-010057.901
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220401-010109.230
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220811-110634.575
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220820-140904.945
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220901-010110.645
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20220915-222435.096
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20221001-010112.580
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20221016-125853.236
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20221016-222956.928
* ZZCI - CentOS 7 - devstack-stein - x86_64 - 20221101-010107.368
* ZZCI - CentOS 7 - docker - x86_64 - 20220101-220056.424
* ZZCI - CentOS 7 - docker - x86_64 - 20220301-220058.873
* ZZCI - CentOS 7 - docker - x86_64 - 20220401-220102.840
* ZZCI - CentOS 7 - docker - x86_64 - 20220811-110637.413
* ZZCI - CentOS 7 - docker - x86_64 - 20220820-140835.603
* ZZCI - CentOS 7 - docker - x86_64 - 20220901-220115.450
* ZZCI - CentOS 7 - docker - x86_64 - 20220915-220324.722
* ZZCI - CentOS 7 - docker - x86_64 - 20221016-125857.924
* ZZCI - CentOS 7 - docker - x86_64 - 20221016-223020.545
* ZZCI - CentOS 7 - docker - x86_64 - 20221101-220103.978
* ZZCI - CentOS 7 - docker - x86_64 - 20221201-220105.396
* ZZCI - CentOS 7 - docker - x86_64 - 20230101-220102.401
* ZZCI - CentOS 7 - docker - x86_64 - 20230201-220101.397
* ZZCI - CentOS 7 - docker - x86_64 - 20230301-220107.956
* ZZCI - CentOS 7 - docker - x86_64 - 20230401-220108.252
* ZZCI - CentOS 7 - docker - x86_64 - 20230501-220111.311
* ZZCI - CentOS 7 - docker - x86_64 - 20230601-220118.447
* ZZCI - CentOS 7 - docker - x86_64 - 20230704-232308.886
* ZZCI - CentOS 7 - docker - x86_64 - 20230705-030900.684
* ZZCI - CentOS 7 - docker - x86_64 - 20230801-220107.983
* ZZCI - CentOS 7 - docker - x86_64 - 20230901-220113.905
* ZZCI - CentOS 7 - docker - x86_64 - 20231101-220126.544
* ZZCI - CentOS 7 - docker - x86_64 - 20231201-220117.630
* ZZCI - CentOS 7 - docker - x86_64 - 20231213-111103.823
* ZZCI - CentOS 7 - docker - x86_64 - 20240101-220119.494
* ZZCI - CentOS 7 - docker - x86_64 - 20240201-220125.685
* ZZCI - CentOS 7 - docker - x86_64 - 20240306-105301.772
* ZZCI - CentOS 7 - docker - x86_64 - 20240401-220152.097
* ZZCI - CentOS 7 - docker - x86_64 - 20240501-220134.070
* ZZCI - CentOS 7 - docker - x86_64 - 20240601-220142.195
* ZZCI - CentOS 7 - helm - x86_64 - 20220101-000245.680
* ZZCI - CentOS 7 - helm - x86_64 - 20220201-000216.309
* ZZCI - CentOS 7 - helm - x86_64 - 20220301-000153.945
* ZZCI - CentOS 7 - helm - x86_64 - 20220401-000138.473
* ZZCI - CentOS 7 - helm - x86_64 - 20220811-110654.568
* ZZCI - CentOS 7 - helm - x86_64 - 20220820-140759.388
* ZZCI - CentOS 7 - helm - x86_64 - 20220901-000209.780
* ZZCI - CentOS 7 - helm - x86_64 - 20220915-220356.090
* ZZCI - CentOS 7 - helm - x86_64 - 20221001-000200.263
* ZZCI - CentOS 7 - helm - x86_64 - 20221016-125903.888
* ZZCI - CentOS 7 - helm - x86_64 - 20221016-223030.291
* ZZCI - CentOS 7 - helm - x86_64 - 20221101-000135.064
* ZZCI - CentOS 7 - helm - x86_64 - 20221201-000156.559
* ZZCI - CentOS 7 - helm - x86_64 - 20230101-000202.908
* ZZCI - CentOS 7 - helm - x86_64 - 20230201-000150.906
* ZZCI - CentOS 7 - helm - x86_64 - 20230301-000133.034
* ZZCI - CentOS 7 - robot - 20190430-080312.962
* ZZCI - CentOS 7 - robot - x86_64 - 20220101-220155.904
* ZZCI - CentOS 7 - robot - x86_64 - 20220201-220158.098
* ZZCI - CentOS 7 - robot - x86_64 - 20220301-220158.535
* ZZCI - CentOS 7 - robot - x86_64 - 20220401-220138.484
* ZZCI - CentOS 7 - robot - x86_64 - 20220810-232749.807
* ZZCI - CentOS 7 - robot - x86_64 - 20220811-110550.401
* ZZCI - CentOS 7 - robot - x86_64 - 20220812-075756.317
* ZZCI - CentOS 7 - robot - x86_64 - 20220812-083902.135
* ZZCI - CentOS 7 - robot - x86_64 - 20220812-094957.303
* ZZCI - CentOS 7 - robot - x86_64 - 20220820-140917.191
* ZZCI - CentOS 7 - robot - x86_64 - 20220901-220215.283
* ZZCI - CentOS 7 - robot - x86_64 - 20220915-220357.338
* ZZCI - CentOS 7 - robot - x86_64 - 20221016-125928.502
* ZZCI - CentOS 7 - robot - x86_64 - 20221016-223041.341
* ZZCI - CentOS 7 - robot - x86_64 - 20221101-220138.675
* ZZCI - CentOS 7 - robot - x86_64 - 20221201-220143.533
* ZZCI - CentOS 7 - robot - x86_64 - 20230101-220136.107
* ZZCI - CentOS 7 - robot - x86_64 - 20230201-220137.499
* ZZCI - CentOS 7 - robot - x86_64 - 20230301-220131.480
* ZZCI - CentOS 7 - robot - x86_64 - 20230501-220152.957
* ZZCI - CentOS 7 - robot - x86_64 - 20231213-085842.829
* ZZCI - CentOS 7 - robot - x86_64 - 20240101-220154.458
* ZZCI - CentOS 7 - robot - x86_64 - 20240201-220154.217
* ZZCI - CentOS 7 - robot - x86_64 - 20240306-105302.366
* ZZCI - CentOS 7 - robot - x86_64 - 20240401-220244.081
* ZZCI - CentOS 7 - robot - x86_64 - 20240501-220214.317
* ZZCI - CentOS 7 - robot - x86_64 - 20240601-220241.858
* ZZCI - CentOS 8 - builder - x86_64 - 20220120-034829.872
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220303-223622.243
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220405-005246.199
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220411-013651.819
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220411-025029.496
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220529-013534.987
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220529-071509.022
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220530-071355.713
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220531-013211.735
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220531-063337.840
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220531-224633.332
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220601-071415.711
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220613-134645.697
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220614-084733.693
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220614-144051.771
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220615-085941.905
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220624-083106.115
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220628-213526.810
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220629-035812.822
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220701-160059.919
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220801-160143.906
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220809-222649.751
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220811-073719.385
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220820-140912.396
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220822-082754.255
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20220901-160108.529
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20221006-022838.351
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20221006-073542.895
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20221006-122155.975
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20221013-083604.413
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20221016-222440.331
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20221101-160106.524
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20221201-160128.560
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230101-160105.035
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230201-160105.789
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230301-160121.204
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230401-160111.589
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230501-160107.084
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230601-160103.902
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230615-124923.578
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230615-143739.719
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230622-044330.771
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230704-070951.083
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230704-074500.124
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230704-231742.101
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230705-031120.321
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230727-135233.501
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20230801-160108.418
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20231213-094027.766
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240113-025342.932
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240117-011746.201
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240201-160121.488
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240309-064327.830
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240401-160147.446
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240422-114205.616
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240501-160131.499
* ZZCI - CentOS Stream 8 - builder - x86_64 - 20240601-160217.263
* ZZCI - CentOS Stream 8 - devstack - x86_64 - 20230615-144631.086
* ZZCI - CentOS Stream 8 - devstack - x86_64 - 20230616-022013.197
* ZZCI - CentOS Stream 8 - devstack - x86_64 - 20230622-095519.460
* ZZCI - CentOS Stream 8 - devstack-yoga - x86_64 - 20230612-132235.763
* ZZCI - CentOS Stream 8 - docker - x86_64 - 20230622-074859.494
* ZZCI - CentOS Stream 8 - docker - x86_64 - 20230628-010335.272
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20220811-231817.668
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20220812-010324.169
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20220812-083859.067
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20220812-095028.046
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20220820-140917.407
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20220901-010210.262
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20221013-083714.503
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20221016-222525.576
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20221101-010205.652
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20221201-010130.764
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20230301-010147.625
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20230401-010209.151
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20230501-010136.955
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20230601-010312.253
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20231212-131123.272
* ZZCI - CentOS Stream 8 - robot - x86_64 - 20231212-205015.151
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
* ZZCI - Ubuntu 18.04 - builder - x86_64 - 20221007-002022.069
* ZZCI - Ubuntu 18.04 - builder - x86_64 - 20221013-122906.855
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220101-040224.236
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220201-040158.287
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220501-040104.357
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220601-040059.617
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220701-040013.395
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220820-140903.631
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20220901-040105.453
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20221001-040106.423
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20221007-005229.346
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20221201-040108.330
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230101-040125.332
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230301-040106.351
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230401-040112.177
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230501-040105.925
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230601-040106.064
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230705-040401.005
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20230801-040013.057
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20231001-040111.487
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20231101-040111.232
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20231201-040141.663
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240101-040145.675
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240113-063344.327
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240201-040120.975
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240301-040012.681
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240306-000749.151
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240326-112125.840
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240501-040132.905
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240601-040134.455
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240701-040125.149
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240801-040132.691
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20240901-040206.174
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20241001-040016.924
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20241201-040126.343
* ZZCI - Ubuntu 18.04 - docker - x86_64 - 20250201-040221.796
* ZZCI - Ubuntu 18.04 - helm -  - 20210513-214525.779
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220101-140055.317
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220301-140057.429
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220501-140101.102
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220811-112321.717
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220820-140830.234
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220822-133446.819
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220823-072905.739
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220901-140108.107
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20220915-235325.735
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20221001-140105.764
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20221013-122339.021
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20221101-140104.772
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20221201-140107.142
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20230101-140111.577
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20230201-140254.859
* ZZCI - Ubuntu 18.04 - helm - x86_64 - 20230301-140059.950
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220101-180057.408
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220201-180056.429
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220301-180056.439
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220401-180112.933
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220501-180100.971
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220601-180059.980
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220701-180056.799
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220801-180111.774
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220822-121130.566
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220823-221257.462
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220823-230942.092
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220824-011831.391
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220824-015145.461
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220824-075630.483
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20220915-223016.788
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20221001-180117.617
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20221013-083654.129
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20221101-180142.920
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20221201-180114.186
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20230101-180105.478
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20230201-180130.689
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20230301-180106.402
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20230401-180107.945
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20230501-180106.320
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20230601-180106.003
* ZZCI - Ubuntu 18.04 - mininet-ovs-28 - x86_64 - 20241003-030624.701
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20221007-005406.181
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20240820-011010.709
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20240901-160214.010
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20241101-160217.260
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20241201-160151.330
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20250101-160150.998
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20250911-215052.528
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20250912-070234.437
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20250912-111554.028
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20250917-024623.680
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20250917-081238.941
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20250917-111151.037
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20250917-123736.491
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20250917-133033.733
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20251201-160153.193
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20251222-132742.475
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260101-004259.058
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260101-160145.340
* ZZCI - Ubuntu 20.04 - builder - x86_64 - 20260106-082118.087
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20220915-223019.580
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20221001-160243.052
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20221101-160134.323
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20221201-160152.784
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20230201-160134.122
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20230401-160201.097
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20230501-160135.014
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20230601-160210.077
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20230801-160224.175
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20230901-160210.845
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20231001-160200.664
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20231101-160245.725
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20231201-160303.189
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240101-160226.547
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240201-160202.956
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240222-233219.906
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240301-160225.120
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240326-112013.773
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240401-160246.269
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240501-160207.164
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240601-160305.840
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240701-160316.313
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20240801-160217.825
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20241001-160433.873
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20241101-160234.899
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20241201-160228.779
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250101-160216.847
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250201-160239.450
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250911-215052.495
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250912-070234.517
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250912-111553.103
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250917-081240.080
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250917-111150.111
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250917-123734.997
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250917-133034.135
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20250918-232438.133
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20251201-160219.325
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20251222-042625.232
* ZZCI - Ubuntu 20.04 - docker - x86_64 - 20260101-160222.557
* ZZCI - Ubuntu 20.04 - helm - x86_64 - 20220822-133458.742
* ZZCI - Ubuntu 20.04 - helm - x86_64 - 20220823-072908.932
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20241101-010217.526
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20241201-010238.135
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20250101-010353.200
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20250201-010426.857
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20250912-111553.450
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20250917-024623.647
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20250917-081238.881
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20250917-111150.465
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20250917-123735.275
* ZZCI - Ubuntu 22.04 - builder - x86_64 - 20250917-133034.447
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
* ZZCI - Ubuntu 22.04 - devstack - x86_64 - 20231031-095146.118
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20241101-170124.472
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20241201-170125.221
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250101-170123.209
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250201-170115.786
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250911-141845.411
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250911-215052.506
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250912-070234.430
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250912-111553.084
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250917-081240.003
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250917-111151.094
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250917-123736.210
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250917-133033.926
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20250918-232437.783
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20251201-170117.678
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20251218-074548.712
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260101-170116.289
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260106-081619.527
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260122-064915.039
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260122-100236.109
* ZZCI - Ubuntu 22.04 - docker - x86_64 - 20260128-013330.800
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20241017-230817.684
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20241018-001946.358
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20241018-225955.645
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20241024-123714.311
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20241101-060158.442
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20241201-060156.310
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250101-060219.146
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250201-060151.911
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250912-070234.419
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250912-111553.366
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250917-081239.394
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250917-111150.605
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250917-123736.879
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20250917-133034.654
* ZZCI - Ubuntu 22.04 - mininet-ovs-217 - x86_64 - 20260106-220203.734
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260107-112904.805
* ZZCI - Ubuntu 22.04 - robot - x86_64 - 20260112-133959.552
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20250912-111552.496
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20250917-123735.362
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20250917-133035.097
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20251113-144314.961
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20251201-000243.318
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20251218-021127.121
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260101-000218.322
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260111-003617.173
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260122-064921.352
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260128-013334.838
* ZZCI - Ubuntu 24.04 - builder - x86_64 - 20260128-071531.791
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20250912-111552.731
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20250917-111149.216
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20250917-123735.583
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20250917-133033.619
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20250918-232438.050
* ZZCI - Ubuntu 24.04 - mininet-ovs-217 - x86_64 - 20260107-112911.047
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260107-112924.635
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260111-213636.378
* ZZCI - Ubuntu 24.04 - robot - x86_64 - 20260112-015616.267
* ZZCI - Ubuntu 25.04 - builder - x86_64 - 20260110-020626.069
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260110-023738.938
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260110-073610.713
* ZZCI - Ubuntu 25.04 - docker - x86_64 - 20260128-071530.935
