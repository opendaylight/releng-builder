| *Settings
| Library   | OperatingSystem
| Library   | SSHLibrary                               | prompt=]>
| Library   | ./test/csit/libraries/RequestsLibrary.py
| Variables | ./test/csit/variables/Variables.py

| *Keywords
| Get_Pcep_Topology |
|                   | ${resp}= | RequestsLibrary.Get | ses | topology/pcep-topology
|                   | Log      | ${resp}
|                   | Log      | ${resp.text}
|                   | [Return] | ${resp}
| Pcep_Off |
|          | ${resp}=                   | Get_Pcep_Topology
|          | Should_Be_Equal_As_Strings | ${resp.status_code} | 200
|          | Should_Be_Equal            | ${resp.text}        | {"topology":[{"topology-id":"pcep-topology","topology-types":{"network-topology-pcep:topology-pcep":{}}}]}
| Pcep_On |
|         | ${resp}=                   | Get_Pcep_Topology
|         | Should_Be_Equal_As_Strings | ${resp.status_code} | 200
|         | ${length}=                 | Evaluate            | len('''${resp.text}''')
|         | Should_Be_True             | ${length}>200
#         # More sophisticated logic is needed to tolerate ordering and base63 symbolic name.
| Wait_For_It | [Arguments]                 | ${it}
|             | Wait_Until_Keyword_Succeeds | 10s   | 1s | ${it}

| *TestCases
| Connect_To_Mininet |
|                    | Open_Connection       | ${MININET}
|                    | Login_With_Public_Key | ${MININET_USER} | ${USER_HOME}/.ssh/id_rsa | any
| Download_Pcc_Mock |
|                   | ${urlbase}=        | Set_Variable      | https://nexus.opendaylight.org/content/repositories/opendaylight.snapshot/org/opendaylight/bgpcep/pcep-pcc-mock
|                   | ${version}=        | Execute_Command   | curl ${urlbase}/maven-metadata.xml \| grep latest \| cut -d '>' -f 2 \| cut -d '<' -f 1
|                   | Log                | ${version}
|                   | ${namepart}=       | Execute_Command   | curl ${urlbase}/${version}/maven-metadata.xml \| grep value \| head -n 1 \| cut -d '>' -f 2 \| cut -d '<' -f 1
|                   | Log                | ${namepart}
|                   | Set_Suite_Variable | ${filename}       | pcep-pcc-mock-${namepart}-executable.jar
|                   | Log                | ${filename}
|                   | Write              | wget -q -N ${urlbase}/${version}/${filename}
|                   | ${response}=       | Read_Until_Prompt
|                   | Log                | ${response}
| Http_Session |
|              | Create_Session | ses | http://${CONTROLLER}:8181/restconf/operational/network-topology:network-topology | auth=${AUTH}
#              # TODO: define timeout
| Topology_Precondition |
|                       | [Tags]      | critical
|                       | Wait_For_It | Pcep_Off
| Start_Pcc_Mock |
|                | ${command}=  | Set_Variable | java -jar ${filename} --local-address ${MININET} --remote-address ${CONTROLLER} &>pccmock.log
|                | Log          | ${command}
|                | Write        | ${command}
| Topology_Intercondition |
|                         | [Tags]      | critical
|                         | Wait_For_It | Pcep_On
| Stop_Pcc_Mock |
|               | ${command}=           | Evaluate          | chr(int(3))
|               | Log                   | ${command}
|               | Write_Bare            | ${command}
|               | ${response}=          | Read_Until_Prompt
|               | Log                   | ${response}
|               | SSHLibrary.Get_File   | pccmock.log
|               | Close_All_Connections
| Topology_Postcondition |
|                        | [Tags]      | critical
|                        | Wait_For_It | Pcep_Off
# That is all for now.
