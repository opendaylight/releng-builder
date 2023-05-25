# Bumping MRI versions tool

This program is making versions changes in pom.xml files. For example 10.0.1 to 10.0.2. The change will apply if groupId.text contain "org.opendaylight".
This program is also making changes in feature.xml files. For example [0.16,1) to [0.17,1)

## Installing

_Prerequisite:_

- Python 3.8+

GET THE CODE:

USING HTTPS:
git clone "https://git.opendaylight.org/gerrit/releng/builder"

USING SSH:
git clone "ssh://{USERNAME}@git.opendaylight.org:29418/releng/builder"

NAVIGATE TO:
cd ~/builder/scripts/bump_mri_versions

INSTALL VIRTUAL ENVIROMENT PACKAGE:
sudo apt install python3-virtualenv

CREATE NEW VIRTUAL ENVIROMENT:
virtualenv venv

ACTIVATE VIRTUAL ENVIROMENT:
. venv/bin/activate

INSTALL LIBRARIES:
pip install requests bs4 lxml

SET FOLDER FOR TESTING:
clone repo for version updating in ~/builder/scripts/bump_mri_versions/repos or
update "bumping_dir" variable in python_lib.py file

## Running

RUN: python main.py

## Logs

PRINT:
All changes will be output to the console.

    examples here:

    XML FILE: repos/aaa/features/odl-aaa-api/pom.xml
    ('groupId:', 'org.opendaylight.mdsal', 'ARTIFACT ID:', 'odl-mdsal-binding-base', 'VERSION:', '11.0.1', 'NEW VERSION:', '11.0.2')
    ****************************************************************************************************

    XML FILE: repos/ovsdb/southbound/southbound-features/odl-ovsdb-southbound-impl/src/main/feature/feature.xml
    ('path:', PosixPath('repos/ovsdb/southbound/southbound-features/odl-ovsdb-southbound-impl/src/main/feature/feature.xml'), 'VERSION:', '[4,5)', 'NEW VERSION:', '[5,6)')
    ****************************************************************************************************
