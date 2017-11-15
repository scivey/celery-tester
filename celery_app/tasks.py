from __future__ import print_function
from .conf import app, DEFAULT_QUEUE

import sys
import os
def say(fmt, *args):
    msg = fmt
    if args:
        msg %= args
    extra = ' '.join([
        '[ stupid_logger ]',
        '(PID=%r)' % (os.getpid(),)
    ])
    print(extra + ' : ' + msg, file=sys.stderr)



@app.task
def echo(msg):
    return msg

@app.task
def ping():
    echo.delay('PING')


class SysExitMethod(object):
    RAISE = 'RAISE'
    CALL = 'CALL'

    ALL = frozenset([RAISE, CALL])


def get_exiter(method):
    if method in SysExitMethod.ALL:
        def exiter(exit_code, prefix=None):
            msg = "exiting process with status=%r, (method=%r)" % (
                exit_code, method
            )
            if prefix:
                msg = prefix + msg
            say(msg)
            if method == SysExitMethod.RAISE:
                raise SystemExit(exit_code)
            assert method == SysExitMethod.CALL, method
            sys.exit(exit_code)
        return exiter
    raise LookupError("No such exit method: %r" % method)


def do_exit(name, method, exit_code):
    exiter = get_exiter(method)
    exiter(exit_code, prefix=name + ' - ')

@app.task
def die_now(exit_code=0, method=SysExitMethod.CALL):
    say("die_now(%r, %r) START", exit_code, method)
    do_exit(name='die_now', exit_code=exit_code, method=method)


@app.task
def sleep_then_die(n_steps, exit_code=0, method=SysExitMethod.CALL):
    n_steps = int(round(n_steps))
    step_duration=1.0
    msg_name = "sleep_then_die(%r, %r, %r)" % (n_steps, exit_code, method)
    say(msg_name + ' START')
    for i in range(0, n_steps):
        msg = "sleeping for %2.2fs (%r/%r)" % (
            step_duration, i, n_steps
        )
        say(msg_name + ' ' + msg)
        time.sleep(step_duration)
    say(msg_name + ' finished sleeping; will exit.')
    do_exit(name=msg_name, exit_code=exit_code, method=method)




