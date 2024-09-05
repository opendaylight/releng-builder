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

import itertools
from collections import namedtuple

from .errors import Context, JenkinsJobsException
from .loc_loader import LocList, LocDict
from jenkins_jobs.expander import YamlObjectsExpander


Dimension = namedtuple("Dimension", "axis params")


def _decode_axis_value(axis, value, key_pos, value_pos):
    if not isinstance(value, (list, LocList)):
        yield {axis: value}
        return
    for idx, item in enumerate(value):
        if not isinstance(item, (dict, LocDict)):
            d = LocDict()
            if type(value) is LocList:
                d.set_item(axis, item, key_pos, value.value_pos[idx])
            else:
                d[axis] = item
            yield d
            continue
        if len(item.items()) != 1:
            raise JenkinsJobsException(
                f"Expected a value or a dict with single element, but got: {item!r}",
                pos=value.value_pos[idx],
                ctx=[Context(f"In parameter {axis!r} definition", key_pos)],
            )
        value, p = next(iter(item.items()))
        yield LocDict.merge(
            {axis: value},  # Point axis value.
            p,  # Point-specific parameters. May override axis value.
        )


def enum_dimensions_params(axes, params, defaults):
    expander = YamlObjectsExpander()
    if not axes:
        # No axes - instantiate one job/view.
        yield {}
        return
    dim_values = []
    for axis in axes:
        try:
            value, key_pos, value_pos = params.item_with_pos(axis)
        except KeyError:
            try:
                value = defaults[axis]
                key_pos = value_pos = None
            except KeyError:
                continue  # May be, value would be received from an another axis values.
        expanded_value = expander.expand(value, params, key_pos, value_pos)
        value = [
            Dimension(axis, params)
            for params in _decode_axis_value(axis, expanded_value, key_pos, value_pos)
        ]
        dim_values.append(value)
    for dimensions in itertools.product(*dim_values):
        overrides = {}  # Axis -> overridden param.
        for dim in dimensions:
            for name, value in dim.params.items():
                if name != dim.axis:
                    overrides[name] = value
        param_dicts = [d.params for d in dimensions]
        # Parameter overrides should take precedence over axis values.
        yield LocDict.merge(*param_dicts, overrides)


def _match_exclude(params, exclude, pos):
    if not isinstance(exclude, dict):
        raise JenkinsJobsException(
            f"Expected a dict, but got: {exclude!r}",
            pos=pos,
        )
    if not exclude:
        raise JenkinsJobsException(
            f"Expected a dict, but is empty: {exclude!r}",
            pos=pos,
        )
    for axis, value in exclude.items():
        try:
            v = params[axis]
        except KeyError:
            raise JenkinsJobsException(
                f"Unknown axis {axis!r}",
                pos=pos,
            )
        if value != v:
            return False
    # All required exclude values are matched.
    return True


def is_point_included(exclude_list, params, key_pos=None):
    if not exclude_list:
        return True
    try:
        for idx, exclude in enumerate(exclude_list):
            if _match_exclude(params, exclude, exclude_list.value_pos[idx]):
                return False
    except JenkinsJobsException as x:
        raise x.with_context(
            f"In template exclude list",
            pos=key_pos,
        )
    return True
