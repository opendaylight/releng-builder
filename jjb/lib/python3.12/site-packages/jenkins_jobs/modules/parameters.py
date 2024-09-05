# Copyright 2012 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.


"""
The Parameters module allows you to specify build parameters for a job.

**Component**: parameters
  :Macro: parameter
  :Entry Point: jenkins_jobs.parameters

Example::

  job:
    name: test_job

    parameters:
      - string:
          name: FOO
          default: bar
          description: "A parameter named FOO, defaults to 'bar'."
"""

import xml.etree.ElementTree as XML

from jenkins_jobs.loc_loader import LocList
from jenkins_jobs.errors import JenkinsJobsException
from jenkins_jobs.errors import MissingAttributeError
from jenkins_jobs.errors import InvalidAttributeError
import jenkins_jobs.modules.base
import jenkins_jobs.modules.helpers as helpers


def base_param(registry, xml_parent, data, do_default, ptype):
    pdef = XML.SubElement(xml_parent, ptype)
    XML.SubElement(pdef, "name").text = data["name"]
    XML.SubElement(pdef, "description").text = data.get("description", "")
    if do_default:
        default = data.get("default", None)
        if default is not None:
            XML.SubElement(pdef, "defaultValue").text = str(default)
        else:
            XML.SubElement(pdef, "defaultValue")
    return pdef


def string_param(registry, xml_parent, data):
    """yaml: string
    A string parameter.

    :arg str name: the name of the parameter
    :arg str default: the default value of the parameter (optional)
    :arg str description: a description of the parameter (optional)
    :arg bool trim: strip whitespaces from the begnning and end
        of the string (optional, default: false)

    Example::

      parameters:
        - string:
            name: FOO
            default: bar
            description: "A parameter named FOO, defaults to 'bar'."
            trim: true
    """
    pdef = base_param(
        registry, xml_parent, data, True, "hudson.model.StringParameterDefinition"
    )

    mapping = [("trim", "trim", False)]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def promoted_param(registry, xml_parent, data):
    """yaml: promoted build
    A promoted build parameter.

    Requires the Jenkins :jenkins-plugins:`Promoted Builds Plugin
    <promoted-builds>`.

    :arg str name: the name of the parameter (required)
    :arg str project-name: the job from which the user can pick runs (required)
    :arg str promotion-name: promotion process to choose from (optional)
    :arg str description: a description of the parameter (optional)

    Example:

    .. literalinclude::
        /../../tests/parameters/fixtures/promoted-build-param001.yaml
       :language: yaml

    """
    pdef = base_param(
        registry,
        xml_parent,
        data,
        False,
        "hudson.plugins.promoted__builds.parameters."
        "PromotedBuildParameterDefinition",
    )
    try:
        XML.SubElement(pdef, "projectName").text = data["project-name"]
    except KeyError:
        raise MissingAttributeError("project-name")

    XML.SubElement(pdef, "promotionProcessName").text = data.get("promotion-name", None)


def password_param(registry, xml_parent, data):
    """yaml: password
    A password parameter.

    :arg str name: the name of the parameter
    :arg str default: the default value of the parameter (optional)
    :arg str description: a description of the parameter (optional)

    Example::

      parameters:
        - password:
            name: FOO
            default: 1HSC0Ts6E161FysGf+e1xasgsHkgleLh09JUTYnipPvw=
            description: "A parameter named FOO."
    """
    base_param(
        registry, xml_parent, data, True, "hudson.model.PasswordParameterDefinition"
    )


def bool_param(registry, xml_parent, data):
    """yaml: bool
    A boolean parameter.

    :arg str name: the name of the parameter
    :arg str default: the default value of the parameter (optional)
    :arg str description: a description of the parameter (optional)

    Example::

      parameters:
        - bool:
            name: FOO
            default: false
            description: "A parameter named FOO, defaults to 'false'."
    """
    data["default"] = str(data.get("default", False)).lower()
    base_param(
        registry, xml_parent, data, True, "hudson.model.BooleanParameterDefinition"
    )


def file_param(registry, xml_parent, data):
    """yaml: file
    A file parameter.

    :arg str name: the target location for the file upload
    :arg str description: a description of the parameter (optional)

    Example::

      parameters:
        - file:
            name: test.txt
            description: "Upload test.txt."
    """
    base_param(
        registry, xml_parent, data, False, "hudson.model.FileParameterDefinition"
    )


def text_param(registry, xml_parent, data):
    """yaml: text
    A text parameter.

    :arg str name: the name of the parameter
    :arg str default: the default value of the parameter (optional)
    :arg str description: a description of the parameter (optional)

    Example::

      parameters:
        - text:
            name: FOO
            default: bar
            description: "A parameter named FOO, defaults to 'bar'."
    """
    base_param(registry, xml_parent, data, True, "hudson.model.TextParameterDefinition")


def label_param(registry, xml_parent, data):
    """yaml: label
    A node label parameter.

    :arg str name: the name of the parameter
    :arg str default: the default value of the parameter (optional)
    :arg str description: a description of the parameter (optional)
    :arg bool all-nodes: to run job on all nodes matching label
        in parallel (default: false)
    :arg str matching-label: to run all nodes matching label
        'success', 'unstable' or 'allCases' (optional)
    :arg str node-eligibility: all nodes, ignore temporary nodes or
        ignore temporary offline nodes (optional, default all nodes)

    Example:

    .. literalinclude::  /../../tests/parameters/fixtures/node-label001.yaml
       :language: yaml

    """

    pdef = base_param(
        registry,
        xml_parent,
        data,
        True,
        "org.jvnet.jenkins.plugins.nodelabelparameter." "LabelParameterDefinition",
    )

    valid_types = ["allCases", "success", "unstable"]
    mapping = [
        ("all-nodes", "allNodesMatchingLabel", False),
        ("matching-label", "triggerIfResult", "allCases", valid_types),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)

    eligibility_label = data.get("node-eligibility", "all").lower()
    eligibility_label_dict = {
        "all": "org.jvnet.jenkins.plugins."
        "nodelabelparameter.node."
        "AllNodeEligibility",
        "ignore-offline": "org.jvnet.jenkins.plugins."
        "nodelabelparameter.node."
        "IgnoreOfflineNodeEligibility",
        "ignore-temp-offline": "org.jvnet.jenkins.plugins."
        "nodelabelparameter.node."
        "IgnoreTempOfflineNodeEligibility",
    }
    if eligibility_label not in eligibility_label_dict:
        raise InvalidAttributeError(
            eligibility_label, eligibility_label, eligibility_label_dict.keys()
        )

    XML.SubElement(pdef, "nodeEligibility").set(
        "class", eligibility_label_dict[eligibility_label]
    )


def node_param(registry, xml_parent, data):
    """yaml: node
    Defines a list of nodes where this job could potentially be executed on.
    Restrict where this project can be run, If your using a node or label
    parameter to run your job on a particular node, you should not use the
    option "Restrict where this project can be run" in the job configuration
    - it will not have any effect to the selection of your node anymore!

    :arg str name: the name of the parameter
    :arg str description: a description of the parameter (optional)
    :arg list default-slaves: The nodes used when job gets triggered
        by anything else other than manually
    :arg list allowed-slaves: The nodes available for selection
        when job gets triggered manually. Empty means 'All'.
    :arg bool ignore-offline-nodes: Ignore nodes not online or not having
        executors (default false)
    :arg bool allowed-multiselect: Allow multi node selection for concurrent
        builds - this option only makes sense (and must be selected!) in
        case the job is configured with: "Execute concurrent builds if
        necessary". With this configuration the build will be executed on all
        the selected nodes in parallel. (default false)

    Example:

    .. literalinclude::  /../../tests/parameters/fixtures/node-param001.yaml
       :language: yaml

    """
    pdef = base_param(
        registry,
        xml_parent,
        data,
        False,
        "org.jvnet.jenkins.plugins.nodelabelparameter." "NodeParameterDefinition",
    )
    default = XML.SubElement(pdef, "defaultSlaves")
    if "default-slaves" in data:
        for slave in data["default-slaves"]:
            XML.SubElement(default, "string").text = slave
    allowed = XML.SubElement(pdef, "allowedSlaves")
    if "allowed-slaves" in data:
        for slave in data["allowed-slaves"]:
            XML.SubElement(allowed, "string").text = slave
    XML.SubElement(pdef, "ignoreOfflineNodes").text = str(
        data.get("ignore-offline-nodes", False)
    ).lower()

    if data.get("allowed-multiselect", False):
        XML.SubElement(
            pdef, "triggerIfResult"
        ).text = "allowMultiSelectionForConcurrentBuilds"
    else:
        XML.SubElement(pdef, "triggerIfResult").text = "multiSelectionDisallowed"
    XML.SubElement(pdef, "allowMultiNodeSelection").text = str(
        data.get("allowed-multiselect", False)
    ).lower()
    XML.SubElement(pdef, "triggerConcurrentBuilds").text = str(
        data.get("allowed-multiselect", False)
    ).lower()


def choice_param(registry, xml_parent, data):
    """yaml: choice
    A single selection parameter.

    :arg str name: the name of the parameter
    :arg list choices: the available choices, first one is the default one.
    :arg str description: a description of the parameter (optional)

    Example::

      parameters:
        - choice:
            name: project
            choices:
              - nova
              - glance
            description: "On which project to run?"
    """
    pdef = base_param(
        registry, xml_parent, data, False, "hudson.model.ChoiceParameterDefinition"
    )
    choices = XML.SubElement(pdef, "choices", {"class": "java.util.Arrays$ArrayList"})
    a = XML.SubElement(choices, "a", {"class": "string-array"})
    for choice in data["choices"]:
        XML.SubElement(a, "string").text = choice


def credentials_param(registry, xml_parent, data):
    """yaml: credentials
    A credentials selection parameter.

    Requires the Jenkins :jenkins-plugins:`Credentials Plugin <credentials>`.

    :arg str name: the name of the parameter
    :arg str type: credential type (optional, default 'any')

        :Allowed Values: * **any** Any credential type (default)
                    * **usernamepassword** Username with password
                    * **sshkey** SSH Username with private key
                    * **secretfile** Secret file
                    * **secrettext** Secret text
                    * **certificate** Certificate

    :arg bool required: whether this parameter is required (optional, default
        false)
    :arg str default: default credentials ID (optional)
    :arg str description: a description of the parameter (optional)

    Example:

    .. literalinclude:: \
    /../../tests/parameters/fixtures/credentials-param001.yaml
       :language: yaml

    """
    cred_impl_types = {
        "any": "com.cloudbees.plugins.credentials.common.StandardCredentials",
        "usernamepassword": "com.cloudbees.plugins.credentials.impl."
        + "UsernamePasswordCredentialsImpl",
        "sshkey": "com.cloudbees.jenkins.plugins.sshcredentials.impl."
        + "BasicSSHUserPrivateKey",
        "secretfile": "org.jenkinsci.plugins.plaincredentials.impl."
        + "FileCredentialsImpl",
        "secrettext": "org.jenkinsci.plugins.plaincredentials.impl."
        + "StringCredentialsImpl",
        "certificate": "com.cloudbees.plugins.credentials.impl."
        + "CertificateCredentialsImpl",
    }

    cred_type = data.get("type", "any").lower()
    if cred_type not in cred_impl_types:
        raise InvalidAttributeError("type", cred_type, cred_impl_types.keys())

    pdef = base_param(
        registry,
        xml_parent,
        data,
        False,
        "com.cloudbees.plugins.credentials." + "CredentialsParameterDefinition",
    )
    XML.SubElement(pdef, "defaultValue").text = data.get("default", "")
    XML.SubElement(pdef, "credentialType").text = cred_impl_types[cred_type]
    XML.SubElement(pdef, "required").text = str(data.get("required", False)).lower()


def run_param(registry, xml_parent, data):
    """yaml: run
    A run parameter.

    :arg str name: the name of the parameter
    :arg str project-name: the name of job from which the user can pick runs
    :arg str description: a description of the parameter (optional)

    Example:

    .. literalinclude::  /../../tests/parameters/fixtures/run-param001.yaml
       :language: yaml

    """
    pdef = base_param(
        registry, xml_parent, data, False, "hudson.model.RunParameterDefinition"
    )
    mapping = [("project-name", "projectName", None)]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


@helpers.check_mutual_exclusive_data_args(
    2, "value", "property-file", "groovy-script", "groovy-script-file"
)
@helpers.check_mutual_exclusive_data_args(
    2, "default-value", "default-property-file", "default-groovy-script"
)
@helpers.check_mutual_exclusive_data_args(
    2,
    "value-description",
    "description-property-file",
    "description-groovy-script",
    "description-groovy-script-file",
)
@helpers.check_mutual_exclusive_data_args(2, "javascript", "javascript-file")
def extended_choice_param(registry, xml_parent, data):
    """yaml: extended-choice
    Creates an extended choice parameter where values can be read from a file

    Requires the Jenkins :jenkins-plugins:`Extended Choice Parameter Plugin
    <extended-choice-parameter>`.

    :arg str name: name of the parameter
    :arg str description: description of the parameter
        (optional, default '')
    :arg str property-file: location of property file to read from
        (optional, default '')
    :arg str property-key: key for the property-file (optional, default '')
    :arg bool quote-value: whether to put quotes around the property
        when passing to Jenkins (optional, default false)
    :arg str visible-items: number of items to show in the list
        (optional, default 5)
    :arg str type: type of select, can be single-select, multi-select,
        multi-level-single-select, multi-level-multi-select,
        radio, checkbox, textbox, json (optional, default single-select)
    :arg str value: comma separated list of values for the single select
        or multi-select box (optional, default '')
    :arg str default-value: used to set the initial selection of the
        single-select or multi-select box (optional, default '')
    :arg str value-description: comma separated list of value descriptions
        for the single select or multi-select box (optional, default '')
    :arg str default-property-file: location of property file when default
        value needs to come from a property file (optional, default '')
    :arg str default-property-key: key for the default property file
        (optional, default '')
    :arg str description-property-file: location of property file when value
        description needs to come from a property file (optional, default '')
    :arg str description-property-key: key for the value description
        property file (optional, default '')
    :arg str multi-select-delimiter: value between selections when the
        parameter is a multi-select (optional, default ',')
    :arg str groovy-script: the groovy script contents (optional, default ',')
    :arg str groovy-script-file: location of groovy script file to generate
        parameters (optional, default '')
    :arg str bindings: variable bindings for the groovy script
        (optional, default '')
    :arg str classpath: the classpath for the groovy script
        (optional, default ',')
    :arg str default-groovy-script: the default groovy
        script contents (optional, default '')
    :arg str default-groovy-classpath: the default classpath for the
        groovy script (optional, default '')
    :arg str description-groovy-script: location of groovy script when value
        description needs to come from a groovy script (optional, default '')
    :arg str description-groovy-script-file: location of groovy script file when value
        description needs to come from a groovy script (optional, default '')
    :arg str description-groovy-classpath: classpath for the value description
        groovy script (optional, default '')
    :arg str javascript: the javascript script contents (optional, default '')
    :arg str javascript-file: location of javasript script file to generate
        parameters (optional, default '')
    :arg bool save-json-parameter-to-file: if json parameter should be saved
        to file (optional, default False)

    Minimal Example:

        .. literalinclude:: \
        /../../tests/parameters/fixtures/extended-choice-param-minimal.yaml
           :language: yaml

    Full Example:

        .. literalinclude:: \
        /../../tests/parameters/fixtures/extended-choice-param-full.yaml
           :language: yaml
    """
    pdef = base_param(
        registry,
        xml_parent,
        data,
        False,
        "com.cwctravel.hudson.plugins."
        "extended__choice__parameter."
        "ExtendedChoiceParameterDefinition",
    )

    choicedict = {
        "single-select": "PT_SINGLE_SELECT",
        "multi-select": "PT_MULTI_SELECT",
        "multi-level-single-select": "PT_MULTI_LEVEL_SINGLE_SELECT",
        "multi-level-multi-select": "PT_MULTI_LEVEL_MULTI_SELECT",
        "radio": "PT_RADIO",
        "checkbox": "PT_CHECKBOX",
        "textbox": "PT_TEXTBOX",
        "json": "PT_JSON",
        "PT_SINGLE_SELECT": "PT_SINGLE_SELECT",
        "PT_MULTI_SELECT": "PT_MULTI_SELECT",
        "PT_MULTI_LEVEL_SINGLE_SELECT": "PT_MULTI_LEVEL_SINGLE_SELECT",
        "PT_MULTI_LEVEL_MULTI_SELECT": "PT_MULTI_LEVEL_MULTI_SELECT",
        "PT_RADIO": "PT_RADIO",
        "PT_CHECKBOX": "PT_CHECKBOX",
        "PT_TEXTBOX": "PT_TEXTBOX",
        "PT_JSON": "PT_JSON",
    }
    mapping = [
        ("value", "value", ""),
        ("visible-items", "visibleItemCount", 5),
        ("multi-select-delimiter", "multiSelectDelimiter", ","),
        ("quote-value", "quoteValue", False),
        ("default-value", "defaultValue", ""),
        ("value-description", "descriptionPropertyValue", ""),
        ("type", "type", "single-select", choicedict),
        ("property-file", "propertyFile", ""),
        ("property-key", "propertyKey", ""),
        ("default-property-file", "defaultPropertyFile", ""),
        ("default-property-key", "defaultPropertyKey", ""),
        ("description-property-file", "descriptionPropertyFile", ""),
        ("description-property-key", "descriptionPropertyKey", ""),
        ("bindings", "bindings", ""),
        ("groovy-script", "groovyScript", ""),
        ("groovy-script-file", "groovyScriptFile", ""),
        ("classpath", "groovyClasspath", ""),
        ("default-groovy-script", "defaultGroovyScript", ""),
        ("default-groovy-classpath", "defaultGroovyClasspath", ""),
        ("description-groovy-script", "descriptionGroovyScript", ""),
        ("description-groovy-script-file", "descriptionGroovyScriptFile", ""),
        ("description-groovy-classpath", "descriptionGroovyClasspath", ""),
        ("javascript", "javascript", ""),
        ("javascript-file", "javascriptFile", ""),
        ("save-json-parameter-to-file", "saveJSONParameterToFile", False),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def validating_string_param(registry, xml_parent, data):
    """yaml: validating-string
    A validating string parameter

    Requires the Jenkins :jenkins-plugins:`Validating String Plugin
    <validating-string-parameter>`.

    :arg str name: the name of the parameter
    :arg str default: the default value of the parameter (optional)
    :arg str description: a description of the parameter (optional)
    :arg str regex: a regular expression to validate the string
    :arg str msg: a message to display upon failed validation

    Example::

      parameters:
        - validating-string:
            name: FOO
            default: bar
            description: "A parameter named FOO, defaults to 'bar'."
            regex: [A-Za-z]*
            msg: Your entered value failed validation
    """
    pdef = base_param(
        registry,
        xml_parent,
        data,
        True,
        "hudson.plugins.validating__string__parameter."
        "ValidatingStringParameterDefinition",
    )
    mapping = [("regex", "regex", None), ("msg", "failedValidationMessage", None)]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def svn_tags_param(registry, xml_parent, data):
    """yaml: svn-tags
    A svn tag parameter

    Requires the Jenkins :jenkins-plugins:`Parameterized Trigger Plugin
    <parameterized-trigger>`.

    :arg str name: the name of the parameter
    :arg str url: the url to list tags from
    :arg str credentials-id: Credentials ID to use for authentication
        (default '')
    :arg str filter: the regular expression to filter tags (default '')
    :arg str default: the default value of the parameter (default '')
    :arg str description: a description of the parameter (default '')
    :arg int max-tags: the number of tags to display (default '100')
    :arg bool sort-newest-first: sort tags from newest to oldest (default true)
    :arg bool sort-z-to-a: sort tags in reverse alphabetical order
        (default false)

    Example::

      parameters:
        - svn-tags:
            name: BRANCH_NAME
            default: release
            description: A parameter named BRANCH_NAME default is release
            url: http://svn.example.org/repo
            filter: [A-za-z0-9]*
    """
    pdef = base_param(
        registry,
        xml_parent,
        data,
        True,
        "hudson.scm.listtagsparameter." "ListSubversionTagsParameterDefinition",
    )
    mapping = [
        ("url", "tagsDir", None),
        ("credentials-id", "credentialsId", ""),
        ("filter", "tagsFilter", ""),
        ("max-tags", "maxTags", "100"),
        ("sort-newest-first", "reverseByDate", True),
        ("sort-z-to-a", "reverseByName", False),
        ("", "uuid", "1-1-1-1-1"),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def dynamic_choice_param(registry, xml_parent, data):
    """yaml: dynamic-choice
    Dynamic Choice Parameter

    Requires the Jenkins :jenkins-plugins:`Jenkins Dynamic Parameter Plug-in
    <dynamicparameter>`.

    :arg str name: the name of the parameter
    :arg str description: a description of the parameter (optional)
    :arg str script: Groovy expression which generates the potential choices.
    :arg bool remote: the script will be executed on the slave where the build
        is started (default false)
    :arg str classpath: class path for script (optional)
    :arg bool read-only: user can't modify parameter once populated
        (default false)

    Example::

      parameters:
        - dynamic-choice:
            name: OPTIONS
            description: "Available options"
            script: "['optionA', 'optionB']"
            remote: false
            read-only: false
    """
    dynamic_param_common(registry, xml_parent, data, "ChoiceParameterDefinition")


def dynamic_string_param(registry, xml_parent, data):
    """yaml: dynamic-string
    Dynamic Parameter

    Requires the Jenkins :jenkins-plugins:`Jenkins Dynamic Parameter Plug-in
    <dynamicparameter>`.

    :arg str name: the name of the parameter
    :arg str description: a description of the parameter (optional)
    :arg str script: Groovy expression which generates the potential choices
    :arg bool remote: the script will be executed on the slave where the build
        is started (default false)
    :arg str classpath: class path for script (optional)
    :arg bool read-only: user can't modify parameter once populated
        (default false)

    Example::

      parameters:
        - dynamic-string:
            name: FOO
            description: "A parameter named FOO, defaults to 'bar'."
            script: "bar"
            remote: false
            read-only: false
    """
    dynamic_param_common(registry, xml_parent, data, "StringParameterDefinition")


def dynamic_choice_scriptler_param(registry, xml_parent, data):
    """yaml: dynamic-choice-scriptler
    Dynamic Choice Parameter (Scriptler)

    Requires the Jenkins :jenkins-plugins:`Jenkins Dynamic Parameter Plug-in
    <dynamicparameter>`.

    :arg str name: the name of the parameter
    :arg str description: a description of the parameter (optional)
    :arg str script-id: Groovy script which generates the default value
    :arg list parameters: parameters to corresponding script

        :Parameter: * **name** (`str`) Parameter name
                    * **value** (`str`) Parameter value
    :arg bool remote: the script will be executed on the slave where the build
        is started (default false)
    :arg bool read-only: user can't modify parameter once populated
        (default false)

    Example::

      parameters:
        - dynamic-choice-scriptler:
            name: OPTIONS
            description: "Available options"
            script-id: "scriptid.groovy"
            parameters:
              - name: param1
                value: value1
              - name: param2
                value: value2
            remote: false
            read-only: false
    """
    dynamic_scriptler_param_common(
        registry, xml_parent, data, "ScriptlerChoiceParameterDefinition"
    )


def dynamic_string_scriptler_param(registry, xml_parent, data):
    """yaml: dynamic-string-scriptler
    Dynamic Parameter (Scriptler)

    Requires the Jenkins :jenkins-plugins:`Jenkins Dynamic Parameter Plug-in
    <dynamicparameter>`.

    :arg str name: the name of the parameter
    :arg str description: a description of the parameter (optional)
    :arg str script-id: Groovy script which generates the default value
    :arg list parameters: parameters to corresponding script

        :Parameter: * **name** (`str`) Parameter name
                    * **value** (`str`) Parameter value
    :arg bool remote: the script will be executed on the slave where the build
        is started (default false)
    :arg bool read-only: user can't modify parameter once populated
        (default false)

    Example::

      parameters:
        - dynamic-string-scriptler:
            name: FOO
            description: "A parameter named FOO, defaults to 'bar'."
            script-id: "scriptid.groovy"
            parameters:
              - name: param1
                value: value1
              - name: param2
                value: value2
            remote: false
            read-only: false
    """
    dynamic_scriptler_param_common(
        registry, xml_parent, data, "ScriptlerStringParameterDefinition"
    )


def dynamic_param_common(registry, xml_parent, data, ptype):
    pdef = base_param(
        registry,
        xml_parent,
        data,
        False,
        "com.seitenbau.jenkins.plugins.dynamicparameter." + ptype,
    )
    XML.SubElement(pdef, "__remote").text = str(data.get("remote", False)).lower()
    XML.SubElement(pdef, "__script").text = data.get("script", None)
    localBaseDir = XML.SubElement(
        pdef, "__localBaseDirectory", {"serialization": "custom"}
    )
    filePath = XML.SubElement(localBaseDir, "hudson.FilePath")
    default = XML.SubElement(filePath, "default")
    XML.SubElement(filePath, "boolean").text = "true"
    XML.SubElement(
        default, "remote"
    ).text = "/var/lib/jenkins/dynamic_parameter/classpath"
    XML.SubElement(pdef, "__remoteBaseDirectory").text = "dynamic_parameter_classpath"
    XML.SubElement(pdef, "__classPath").text = data.get("classpath", None)
    XML.SubElement(pdef, "readonlyInputField").text = str(
        data.get("read-only", False)
    ).lower()


def dynamic_scriptler_param_common(registry, xml_parent, data, ptype):
    pdef = base_param(
        registry,
        xml_parent,
        data,
        False,
        "com.seitenbau.jenkins.plugins.dynamicparameter." "scriptler." + ptype,
    )
    parametersXML = XML.SubElement(pdef, "__parameters")
    parameters = data.get("parameters", [])
    if parameters:
        mapping = [("name", "name", None), ("value", "value", None)]
        for parameter in parameters:
            parameterXML = XML.SubElement(
                parametersXML,
                "com.seitenbau.jenkins.plugins."
                "dynamicparameter.scriptler."
                "ScriptlerParameterDefinition_"
                "-ScriptParameter",
            )
            helpers.convert_mapping_to_xml(
                parameterXML, parameter, mapping, fail_required=True
            )
    mapping = [
        ("script-id", "__scriptlerScriptId", None),
        ("remote", "__remote", False),
        ("read-only", "readonlyInputField", False),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def matrix_combinations_param(registry, xml_parent, data):
    """yaml: matrix-combinations
    Matrix combinations parameter

    Requires the Jenkins :jenkins-plugins:`Matrix Combinations Plugin
    <matrix-combinations-parameter>`.

    :arg str name: the name of the parameter
    :arg str description: a description of the parameter (optional)
    :arg str filter: Groovy expression to use filter the combination by
        default (optional)

    Example:

    .. literalinclude:: \
    /../../tests/parameters/fixtures/matrix-combinations-param001.yaml
       :language: yaml

    """
    element_name = (
        "hudson.plugins.matrix__configuration__parameter."
        "MatrixCombinationsParameterDefinition"
    )
    pdef = XML.SubElement(xml_parent, element_name)

    mapping = [
        ("name", "name", None),
        ("description", "description", ""),
        ("filter", "defaultCombinationFilter", ""),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)

    return pdef


def copyartifact_build_selector_param(registry, xml_parent, data):
    """yaml: copyartifact-build-selector

    Control via a build parameter, which build the copyartifact plugin should
    copy when it is configured to use 'build-param'.

    Requires the Jenkins :jenkins-plugins:`Copy Artifact plugin <copyartifact>`.

    :arg str name: name of the build parameter to store the selection in
    :arg str description: a description of the parameter (optional)
    :arg str which-build: which to provide as the default value in the UI. See
        ``which-build`` param of :py:mod:`~builders.copyartifact` from the
        builders module for the available values as well as options available
        that control additional behaviour for the selected value.

    Example:

    .. literalinclude::
        /../../tests/parameters/fixtures/copyartifact-build-selector001.yaml
       :language: yaml

    """

    t = XML.SubElement(
        xml_parent, "hudson.plugins.copyartifact." "BuildSelectorParameter"
    )
    mapping = [("name", "name", None), ("description", "description", "")]
    helpers.convert_mapping_to_xml(t, data, mapping, fail_required=True)

    helpers.copyartifact_build_selector(t, data, "defaultSelector")


def maven_metadata_param(registry, xml_parent, data):
    """yaml: maven-metadata
    This parameter allows the resolution of maven artifact versions
    by contacting the repository and reading the maven-metadata.xml.

    Requires the Jenkins :jenkins-plugins:`Maven Metadata Plugin
    <maven-metadata-plugin>`.

    :arg str name: Name of the parameter
    :arg str description: Description of the parameter (optional)
    :arg str repository-base-url: URL from where you retrieve your artifacts
        (default '')
    :arg str repository-username: Repository's username if authentication is
        required. (default '')
    :arg str repository-password: Repository's password if authentication is
        required. (default '')
    :arg str artifact-group-id: Unique project identifier (default '')
    :arg str artifact-id: Name of the artifact without version (default '')
    :arg str packaging: Artifact packaging option. Could be something such as
        jar, zip, pom.... (default '')
    :arg str versions-filter: Specify a regular expression which will be used
        to filter the versions which are actually displayed when triggering a
        new build. (default '')
    :arg str default-value: For features such as SVN polling a default value
        is required. If job will only be started manually, this field is not
        necessary. (default '')
    :arg str maximum-versions-to-display: The maximum number of versions to
        display in the drop-down. Any non-number value as well as 0 or negative
        values will default to all. (default 10)
    :arg str sorting-order: ascending or descending
        (default descending)

    Example:

    .. literalinclude::
       /../../tests/parameters/fixtures/maven-metadata-param001.yaml
       :language: yaml

    """
    pdef = base_param(
        registry,
        xml_parent,
        data,
        False,
        "eu.markov.jenkins.plugin.mvnmeta." "MavenMetadataParameterDefinition",
    )
    mapping = [
        ("repository-base-url", "repoBaseUrl", ""),
        ("artifact-group-id", "groupId", ""),
        ("artifact-id", "artifactId", ""),
        ("packaging", "packaging", ""),
        ("default-value", "defaultValue", ""),
        ("versions-filter", "versionFilter", ""),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)

    sort_order = data.get("sorting-order", "descending").lower()
    sort_dict = {"descending": "DESC", "ascending": "ASC"}

    if sort_order not in sort_dict:
        raise InvalidAttributeError(sort_order, sort_order, sort_dict.keys())

    XML.SubElement(pdef, "sortOrder").text = sort_dict[sort_order]
    mapping = [
        ("maximum-versions-to-display", "maxVersions", 10),
        ("repository-username", "username", ""),
        ("repository-password", "password", ""),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def hidden_param(parser, xml_parent, data):
    """yaml: hidden
    Allows you to use parameters hidden from the build with parameter page.

    Requires the Jenkins :jenkins-plugins:`Hidden Parameter Plugin
    <hidden-parameter>`.

    :arg str name: the name of the parameter
    :arg str default: the default value of the parameter (optional)
    :arg str description: a description of the parameter (optional)

    Example:

    .. literalinclude::
       /../../tests/parameters/fixtures/hidden-param001.yaml
       :language: yaml

    """
    base_param(
        parser, xml_parent, data, True, "com.wangyin.parameter.WHideParameterDefinition"
    )


def random_string_param(registry, xml_parent, data):
    """yaml: random-string
    This parameter generates a random string and passes it to the
    build, preventing Jenkins from combining queued builds.

    Requires the Jenkins :jenkins-plugins:`Random String Parameter Plugin
    <random-string-parameter>`.

    :arg str name: Name of the parameter
    :arg str description: Description of the parameter (default '')
    :arg str failed-validation-message: Failure message to display for invalid
        input (default '')

    Example:

    .. literalinclude::
       /../../tests/parameters/fixtures/random-string-param001.yaml
       :language: yaml
    """
    pdef = XML.SubElement(
        xml_parent,
        "hudson.plugins.random__string__parameter." "RandomStringParameterDefinition",
    )
    if "name" not in data:
        raise JenkinsJobsException("random-string must have a name parameter.")

    mapping = [
        ("name", "name", None),
        ("description", "description", ""),
        ("failed-validation-message", "failedValidationMessage", ""),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def git_parameter_param(registry, xml_parent, data):
    """yaml: git-parameter
    This parameter allows you to select a git tag, branch or revision number as
    parameter in Parametrized builds.

    Requires the Jenkins :jenkins-plugins:`Git Parameter Plugin
    <git-parameter>`.

    :arg str name: Name of the parameter
    :arg str description: Description of the parameter (default '')
    :arg str type: The type of the list of parameters (default 'PT_TAG')

        :Allowed Values: * **PT_TAG** list of all commit tags in repository -
                        returns Tag Name
                    * **PT_BRANCH** list of all branches in repository -
                        returns Branch Name
                    * **PT_BRANCH_TAG** list of all commit tags and all
                        branches in repository - returns Tag Name or Branch
                        Name
                    * **PT_REVISION** list of all revision sha1 in repository
                        followed by its author and date - returns Tag SHA1
                    * **PT_PULL_REQUEST**

    :arg str branch: Name of branch to look in. Used only if listing
        revisions.  (default '')
    :arg str branchFilter: Regex used to filter displayed branches. If blank,
        the filter will default to ".*". Remote branches will be listed with
        the remote name first. E.g., "origin/master"  (default '.*')
    :arg str tagFilter: Regex used to filter displayed branches. If blank, the
        filter will default to ".*". Remote branches will be listed with the
        remote name first. E.g., "origin/master"  (default '*')
    :arg str sortMode: Mode of sorting.  (default 'NONE')

        :Allowed Values: * **NONE**
                    * **DESCENDING**
                    * **ASCENDING**
                    * **ASCENDING_SMART**
                    * **DESCENDING_SMART**

    :arg str defaultValue: This value is returned when list is empty. (default
        '')
    :arg str selectedValue: Which value is selected, after loaded parameters.
        If you choose 'default', but default value is not present on the list,
        nothing is selected. (default 'NONE')

        :Allowed Values: * **NONE**
                    * **TOP**
                    * **DEFAULT**

    :arg str useRepository: If in the task is defined multiple repositories
        parameter specifies which the repository is taken into account. If the
        parameter is not defined, is taken first defined repository. The
        parameter is a regular expression which is compared with a URL
        repository. (default '')
    :arg bool quickFilterEnabled: When this option is enabled will show a text
        field. Parameter is filtered on the fly. (default false)

    Minimal Example:

    .. literalinclude::
       /../../tests/parameters/fixtures/git-parameter-param-minimal.yaml
       :language: yaml

    Full Example:

    .. literalinclude::
       /../../tests/parameters/fixtures/git-parameter-param-full.yaml
       :language: yaml
    """
    pdef = XML.SubElement(
        xml_parent,
        "net.uaznia.lukanus.hudson.plugins.gitparameter." "GitParameterDefinition",
    )

    valid_types = [
        "PT_TAG",
        "PT_BRANCH",
        "PT_BRANCH_TAG",
        "PT_REVISION",
        "PT_PULL_REQUEST",
    ]

    valid_sort_modes = [
        "NONE",
        "ASCENDING",
        "ASCENDING_SMART",
        "DESCENDING",
        "DESCENDING_SMART",
    ]

    valid_selected_values = ["NONE", "TOP", "DEFAULT"]

    mapping = [
        ("name", "name", None),
        ("description", "description", ""),
        ("type", "type", "PT_TAG", valid_types),
        ("branch", "branch", ""),
        ("tagFilter", "tagFilter", "*"),
        ("branchFilter", "branchFilter", ".*"),
        ("sortMode", "sortMode", "NONE", valid_sort_modes),
        ("defaultValue", "defaultValue", ""),
        ("selectedValue", "selectedValue", "NONE", valid_selected_values),
        ("useRepository", "useRepository", ""),
        ("quickFilterEnabled", "quickFilterEnabled", False),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def param_separator(registry, xml_parent, data):
    """yaml: parameter-separator
    A parameter separator.

    :arg str name: name of the separator (default "", the plugin will assign a randomly generated UUID if not specified)
    :arg str separator-style: the style of the separator. Uses CSS. (default "")
    :arg str section-header-text: the section header text of the separator (default "")
    :arg str section-header-style: the section header style (CSS) of the separator. Uses CSS. (default "")

    Example::

      parameters:
        - parameter-separator:
            name: lorem
            separator-style: FOO
            section-header: bar
            section-header-style: font-weight:bold;z-index:10000
    """
    element_name = "jenkins.plugins.parameter__separator.ParameterSeparatorDefinition"
    pdef = XML.SubElement(xml_parent, element_name)
    XML.SubElement(pdef, "description")  # To create empty description tag
    mapping = [
        ("name", "name", ""),
        ("section-header", "sectionHeader", ""),
        ("section-header-style", "sectionHeaderStyle", ""),
        ("separator-style", "separatorStyle", ""),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def __handle_unochoice_script(data, pdef, script_type, main_script_xml):

    if script_type == "script":
        secure_script_xml = XML.SubElement(main_script_xml, "secureScript")
    elif script_type == "fallback-script":
        secure_script_xml = XML.SubElement(main_script_xml, "secureFallbackScript")

    sub_script_xml = XML.SubElement(secure_script_xml, "script")
    groovy_sandbox_xml = XML.SubElement(secure_script_xml, "sandbox")

    script = data.get(script_type, {})
    sub_script_xml.text = script.get("groovy", "")
    groovy_sandbox_xml.text = str(script.get("use-groovy-sandbox", True)).lower()

    if "script-additional-classpath" in script:
        classpath_xml = XML.SubElement(secure_script_xml, "classpath")
        for additional_classpath in script.get("script-additional-classpath"):
            entry_xml = XML.SubElement(classpath_xml, "entry")
            url_xml = XML.SubElement(entry_xml, "url")
            url_xml.text = additional_classpath


def active_choices_param(registry, xml_parent, data):
    """yaml: active-choices
    Active Choices Parameter

    Requires the Jenkins :jenkins-plugins:`Active Choices Plug-in
    <uno-choice>`.

    :arg str name: Name of the parameter (required).
    :arg str description: Description of the parameter.
    :arg list script: Use a Groovy script to define the parameter.

        :Parameter: * **groovy** (`str`) Groovy DSL Script
                    * **use-groovy-sandbox** (`bool`) To run this
                        Groovy script in a sandbox with limited abilities
                        (default True)
                    * **script-additional-classpath** (`list`) Additional
                        classpath entries accessible from the script.
    :arg list fallback-script: Use a Fallback script. If the script
        (specified above) fails, the fallback script will be used as a fallback.

        :Parameter: * **groovy** (`str`) Groovy DSL Script
                    * **use-groovy-sandbox** (`bool`) To run this Groovy
                        script in a sandbox with limited abilities.
                        (default True)
                    * **script-additional-classpath** (`list`) Additional
                        classpath entries accessible from the script.
    :arg bool enable-filters: If enabled a text box will appear next to
        this element and will permit the user to filter its entries. The
        list values never get re-evaluated (default False).
    :arg int filter-starts-at: How many characters a user must enter
        before the filter is applied (default 1).
    :arg str choice-type: type of the choices. (default 'single-select')

        :Allowed Values: * **single-select**
                    * **multi-select**
                    * **radio-buttons**
                    * **checkboxes**

    Minimal Example:

    .. literalinclude::
        /../../tests/yamlparser/job_fixtures/active-choices-param001.yaml
       :language: yaml

    Full Example:

    .. literalinclude::
        /../../tests/yamlparser/job_fixtures/active-choices-param002.yaml
       :language: yaml
    """
    element_name = "org.biouno.unochoice.ChoiceParameter"
    pdef = XML.SubElement(xml_parent, element_name)

    __active_choice_param_internal(pdef, data)


def active_choices_reactive_param(registry, xml_parent, data):
    """yaml: active-choices-reactive
    Active Choices Reactive Parameter

    Requires the Jenkins :jenkins-plugins:`Active Choices Plug-in
    <uno-choice>`.

    :arg str name: Name of the parameter (required).
    :arg str description: Description of the parameter.
    :arg list script: Use a Groovy script to define the parameter.

        :Parameter: * **groovy** (`str`) Groovy DSL Script
                    * **use-groovy-sandbox** (`bool`) To run this
                        Groovy script in a sandbox with limited abilities
                        (default True)
                    * **script-additional-classpath** (`list`) Additional
                        classpath entries accessible from the script.
    :arg list fallback-script: Use a Fallback script. If the script
        (specified above) fails, the fallback script will be used as a fallback.

        :Parameter: * **groovy** (`str`) Groovy DSL Script
                    * **use-groovy-sandbox** (`bool`) To run this Groovy
                        script in a sandbox with limited abilities.
                        (default True)
                    * **script-additional-classpath** (`list`) Additional
                        classpath entries accessible from the script.
    :arg bool enable-filters: If enabled a text box will appear next to
        this element and will permit the user to filter its entries. The
        list values never get re-evaluated (default False).
    :arg int filter-starts-at: How many characters a user must enter
        before the filter is applied (default 1).
    :arg str choice-type: type of the choices. (default 'single-select')

        :Allowed Values: * **single-select**
                    * **multi-select**
                    * **radio-buttons**
                    * **checkboxes**
    :arg str referenced-parameters: Comma separated list of other job
        parameters referenced in the uno-choice script

    Minimal Example:

    .. literalinclude::
        /../../tests/yamlparser/job_fixtures/active-choices-reactive-param001.yaml
       :language: yaml

    Full Example:

    .. literalinclude::
        /../../tests/yamlparser/job_fixtures/active-choices-reactive-param002.yaml
       :language: yaml
    """

    element_name = "org.biouno.unochoice.CascadeChoiceParameter"
    pdef = XML.SubElement(xml_parent, element_name)

    __active_choice_param_internal(pdef, data)

    mapping = [
        ("referenced-parameters", "referencedParameters", ""),
        ("random-name", "randomName", "choice-param-{0}".format(data["name"]).lower()),
        ("visible-items", "visibleItemCount", 1),
    ]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=False)
    XML.SubElement(pdef, "parameters", {"class": "linked-hash-map"})


def __active_choice_param_internal(xml_parent, data):
    valid_choice_types_dict = {
        "single-select": "PT_SINGLE_SELECT",
        "multi-select": "PT_MULTI_SELECT",
        "radio-buttons": "PT_RADIO",
        "checkboxes": "PT_CHECKBOX",
    }

    mapping = [
        ("name", "name", None),
        ("description", "description", ""),
        ("choice-type", "choiceType", "single-select", valid_choice_types_dict),
        ("enable-filters", "filterable", False),
        ("filter-starts-at", "filterLength", 1),
        ("_project-name", "projectName", None),
        ("_project-full-name", "projectFullName", None),
    ]

    main_script_xml = XML.SubElement(xml_parent, "script")
    main_script_xml.set("class", "org.biouno.unochoice.model.GroovyScript")
    __handle_unochoice_script(data, xml_parent, "fallback-script", main_script_xml)
    __handle_unochoice_script(data, xml_parent, "script", main_script_xml)

    helpers.convert_mapping_to_xml(xml_parent, data, mapping, fail_required=True)


def dynamic_reference_param(registry, xml_parent, data):
    """yaml: dynamic-reference
    Active Choices Reactive Reference Parameter

    Requires the Jenkins :jenkins-plugins:`Active Choices Plug-in
    <uno-choice>`.

    :arg str name: Name of the parameter (required).
    :arg str description: Description of the parameter.
    :arg list script: Use a Groovy script to define the parameter.

        :Parameter: * **groovy** (`str`) Groovy DSL Script
                    * **use-groovy-sandbox** (`bool`) To run this
                        Groovy script in a sandbox with limited abilities
                        (default True)
                    * **script-additional-classpath** (`list`) Additional
                        classpath entries accessible from the script.
    :arg list fallback-script: Use a Fallback script. If the script
        (specified above) fails, the fallback script will be used as a fallback.

        :Parameter: * **groovy** (`str`) Groovy DSL Script
                    * **use-groovy-sandbox** (`bool`) To run this Groovy
                        script in a sandbox with limited abilities.
                        (default True)
                    * **script-additional-classpath** (`list`) Additional
                        classpath entries accessible from the script.
    :arg bool omit-value-field: By default Dynamic Reference Parameters always
        include a hidden input for the value. If your script creates an input
        HTML element, you can check this option and the value input field will
        be omitted (default False).
    :arg str referenced-parameters: Comma separated list of other job
         parameters referenced in the uno-choice script. When any of the
         referenced parameters are updated, the Groovy script will
         re-evaluate the choice list using the updated values of referenced
         parameters.
    :arg str choice-type: type of the choices. (default 'input-text-box')

        :Allowed Values: * **input-text-box**
                    * **numbered-list**
                    * **bullet-items-list**
                    * **formatted-html**
                    * **formatted-hidden-html**

    Minimal Example:

    .. literalinclude::
        /../../tests/yamlparser/job_fixtures/dynamic-reference-param001.yaml
       :language: yaml

    Full Example:

    .. literalinclude::
        /../../tests/yamlparser/job_fixtures/dynamic-reference-param002.yaml
       :language: yaml
    """
    element_name = "org.biouno.unochoice.DynamicReferenceParameter"
    pdef = XML.SubElement(xml_parent, element_name)

    valid_choice_types_dict = {
        "input-text-box": "ET_TEXT_BOX",
        "numbered-list": "ET_ORDERED_LIST",
        "bullet-items-list": "ET_UNORDERED_LIST",
        "formatted-html": "ET_FORMATTED_HTML",
        "formatted-hidden-html": "ET_FORMATTED_HIDDEN_HTML",
    }

    mapping = [
        ("name", "name", None),
        ("description", "description", ""),
        ("choice-type", "choiceType", "input-text-box", valid_choice_types_dict),
        ("_project-name", "projectName", None),
        ("_project-full-name", "projectFullName", None),
        ("referenced-parameters", "referencedParameters", ""),
        ("omit-value-field", "omitValueField", False),
    ]

    main_script_xml = XML.SubElement(pdef, "script")
    main_script_xml.set("class", "org.biouno.unochoice.model.GroovyScript")
    __handle_unochoice_script(data, pdef, "fallback-script", main_script_xml)
    __handle_unochoice_script(data, pdef, "script", main_script_xml)

    XML.SubElement(pdef, "parameters")  # Empty parameters tag

    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def persistent_string_param(registry, xml_parent, data):
    """yaml: persistent-string
    A persistent string parameter.

    Requires the Jenkins :jenkins-plugins:`Persistent Parameter Plugin
    <persistent-parameter>`.

    :arg str name: the name of the parameter
    :arg str default: the default value of the parameter (optional)
    :arg str description: a description of the parameter (optional)
    :arg bool trim: strip whitespaces from the begnning and end
        of the string (optional, default: false)
    :arg bool successfulOnly: if true, then the value of the parameter
        gets persisted only between successful builds
        (optional, default: false)

    Example::

      parameters:
        - persistent-string:
            name: FOO
            default: bar
            description: "A parameter named FOO, defaults to 'bar'."
            trim: false
            successfulOnly: false
    """
    pdef = base_param(
        registry,
        xml_parent,
        data,
        True,
        "com.gem.persistentparameter.PersistentStringParameterDefinition",
    )

    mapping = [("trim", "trim", False), ("successfulOnly", "successfulOnly", False)]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def persistent_bool_param(registry, xml_parent, data):
    """yaml: persistent-bool
    A persistent boolean parameter.

    Requires the Jenkins :jenkins-plugins:`Persistent Parameter Plugin
    <persistent-parameter>`.

    :arg str name: the name of the parameter
    :arg str default: the default value of the parameter (optional)
    :arg str description: a description of the parameter (optional)
    :arg bool successfulOnly: if true, then the value of the parameter
        gets persisted only between successful builds
        (optional, default: false)

    Example::

      parameters:
        - persistent-bool:
            name: FOO
            default: false
            description: "A persistent parameter named FOO, defaults to 'false'."
            successfulOnly: false
    """
    data["default"] = str(data.get("default", False)).lower()
    pdef = base_param(
        registry,
        xml_parent,
        data,
        True,
        "com.gem.persistentparameter.PersistentBooleanParameterDefinition",
    )

    mapping = [("successfulOnly", "successfulOnly", False)]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def persistent_text_param(registry, xml_parent, data):
    """yaml: persistent-text
    A persistent text parameter.

    Requires the Jenkins :jenkins-plugins:`Persistent Parameter Plugin
    <persistent-parameter>`.

    :arg str name: the name of the parameter
    :arg str default: the default value of the parameter (optional)
    :arg str description: a description of the parameter (optional)
    :arg bool trim: strip whitespaces from the begnning and end
        of the string (optional, default: false)
    :arg bool successfulOnly: if true, then the value of the parameter
        gets persisted only between successful builds
        (optional, default: false)

    Example::

      parameters:
        - persistent-text:
            name: FOO
            default: bar
            description: "A persistent parameter named FOO, defaults to 'bar'."
            successfulOnly: false
    """

    pdef = base_param(
        registry,
        xml_parent,
        data,
        True,
        "com.gem.persistentparameter.PersistentTextParameterDefinition",
    )

    mapping = [("trim", "trim", False), ("successfulOnly", "successfulOnly", False)]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


def persistent_choice_param(registry, xml_parent, data):
    """yaml: persistent-choice
    A persistent single selection parameter.

    Requires the Jenkins :jenkins-plugins:`Persistent Parameter Plugin
    <persistent-parameter>`.

    :arg str name: the name of the parameter
    :arg list choices: the available choices, first one is the default one.
    :arg str description: a description of the parameter (optional)
    :arg bool successfulOnly: if true, then the value of the parameter
        gets persisted only between successful builds
        (optional, default: false)

    Example::

      parameters:
        - persistent-choice:
            name: project
            choices:
              - nova
              - glance
            description: "On which project to run?"
            successfulOnly: false
    """
    pdef = base_param(
        registry,
        xml_parent,
        data,
        False,
        "com.gem.persistentparameter.PersistentChoiceParameterDefinition",
    )
    choices = XML.SubElement(pdef, "choices", {"class": "java.util.Arrays$ArrayList"})
    a = XML.SubElement(choices, "a", {"class": "string-array"})
    for choice in data["choices"]:
        XML.SubElement(a, "string").text = choice

    mapping = [("successfulOnly", "successfulOnly", False)]
    helpers.convert_mapping_to_xml(pdef, data, mapping, fail_required=True)


class Parameters(jenkins_jobs.modules.base.Base):
    sequence = 21

    component_type = "parameter"
    component_list_type = "parameters"

    @staticmethod
    def _extend_uno_choice_param_data(param, param_type, data):
        """Pass job name to the uno-choice plugin"""
        if param_type in (
            "active-choices",
            "active-choices-reactive",
            "dynamic-reference",
        ):
            # Extend uno-choice plugin parameter data with mandatory properties:
            # `project-name` and `project-full-name`
            param[param_type]["_project-name"] = data["name"].split("/")[-1]
            param[param_type]["_project-full-name"] = data["name"]

    def gen_xml(self, xml_parent, data):
        properties = xml_parent.find("properties")
        if properties is None:
            properties = XML.SubElement(xml_parent, "properties")

        parameters = data.get("parameters", [])
        hmodel = "hudson.model."
        if parameters:
            # The conditionals here are to work around the extended_choice
            # parameter also being definable in the properties module.  This
            # usage has been deprecated but not removed.  Because it may have
            # added these elements before us, we need to check if they already
            # exist, and only add them if they're missing.
            pdefp = properties.find(hmodel + "ParametersDefinitionProperty")
            if pdefp is None:
                pdefp = XML.SubElement(
                    properties, hmodel + "ParametersDefinitionProperty"
                )
            pdefs = pdefp.find("parameterDefinitions")
            if pdefs is None:
                pdefs = XML.SubElement(pdefp, "parameterDefinitions")
            for idx, param in enumerate(parameters):
                if isinstance(parameters, LocList):
                    param_pos = parameters.value_pos[idx]
                else:
                    param_pos = None
                if not isinstance(param, dict):
                    # Macro parameter without arguments
                    param = {param: {}}
                param_type = next(iter(param))
                macro_dict = self.registry.macros.get("parameter", {})
                macro = macro_dict.get(param_type)
                if not macro:
                    self._extend_uno_choice_param_data(param, param_type, data)
                else:
                    # Process macro case.
                    for macro_param in macro.elements:
                        for macro_param_type in macro_param:
                            self._extend_uno_choice_param_data(
                                macro_param, macro_param_type, data
                            )
                self.registry.dispatch(
                    "parameter", pdefs, param, component_pos=param_pos
                )
