#!/usr/bin/env python

"""
check harvester health
"""

import os
import re
import shutil
import subprocess


def check_command(command, check_string):
    print("Checking command : {0}".format(command))
    print("For string : {0}".format(check_string))

    tmp_array = command.split()
    output = (
        subprocess.Popen(tmp_array, stdout=subprocess.PIPE)
        .communicate()[0]
        .decode("ascii")
    )

    if re.search(check_string, output):
        print("Found the string, return 100")
        return 100
    else:
        print("String not found, return 0")
        return 0


def uwsgi_process_availability():
    # check the uwsgi
    process_avail = 0
    output = (
        subprocess.Popen(
            "ps -eo pgid,args | grep uwsgi | grep -v grep",
            stdout=subprocess.PIPE,
            shell=True,
        )
        .communicate()[0]
        .decode("ascii")
    )
    count = 0
    for line in output.split("\n"):
        line = line.strip()
        if line == "":
            continue
        count += 1
    if count >= 1:
        process_avail = 100

    print("uwsgi process check availability: %s" % process_avail)
    return process_avail


def condor_process_availability():
    # check the condor
    process_avail = 0
    output = (
        subprocess.Popen(
            "ps -eo pgid,args | grep condor_schedd | grep -v grep",
            stdout=subprocess.PIPE,
            shell=True,
        )
        .communicate()[0]
        .decode("ascii")
    )
    count = 0
    for line in output.split("\n"):
        line = line.strip()
        if line == "":
            continue
        count += 1
    if count >= 1:
        process_avail = 100

    print("condor_q process check availability: %s" % process_avail)
    return process_avail


def condor_q_availability():
    # check the condor_q
    process_avail = 0
    try:
        result = subprocess.run(
            ["condor_q"],
            timeout=10,  # Timeout in seconds
            capture_output=True,
            text=True
        )
        print(f"command output: {result.stdout}")
        process_avail = 100
    except subprocess.TimeoutExpired:
        print("The command timed out!")
        process_avail = 0

    print("condor_q process check availability: %s" % process_avail)
    return process_avail


def shared_volume_usage_check(path="/var/log/panda", warn_threshold_pct=80):
    # /var/log/panda is the panda-shared-logs CephFS volume, shared across
    # panda-server, jedi, bigmon, panda-ui, and idds-rest - a bug in any one
    # of them filling it up affects all the others too, so it's worth an
    # early warning here rather than only discovering it during an incident.
    try:
        usage = shutil.disk_usage(path)
        used_pct = 100 * usage.used / usage.total
        print(f"{path} usage: {used_pct:.0f}% ({usage.used // (1024 ** 3)}G / {usage.total // (1024 ** 3)}G)")
        if used_pct >= warn_threshold_pct:
            print(f"WARNING: {path} usage is {used_pct:.0f}%, at or above the {warn_threshold_pct}% warning threshold")
    except Exception as ex:
        print(f"failed to check {path} disk usage: {ex}")


def main():
    uwsgi_avail, condor_avail, condor_q_avail = 0, 0, 0
    try:
        uwsgi_avail = uwsgi_process_availability()
        condor_avail = condor_process_availability()
        condor_q_avail = condor_q_availability()
    except Exception as ex:
        print(f"failed to check availability: {ex}")

    shared_volume_usage_check()

    print(f"uwsgi_avail: {uwsgi_avail}, condor_avail: {condor_avail}, condor_q_avail: {condor_q_avail}")

    health_monitor_file = "/var/log/panda/harvester_healthy"
    if uwsgi_avail and condor_avail and condor_q_avail:
        with open(health_monitor_file, 'w') as f:
            f.write("OK")
    else:
        if os.path.exists(health_monitor_file):
            os.remove(health_monitor_file)


if __name__ == '__main__':
    main()
