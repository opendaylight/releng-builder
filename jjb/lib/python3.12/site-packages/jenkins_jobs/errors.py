"""Exception classes for jenkins_jobs errors"""

import inspect
from dataclasses import dataclass

from .position import Pos


def is_sequence(arg):
    return not hasattr(arg, "strip") and (
        hasattr(arg, "__getitem__") or hasattr(arg, "__iter__")
    )


def context_lines(message, pos):
    if not pos:
        return [message]
    snippet_lines = [line.rstrip() for line in pos.snippet.splitlines()]
    return [
        f"{pos.path}:{pos.line+1}:{pos.column+1}: {message}",
        *snippet_lines,
    ]


@dataclass
class Context:
    message: str
    pos: Pos

    @property
    def lines(self):
        return context_lines(self.message, self.pos)


class JenkinsJobsException(Exception):
    def __init__(self, message, pos=None, ctx=None):
        super().__init__(message)
        self.pos = pos
        self.ctx = ctx or []  # Context list

    @property
    def message(self):
        return self.args[0]

    def with_pos(self, pos):
        return JenkinsJobsException(self.message, pos, self.ctx)

    def with_context(self, message, pos, ctx=None):
        return JenkinsJobsException(
            self.message, self.pos, [*(ctx or []), Context(message, pos), *self.ctx]
        )

    def with_ctx_list(self, ctx):
        return JenkinsJobsException(self.message, self.pos, [*ctx, *self.ctx])

    @property
    def lines(self):
        ctx_lines = []
        for ctx in self.ctx:
            ctx_lines += ctx.lines
        return [*ctx_lines, *context_lines(self.message, self.pos)]


class ModuleError(JenkinsJobsException):
    def get_module_name(self):
        frame = inspect.currentframe()
        module_name = "<unresolved>"
        while frame:
            # XML generation called via dispatch
            co_name = frame.f_code.co_name
            if co_name == "run":
                break
            if co_name == "dispatch":
                data = frame.f_locals
                module_name = "%s.%s" % (data["component_type"], data["name"])
                break
            # XML generation done directly by class using gen_xml or root_xml
            if co_name == "gen_xml" or co_name == "root_xml":
                data = frame.f_locals["data"]
                module_name = next(iter(data.keys()))
                break
            frame = frame.f_back

        return module_name


class InvalidAttributeError(ModuleError):
    def __init__(self, attribute_name, value, valid_values=None, pos=None, ctx=None):
        message = "'{0}' is an invalid value for attribute {1}.{2}".format(
            value, self.get_module_name(), attribute_name
        )

        if is_sequence(valid_values):
            message += "\nValid values include: {0}".format(
                ", ".join("'{0}'".format(value) for value in valid_values)
            )

        super().__init__(message, pos, ctx)


class MissingAttributeError(ModuleError):
    def __init__(self, missing_attribute, module_name=None, pos=None, ctx=None):
        module = module_name or self.get_module_name()
        if is_sequence(missing_attribute):
            message = "One of {0} must be present in '{1}'".format(
                ", ".join("'{0}'".format(value) for value in missing_attribute), module
            )
        else:
            message = "Missing {0} from an instance of '{1}'".format(
                missing_attribute, module
            )

        super().__init__(message, pos, ctx)


class AttributeConflictError(ModuleError):
    def __init__(self, attribute_name, attributes_in_conflict, module_name=None):
        module = module_name or self.get_module_name()
        message = "Attribute '{0}' can not be used together with {1} in {2}".format(
            attribute_name,
            ", ".join("'{0}'".format(value) for value in attributes_in_conflict),
            module,
        )

        super(AttributeConflictError, self).__init__(message)


class YAMLFormatError(JenkinsJobsException):
    pass


class JJBConfigException(JenkinsJobsException):
    pass
