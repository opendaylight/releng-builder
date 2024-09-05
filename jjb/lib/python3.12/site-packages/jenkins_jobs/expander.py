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

from functools import partial
from itertools import filterfalse
from jinja2 import StrictUndefined

from .errors import Context, JenkinsJobsException
from .formatter import CustomFormatter, enum_str_format_required_params
from .loc_loader import LocDict, LocString, LocList
from .yaml_objects import (
    J2String,
    J2Yaml,
    YamlInclude,
    YamlListJoin,
    IncludeJinja2,
    IncludeRawExpand,
    IncludeRawVerbatim,
)


def expand_dict(expander, obj, params, key_pos, value_pos):
    result = LocDict(pos=obj.pos)
    for key, value in obj.items():
        expanded_key = expander.expand(key, params, None)
        expanded_value = expander.expand(
            value, params, obj.key_pos.get(key), obj.value_pos.get(key)
        )
        result.set_item(
            expanded_key, expanded_value, obj.key_pos.get(key), obj.value_pos.get(key)
        )
    return result


def expand_list(expander, obj, params, key_pos, value_pos):
    items = [
        expander.expand(item, params, None, obj.value_pos[idx])
        for idx, item in enumerate(obj)
    ]
    value_pos = [obj.value_pos[idx] for idx, _ in enumerate(obj)]
    return LocList(items, obj.pos, value_pos)


def expand_tuple(expander, obj, params, key_pos, value_pos):
    return tuple(expander.expand(item, params, None) for item in obj)


class StrExpander:
    def __init__(self, allow_empty_variables):
        self._formatter = CustomFormatter(allow_empty_variables)

    def __call__(self, obj, params, key_pos, value_pos):
        try:
            return self._formatter.format(str(obj), **params)
        except JenkinsJobsException as x:
            lines = str(obj).splitlines()
            start_ofs = value_pos.body.index(lines[0])
            pre_pad = value_pos.body[:start_ofs]
            # Shift position to reflect template position inside yaml file:
            if "\n" in pre_pad:
                pos = value_pos.with_offset(line_ofs=1)
            else:
                pos = value_pos.with_offset(column_ofs=start_ofs)
            pos = pos.with_contents_start()
            raise x.with_pos(pos)


def call_expand(expander, obj, params, key_pos, value_pos):
    return obj.expand(expander, params)


def dont_expand(obj, params, key_pos, value_pos):
    return obj


def dont_expand_yaml_object(expander, obj, params, key_pos, value_pos):
    return obj


yaml_classes_list = [
    J2String,
    J2Yaml,
    YamlInclude,
    YamlListJoin,
    IncludeJinja2,
    IncludeRawExpand,
    IncludeRawVerbatim,
]

deprecated_yaml_tags = [
    ("!include", YamlInclude),
    ("!include-raw", IncludeRawExpand),
    ("!include-raw:", IncludeRawExpand),
    ("!include-raw-escape", IncludeRawVerbatim),
    ("!include-raw-escape:", IncludeRawVerbatim),
]


# Expand strings and yaml objects.
class Expander:
    def __init__(self, config=None):
        if config:
            allow_empty_variables = config.yamlparser["allow_empty_variables"]
        else:
            allow_empty_variables = False
        _yaml_object_expanders = {
            cls: partial(call_expand, self) for cls in yaml_classes_list
        }
        self.expanders = {
            dict: partial(expand_dict, self),
            LocDict: partial(expand_dict, self),
            list: partial(expand_list, self),
            LocList: partial(expand_list, self),
            tuple: partial(expand_tuple, self),
            str: StrExpander(allow_empty_variables),
            LocString: StrExpander(allow_empty_variables),
            bool: dont_expand,
            int: dont_expand,
            float: dont_expand,
            type(None): dont_expand,
            **_yaml_object_expanders,
        }

    def expand(self, obj, params, key_pos=None, value_pos=None):
        t = type(obj)
        try:
            expander = self.expanders[t]
        except KeyError:
            raise JenkinsJobsException(
                f"Do not know how to expand type: {t!r}", pos=value_pos
            )
        return expander(obj, params, key_pos, value_pos)


# Expand only yaml objects.
class YamlObjectsExpander(Expander):
    def __init__(self, config=None):
        super().__init__(config)
        self.expanders.update(
            {
                str: dont_expand,
                LocString: dont_expand,
                IncludeRawVerbatim: dont_expand,
            }
        )


# Expand only string parameters.
class StringsOnlyExpander(Expander):
    def __init__(self, config):
        super().__init__(config)
        _yaml_object_expanders = {
            cls: partial(dont_expand_yaml_object, self) for cls in yaml_classes_list
        }
        self.expanders.update(_yaml_object_expanders)


def call_required_params(obj, pos):
    yield from obj.required_params


def enum_dict_params(obj, pos):
    for key, value in obj.items():
        yield from enum_required_params(key, obj.key_pos.get(key))
        yield from enum_required_params(value, obj.value_pos.get(key))


def enum_seq_params(obj, pos):
    for idx, value in enumerate(obj):
        yield from enum_required_params(value, pos=None)


def enum_loc_list_params(obj, pos):
    for idx, value in enumerate(obj):
        yield from enum_required_params(value, obj.value_pos[idx])


def no_parameters(obj, pos):
    return []


yaml_classes_enumers = {cls: call_required_params for cls in yaml_classes_list}

param_enumers = {
    str: enum_str_format_required_params,
    LocString: enum_str_format_required_params,
    dict: enum_dict_params,
    LocDict: enum_dict_params,
    list: enum_seq_params,
    LocList: enum_loc_list_params,
    tuple: enum_seq_params,
    bool: no_parameters,
    int: no_parameters,
    float: no_parameters,
    type(None): no_parameters,
    **yaml_classes_enumers,
}

# Do not expand these.
disable_expand_for = {"template-name"}


def enum_required_params(obj, pos):
    t = type(obj)
    try:
        enumer = param_enumers[t]
    except KeyError:
        raise JenkinsJobsException(
            f"Do not know how to enumerate required parameters for type: {t!r}",
            pos=pos,
        )
    return enumer(obj, pos)


def expand_parameters(expander, param_dict):
    expanded_params = LocDict()
    deps = {}  # Variable name -> variable pos.

    def deps_context():
        return [Context(f"Used by {n}", vp) for n, (kp, vp) in deps.items()]

    def expand(name):
        try:
            value = expanded_params[name]
            key_pos = expanded_params.key_pos.get(name)
            value_pos = expanded_params.value_pos.get(name)
            return (value, key_pos, value_pos)
        except KeyError:
            pass
        try:
            format = param_dict[name]
        except KeyError:
            return (StrictUndefined(name=name), None, None)
        key_pos = param_dict.key_pos.get(name)
        value_pos = param_dict.value_pos.get(name)
        if name in deps:
            expand_ctx = Context(f"While expanding {name!r}", key_pos)
            raise JenkinsJobsException(
                f"Recursive parameters usage: {' <- '.join(deps)}",
                pos=value_pos,
                ctx=[*deps_context(), expand_ctx],
            )
        if name in disable_expand_for:
            value = format
        else:
            required_params = list(enum_required_params(format, value_pos))
            deps[name] = (key_pos, value_pos)
            try:
                params = LocDict.merge(expanded_params)
                for n in required_params:
                    v, kp, vp = expand(n)
                    params.set_item(n, v, kp, vp)
            finally:
                deps.popitem()
            try:
                value = expander.expand(format, params, key_pos, value_pos)
            except JenkinsJobsException as x:
                raise x.with_context(
                    f"While expanding parameter {name!r}",
                    pos=key_pos,
                    ctx=deps_context(),
                )
        expanded_params.set_item(name, value, key_pos, value_pos)
        return (value, key_pos, value_pos)

    expand("name")  # expand 'name' parameter first
    for name in filterfalse(lambda x: x == "name", param_dict):
        expand(name)
    return expanded_params
