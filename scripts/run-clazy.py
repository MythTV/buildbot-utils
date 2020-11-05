#!/usr/bin/env python
#
#===- run-clazy.py - Parallel clazy runner --------*- python -*--===#
#
# From run-clang-tidy.py.
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
#===-----------------------------------------------------------------------===#
# FIXME: Integrate with clang-tidy-diff.py


"""
Parallel clazy runner
==========================

Runs clazy over all files in a compilation database. Requires clazy in $PATH.

Example invocations.
- Run clazy on all files in the current working directory with a default
  set of checks and show warnings in the cpp files and all project headers.
    run-clazy.py $PWD

Compilation database setup:
http://clang.llvm.org/docs/HowToSetupToolingForLLVM.html
"""

from __future__ import print_function

import argparse
import glob
import json
import multiprocessing
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import traceback

try:
  import yaml
except ImportError:
  yaml = None

is_py2 = sys.version[0] == '2'

if is_py2:
    import Queue as queue
else:
    import queue as queue


def find_compilation_database(path):
  """Adjusts the directory until a compilation database is found."""
  result = './'
  while not os.path.isfile(os.path.join(result, path)):
    if os.path.realpath(result) == '/':
      print('Error: could not find compilation database.')
      sys.exit(1)
    result += '../'
  return os.path.realpath(result)


def make_absolute(f, directory):
  if os.path.isabs(f):
    return f
  return os.path.normpath(os.path.join(directory, f))


def get_tidy_invocation(f, checks, tmpdir, build_path, header_filter, quiet):
  """Gets a command line for clang-tidy."""
  start = ["clazy",  "--standalone"]
  if header_filter is not None:
    start.append('-header-filter=' + header_filter)
  if checks:
    start.append('-checks=' + checks)
  if tmpdir is not None:
    start.append('-export-fixes')
    # Get a temporary file. We immediately close the handle so clang-tidy can
    # overwrite it.
    (handle, name) = tempfile.mkstemp(suffix='.yaml', dir=tmpdir)
    os.close(handle)
    start.append(name)
  start.append('-p=' + build_path)
  if quiet:
      start.append('-quiet')
  start.append(f)
  return start


def merge_replacement_files(tmpdir, mergefile):
  """Merge all replacement files in a directory into a single file"""
  # The fixes suggested by clang-tidy >= 4.0.0 are given under
  # the top level key 'Diagnostics' in the output yaml files
  mergekey = "Diagnostics"
  merged=[]
  for replacefile in glob.iglob(os.path.join(tmpdir, '*.yaml')):
    content = yaml.safe_load(open(replacefile, 'r'))
    if not content:
      continue # Skip empty files.
    merged.extend(content.get(mergekey, []))

  if merged:
    # MainSourceFile: The key is required by the definition inside
    # include/clang/Tooling/ReplacementsYaml.h, but the value
    # is actually never used inside clang-apply-replacements,
    # so we set it to '' here.
    output = {'MainSourceFile': '', mergekey: merged}
    with open(mergefile, 'w') as out:
      yaml.safe_dump(output, out)
  else:
    # Empty the file:
    open(mergefile, 'w').close()


def run_tidy(args, tmpdir, build_path, queue, lock, failed_files):
  """Takes filenames out of queue and runs clang-tidy on them."""
  while True:
    name = queue.get()
    invocation = get_tidy_invocation(name, args.checks, tmpdir, build_path,
                                     args.header_filter, args.quiet)

    proc = subprocess.Popen(invocation, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = proc.communicate()
    if proc.returncode != 0:
      failed_files.append(name)
    with lock:
      sys.stdout.write(' '.join(invocation) + '\n' + output.decode('utf-8'))
      if len(err) > 0:
        sys.stdout.flush()
        sys.stderr.write(err.decode('utf-8'))
    queue.task_done()


def is_git_directory(path = '.'):
    return subprocess.call(['git', '-C', path, 'status'],
                           stderr=subprocess.STDOUT,
                           stdout = open(os.devnull, 'w')) == 0

def read_dotClazy():
    filename = f".clazy"
    while not os.path.isfile(filename):
        if not is_git_directory(".."):
            return None 
        os.chdir("..")

    f = open(filename, 'r')
    if not f:
        return None
    lines = f.read().splitlines()
    f.close()

    # Strip comments
    lines = map(lambda line: re.sub('//.*$', '', line), lines)
    lines = map(lambda line: re.sub('#.*$', '', line), lines)
    # Strip leading/trailing white space
    lines = map(str.strip, lines)
    # Remove blank lines
    lines = list(filter(None, lines))
    return ",".join(lines)

def main():
  parser = argparse.ArgumentParser(description='Runs clazy over all files '
                                   'in a compilation database. Requires '
                                   'clazy in $PATH.')
  parser.add_argument('-clang-tidy-binary', metavar='PATH',
                      default='clazy',
                      help='path to clazy binary')
  parser.add_argument('-checks', default=None,
                      help='checks filter, when not specified, use clazy default')
  parser.add_argument('-header-filter', default=None,
                      help='regular expression matching the names of the '
                      'headers to output diagnostics from. Diagnostics from '
                      'the main file of each translation unit are always '
                      'displayed.')
  if yaml:
    parser.add_argument('-export-fixes', metavar='filename', dest='export_fixes',
                        help='Create a yaml file to store suggested fixes in, '
                        'which can be applied with clang-apply-replacements.')
  parser.add_argument('-j', type=int, default=0,
                      help='number of tidy instances to be run in parallel.')
  parser.add_argument('files', nargs='*', default=['.*'],
                      help='files to be processed (regex on path)')
  parser.add_argument('-fix', action='store_true', help='apply fix-its')
  parser.add_argument('-p', dest='build_path',
                      help='Path used to read a compile command database.')
  parser.add_argument('-quiet', action='store_true',
                      help='Run clang-tidy in quiet mode')
  args = parser.parse_args()

  db_path = 'compile_commands.json'

  if args.build_path is not None:
    build_path = args.build_path
  else:
    # Find our database
    build_path = find_compilation_database(db_path)

  try:
    invocation = ['clazy', '--standalone', '--list-checks']
    invocation.append('-p=' + build_path)
    if args.checks:
      invocation.append('-checks=' + args.checks)
    else:
      args.checks = read_dotClazy()
      if args.checks:
        if not args.quiet:
            print("Using checks: " + args.checks)
        invocation.append('-checks=' + args.checks)
    invocation.append('-')
    if args.quiet:
      # Even with -quiet we still want to check if we can call clang-tidy.
      with open(os.devnull, 'w') as dev_null:
        subprocess.check_call(invocation, stdout=dev_null)
    else:
      subprocess.check_call(invocation)
  except:
    print("Unable to run clazy.", file=sys.stderr)
    sys.exit(1)

  # Load the database and extract all files.
  database = json.load(open(os.path.join(build_path, db_path)))
  files = [make_absolute(entry['file'], entry['directory'])
           for entry in database]

  max_task = args.j
  if max_task == 0:
    max_task = multiprocessing.cpu_count()

  tmpdir = None
  if args.fix or (yaml and args.export_fixes):
    tmpdir = tempfile.mkdtemp(prefix="tidy-")

  # Build up a big regexy filter from all command line arguments.
  file_name_re = re.compile('|'.join(args.files))

  return_code = 0
  try:
    # Spin up a bunch of tidy-launching threads.
    task_queue = queue.Queue(max_task)
    # List of files with a non-zero return code.
    failed_files = []
    lock = threading.Lock()
    for _ in range(max_task):
      t = threading.Thread(target=run_tidy,
                           args=(args, tmpdir, build_path, task_queue, lock, failed_files))
      t.daemon = True
      t.start()

    # Fill the queue with files.
    for name in files:
      if file_name_re.search(name):
        task_queue.put(name)

    # Wait for all threads to be done.
    task_queue.join()
    if len(failed_files):
      return_code = 1

  except KeyboardInterrupt:
    # This is a sad hack. Unfortunately subprocess goes
    # bonkers with ctrl-c and we start forking merrily.
    print('\nCtrl-C detected, goodbye.')
#    if tmpdir:
#      shutil.rmtree(tmpdir)
    os.kill(0, 9)

  if yaml and args.export_fixes:
    print('Writing fixes to ' + args.export_fixes + ' ...')
    try:
      merge_replacement_files(tmpdir, args.export_fixes)
    except:
      print('Error exporting fixes.\n', file=sys.stderr)
      traceback.print_exc()
      return_code=1

  if args.fix:
    print('Applying fixes ...')
    try:
      apply_fixes(args, tmpdir)
    except:
      print('Error applying fixes.\n', file=sys.stderr)
      traceback.print_exc()
      return_code = 1

#  if tmpdir:
#    shutil.rmtree(tmpdir)
  sys.exit(return_code)


if __name__ == '__main__':
  main()
