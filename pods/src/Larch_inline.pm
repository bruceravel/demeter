package Larch;  # -*- python -*-

use Inline Python;

1;

__DATA__
__Python__

import sys
import numpy
import larch

from larch.interpreter import Interpreter
from larch.inputText import InputText

BANNER = """  Larch %s (%s) M. Newville, T. Trainor
  using python %s, numpy %s"""  %  (larch.__version__, larch.__date__,
                                    '%i.%i.%i' % sys.version_info[:3],
                                    numpy.__version__)

# execute scripts listed on command-line
#shell.input.interactive = False
#finp = open(arg, 'r')
#for itxt, txt in enumerate(finp.readlines()):
#    shell.input.put(txt[:-1], lineno=itxt, filename=arg)
#finp.close()
#shell.larch_execute('')
#shell.input.interactive = True

def add(x,y):
   return x + y

def subtract(x,y):
   return x - y

shell = larch.shell()

def dispose(x):
   shell.input.interactive = False
   shell.larch_execute(x)


###END_OF_PYTHON
