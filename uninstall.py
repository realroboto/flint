#!/usr/bin/env python3
"""Remove flint's hook registrations. Equivalent to `install.py --uninstall`."""
import sys

import install

if __name__ == '__main__':
    sys.exit(install.main(['--uninstall']))
