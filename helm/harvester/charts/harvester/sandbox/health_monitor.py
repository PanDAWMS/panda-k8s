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


def send_mail(subject, body, recipient, sender="atlas-adc-panda-no-reply@cern.ch"):
    try:
        subprocess.run(
            # explicit -r sender is required: cernmx.cern.ch rejects mail from
            # an arbitrary local/hostname-based From address by policy, so the
            # default (unset) sender bounces - use the same pre-authorized
            # address panda-server's own MailUtils.py already sends from.
            ["mail", "-r", sender, "-s", subject, recipient],
            input=body, text=True, timeout=30, check=True,
        )
    except Exception as ex:
        # mail isn't installed in every harvester image yet (HSF/harvester#312) -
        # don't let a missing/broken mail command take down the rest of the
        # health check, just note it and move on.
        print(f"failed to send mail ({subject!r}): {ex}")


def shared_volume_usage_check(path="/var/log/condor_logs", warn_threshold_pct=90,
                               alert_recipient="atlas-adc-harvester-central-support@cern.ch",
                               alert_marker="/var/log/panda/.shared_volume_alert_sent"):
    # /var/log/condor_logs is harvester's mount of the panda-shared-logs
    # CephFS volume, shared across panda-server, jedi, bigmon, panda-ui, and
    # idds-rest - a bug in any one of them filling it up affects all the
    # others too, so it's worth an early warning here rather than only
    # discovering it during an incident. Note: /var/log/panda is NOT this
    # volume on every cluster - on testbed it's harvester's own separate
    # dedicated 50Gi volume, not the 200Gi shared one, so don't switch back
    # to checking that path.
    try:
        usage = shutil.disk_usage(path)
        used_pct = 100 * usage.used / usage.total
        print(f"{path} usage: {used_pct:.0f}% ({usage.used // (1024 ** 3)}G / {usage.total // (1024 ** 3)}G)")

        hostname = os.uname().nodename
        if used_pct >= warn_threshold_pct:
            message = f"WARNING: {path} usage is {used_pct:.0f}%, at or above the {warn_threshold_pct}% warning threshold"
            print(message)
            # only alert once per breach, not every 10-minute cron cycle -
            # a marker file tracks whether we've already alerted this time
            if not os.path.exists(alert_marker):
                send_mail(f"[SHARED_LOGS] {path} at {used_pct:.0f}% on {hostname}", message, alert_recipient)
                with open(alert_marker, "w") as f:
                    f.write(message)
        elif os.path.exists(alert_marker):
            # usage dropped back below threshold - send a recovery notice and
            # clear the marker so a future breach alerts again
            message = f"RECOVERED: {path} usage is back down to {used_pct:.0f}%, below the {warn_threshold_pct}% warning threshold"
            print(message)
            send_mail(f"[SHARED_LOGS] RECOVERED: {path} at {used_pct:.0f}% on {hostname}", message, alert_recipient)
            os.remove(alert_marker)
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
