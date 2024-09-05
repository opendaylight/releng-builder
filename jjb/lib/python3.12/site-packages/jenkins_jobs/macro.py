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

from dataclasses import dataclass
from functools import partial

from .root_base import ElementBase
from .expander import Expander, StringsOnlyExpander
from .yaml_objects import BaseYamlObject
from .loc_loader import LocDict
from .errors import JenkinsJobsException
from .position import Pos


macro_specs = [
    # type_name, elements_name (aka component_type, component_list_type for Registry).
    ("parameter", "parameters"),
    ("property", "properties"),
    ("builder", "builders"),
    ("wrapper", "wrappers"),
    ("trigger", "triggers"),
    ("publisher", "publishers"),
    ("scm", "scm"),
    ("pipeline-scm", "pipeline-scm"),
    ("reporter", "reporters"),
    ("notification", "notifications"),
]


@dataclass
class Macro(ElementBase):
    _expander: Expander
    _str_expander: StringsOnlyExpander
    _type_name: str
    name: str
    defaults_name: str
    pos: Pos
    elements: list

    @classmethod
    def add(
        cls,
        type_name,
        elements_name,
        config,
        roots,
        data,
        pos,
    ):
        d = data.copy()
        name = d.pop_required_loc_string("name")
        defaults = d.pop_loc_string("defaults", "global")
        elements = d.pop_required_element(elements_name)
        params = d
        expander = Expander(config)
        str_expander = StringsOnlyExpander(config)
        macro = cls(
            _defaults=roots.defaults,
            _expander=expander,
            _str_expander=str_expander,
            _type_name=type_name,
            name=name,
            defaults_name=defaults,
            pos=pos,
            params=params,
            elements=elements or [],
        )
        roots.assign(roots.macros[type_name], name, macro, "macro")

    def __str__(self):
        return f"{self._type_name} macro {self.name!r}"

    def dispatch_elements(self, registry, xml_parent, component_data, job_data, params):
        defaults = self._pick_defaults(self.defaults_name)
        full_params = LocDict.merge(
            defaults.params,
            self.params,
            params,
        )
        element_list = self.elements
        if isinstance(element_list, BaseYamlObject):
            # Expand !j2-yaml tag if it is right below macro body.
            # But do not expand yaml tags inside it - they will be expanded later.
            element_list = element_list.expand(self._str_expander, full_params)
        for element in element_list:
            try:
                expanded_element = self._expander.expand(element, full_params)
            except JenkinsJobsException as x:
                raise x.with_context(
                    f"While expanding {self}",
                    pos=self.pos,
                )
            # Pass component_data in as template data to this function
            # so that if the macro is invoked with arguments,
            # the arguments are interpolated into the real defn.
            registry.dispatch(
                self._type_name,
                xml_parent,
                expanded_element,
                component_data,
                job_data=job_data,
            )


macro_adders = {
    macro_type: partial(Macro.add, macro_type, elements_name)
    for macro_type, elements_name in macro_specs
}
