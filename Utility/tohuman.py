#!/usr/bin/env python3
import datetime
import sys
import time

ts = int(sys.argv[1])

human = datetime.datetime.fromtimestamp(ts)

print(str(human) + " " + "/".join(time.tzname), end='')
