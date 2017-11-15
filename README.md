## celery test app

This is a mock celery app, because everything is terrible. Some of the scripts require zsh because I said so. It doesn't have to be set as your login shell; it just has to be installed. If you don't have it, you can `apt-get install zsh` or `brew mochachino whatever`.  virtualenv+pip setup and installation of requirements are handled by the scripts that expect them to be in place.

### setup

#### start redis
The `docker-compose.yml` in the repo root will a new redis-server listening on `localhost:6380`.  The default port is 6379, so this should work even if you're already running a redis instance locally.

Make sure you're in the same directory as `docker-compose.yml`, then start redis with:

```shell
sudo docker-compose up
```
This particular command runs in the foreground, but docker-compose can also start containers in the background.  Check the docs.

#### start the worker
This will run the celery worker in the foreground, blocking until it exits.  You'll need to open up another terminal tab/window for the other steps.

```shell
./scripts/run-worker.zsh
```

This script does the following:
* creates a pidfile at `./tmp/run/celery-worker.pid`, which is used by `run-sysdig.zsh` (below) to configure sysdig filters.
* checks for a virtualenv at `./tmp/env`. if the that directory doesn't exist, creates the virtualenv and installs requirements.
* acivates the virtualenv
* fixes `PYTHONPATH` so that `celery_app` is importable
* exec into a worker with `exec celery worker -A celery_app.conf [..flags]`

Note that the celery worker needs to connect to its broker during initialization, and on connection failure the worker will exit without even entering its main loop.  There's an easy way to avoid this problem: run the redis setup step first.


#### start sysdig
This script uses `sysdig` to capture all system-level events from the celery worker.  This includes the worker's main management process and any process it forks off.  Most importantly, this includes the forked python processes responsible for actually executing tasks.  (These are direct children of the manager process, which doesn't directly execute any tasks at all -- it just passes task arguments on to its children).

With the worker already running (see notes below), run:
```shell
./scripts/run-sysdig.zsh
```

If you don't know what you would use sysdig for, or if you're familiar with it but you hate things that are awesome, you can skip this step.  Everything else will still work.

If you do want to use it, note the following:
* Like the worker, this runs in the foreground.  Leave it running, and open another terminal for the remaining steps.
* Sysdig needs root access.  If you aren't root, you'll be prompted for your sudo password.
* The sysdig filter is PID-based. The PID is read from a pidfile.  The pidfile is created by `./scripts/run-worker.zsh`.  If `./scripts/run-worker.zsh` isn't running, this script can't do anything but insult you.
* The current implementation can't actually insult you, but this could change very quickly and you would do well to keep that in mind.


### use

#### open ipython shell
You probably want to be in a python shell.  If you want to manually kick off a task, or if you want to do anything that sounds remotely like that, then this is what you want.

This script will drop you into `ipython`, running in the same the python environment as the worker:
```shell
./scripts/run-ipython.zsh
```
This doesn't create any pidfiles, but otherwise this script is almost the same as run-worker.zsh.  The only other difference is that this `exec`s ipython instead of celery.

#### using the ipython shell
As in the worker process, the local `celery_app` module is always importable in the shell.  Kicking off tasks looks like you'd expect:

```python
from celery_app.tasks import die_now
result = die_now.delay(exit_code=1)
result.get()
```

The shell and worker use the same celery configuration -- same broker, same task definitions, etc -- and in general, any task enqueued in the shell will end up being handled by the worker started under `run-worker.zsh`.  Likewise, related log messages will appear in the terminal where `run-worker.zsh` is foregrounded.  At a minimum, this terminal will display celery's builtin task- and worker-level logging.  By default, logs from the `celery_app` module will end up here as well.

Notable exceptions to what I just said:
* If the worker isn't listening to queue `'xyz'`, and if you decide to send a
  task to `'xyz'`, you won't even have a bad time.  You'll have nothing, and it will be your fault.
* If you decide to run any other worker in the same cluster (anything connected to the same broker), you'll need to add the word "sometimes" to 80% of the statements above this line. I'm not going to tell you which ones.
* If you reconfigure app-level logging, refer to the previous point and replace "sometimes" with "allegedly."





