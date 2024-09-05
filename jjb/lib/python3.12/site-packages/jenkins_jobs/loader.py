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
import functools
import io
import logging
import warnings
from functools import partial

from .errors import JenkinsJobsException
from .loc_loader import LocLoader
from .yaml_objects import BaseYamlObject
from .expander import YamlObjectsExpander, deprecated_yaml_tags, yaml_classes_list
from .roots import root_adders

logger = logging.getLogger(__name__)


class Loader(LocLoader):
    @classmethod
    def empty(cls, jjb_config):
        return cls(io.StringIO(), jjb_config)

    def __init__(
        self, stream, jjb_config, source_path=None, source_dir=None, anchors=None
    ):
        super().__init__(stream, source_path)
        self.jjb_config = jjb_config
        self.source_path = source_path
        self.source_dir = source_dir
        self._retain_anchors = jjb_config.yamlparser["retain_anchors"]
        if anchors:
            # Override default set by super class.
            self.anchors = anchors

    # Override the default composer to skip resetting the anchors at the
    # end of the current document.
    def compose_document(self):
        # Drop the DOCUMENT-START event.
        self.get_event()
        # Compose the root node.
        node = self.compose_node(None, None)
        # Drop the DOCUMENT-END event.
        self.get_event()
        return node

    def _with_stream(self, stream, source_path, source_dir):
        return Loader(stream, self.jjb_config, source_path, source_dir, self.anchors)

    def load_fp(self, fp):
        return self.load(fp)

    # 1024 cache size seems like a reasonable balance between memory requirement and performance gain
    @functools.lru_cache(maxsize=1024)
    def load_path(self, path):
        # Caching parsed file outputs is safe even with _retain_anchors set to True because:
        # PyYAML does not allow updating anchor values, it is considered as anchor duplication
        # So we can safely cache a parsed YAML for a file containing an alias since the alias can be defined
        # only once and must be defined before use. The alias value will remain same irrespective of the number
        # times a file is parsed
        return self.load(path.read_text(), source_path=path, source_dir=path.parent)

    def load(self, stream, source_path=None, source_dir=None):
        loader = self._with_stream(stream, source_path, source_dir)
        try:
            return loader.get_single_data()
        finally:
            loader.dispose()
            if self._retain_anchors:
                self.anchors.update(loader.anchors)


def load_deprecated_yaml(tag, cls, loader, node):
    warnings.warn(
        f"Tag {tag!r} is deprecated, switch to using {cls.yaml_tag!r}",
        UserWarning,
    )
    return cls.from_yaml(loader, node)


for cls in yaml_classes_list:
    Loader.add_constructor(cls.yaml_tag, cls.from_yaml)

for tag, cls in deprecated_yaml_tags:
    Loader.add_constructor(tag, partial(load_deprecated_yaml, tag, cls))


def is_stdin(path):
    return hasattr(path, "read")


def enum_expanded_paths(path_list):
    visited_set = set()

    def real(path):
        real_path = path.resolve()
        if real_path in visited_set:
            logger.warning(
                "File '%s' is already added as '%s'; ignoring reference to avoid"
                " duplicating YAML definitions.",
                path,
                real_path,
            )
        else:
            yield real_path
            visited_set.add(real_path)

    for path in path_list:
        if is_stdin(path):
            yield path
        elif path.is_dir():
            for p in path.iterdir():
                if p.suffix in {".yml", ".yaml"}:
                    yield from real(p)
        else:
            yield from real(path)


def load_files(config, roots, path_list):
    expander = YamlObjectsExpander(config)
    loader = Loader.empty(config)
    for path in enum_expanded_paths(path_list):
        if is_stdin(path):
            data = loader.load_fp(path)
        else:
            data = loader.load_path(path)
        if data is None:
            continue
        if not isinstance(data, list):
            raise JenkinsJobsException(
                f"The topmost collection must be a list, but is: {data}",
                pos=data.pos,
            )
        for idx, item in enumerate(data):
            if not isinstance(item, dict):
                raise JenkinsJobsException(
                    f"Topmost list should contain single-item dict,"
                    f" not a {type(item)}. Missing indent?",
                    pos=data.value_pos[idx],
                )
            if len(item) != 1:
                raise JenkinsJobsException(
                    f"Topmost dict should be single-item,"
                    f" but have keys {list(item.keys())}. Missing indent?",
                    pos=item.pos,
                )
            kind, contents = next(iter(item.items()))
            if kind.startswith("_"):
                continue
            if isinstance(contents, BaseYamlObject):
                contents = contents.expand(expander, params={})
            try:
                adder = root_adders[kind]
            except KeyError:
                raise JenkinsJobsException(
                    f"Unknown topmost element type : {kind!r};"
                    f" known are: {','.join(root_adders)}.",
                    pos=item.pos,
                )
            adder(config, roots, contents, item.pos)
