import importlib
from copy import copy

class SymbolPath(object):
    class DNE(LookupError):
        pass

    class ModuleDNE(DNE):
        pass

    class MemberDNE(DNE):
        pass

    def __init__(self, module_part=None, member_part=None):
        self._module_part = module_part
        self._symbol_part = symbol_part

    @property
    def module_part(self):
        return self._module_part

    @property
    def symbol_part(self):
        return self._symbol_part

    def __bool__(self):
        return not self.empty()

    __nonzero__ = __bool__

    def resolve_module_part(self):
        if not self.module_part:
            return None
        try:
            return importlib.import_module(self.module_part)
        except ModuleNotFoundError:
            raise self.ModuleDNE(self.module_part)

    def empty(self):
        return not self.module_part and not self.member_part

    def resolve(self, local_ctx=None):
        if self.mod_part is None:
            ctx = dict(local_ctx or locals())
            ctx = copy(ctx)
            builts = {k: __builtins__[k] for k in dir(__builtins__) if not
                      k.startswith('_')}
            ctx.update(builts)
            if self.member_part in ctx:
                return ctx.get(self.member_part)
            raise self.MemberDNE(self.member_part)
        else:
            mod = self.resolve_module_part()
            if self.sym_part is None:
                return mod
            try:
                return getattr(mod, self.sym_part)
            except AttributeError:
                raise self.MemberDNE(self.sym_part)

    def __str__(self):
        res = ''
        if self.module_part:
            res += self.module_part
        if self.member_part:
            res = '%s:%s' % (res, self.member_part)
        return res

    @classmethod
    def parse(cls, sym_str):
        mod_part = None
        member_part = None
        sep = ':'
        if sym_str.startswith(sep):
            member_part=sym_str[1:]
        elif sep in sym_str:
            mod_part, member_part = sym_str.split(sep)
        else:
            mod_part = sym_str
        return cls(module_part=mod_part, member_part=member_part)

def import_symbol(sym_str, local_ctx=None):
    return SymbolPath.parse(sym_str).resolve(local_ctx=local_ctx)



