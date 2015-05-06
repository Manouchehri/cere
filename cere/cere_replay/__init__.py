#!/usr/bin/env python

import os
import sys
import argparse
import logging
import shutil
import subprocess
import cere_configure
import cere_dump
import common.variables as var
import common.utils as utils

logger = logging.getLogger('Replay')

def init_module(subparsers, cere_plugins):
    cere_plugins["replay"] = run
    replay_parser = subparsers.add_parser("replay", help="replay a region")
    replay_parser.add_argument('--region', required=True, help="Region to replay")
    replay_parser.add_argument('--invocation', type=int, default=1, help="invocation to replay (Default 1)")
    replay_parser.add_argument('--invitro-callcount', type=int, default=10, help="Meta-repetition for the replay (Default 10)")
    replay_parser.add_argument('--noinstrumentation', type=bool, const=True, default=False, nargs='?', help="=Replay without instrumentation")
    replay_parser.add_argument('--wrapper', default=var.RDTSC_WRAPPER, help="Wrapper used to make the link between cere interface and your library")
    replay_parser.add_argument('--norun', type=bool, default=False, help="=If you don't want to automatically run the replay")
    replay_parser.add_argument('--force', '-f', const=True, default=False, nargs='?', help="Will re-dump any previous CERE dumps")

def run(args):
    if not cere_configure.init():
        return False
    if utils.is_invalid(args.region) and not args.force:
        logger.warning("{0} is invalid. Skipping replay".format(args.region))
        return False
    if os.path.isfile("{0}/{1}_{2}.csv".format(var.CERE_REPLAY_PATH, args.region, args.invocation)) and not args.force:
        logger.info("Keeping previous replay measures for {0} invocation {1}.".format(args.region, args.invocation))
        return True
    if args.noinstrumentation:
        instru_cmd = ""
        logger.info("Compiling replay mode for region {0} invocation {1} without instrumentation".format(args.region, args.invocation))
    else:
        instru_cmd = "--instrument"
        logger.info("Compiling replay mode for region {0} invocation {1} with instrumentation".format(args.region, args.invocation))
    try:
        logger.debug(subprocess.check_output("{0} INVITRO_CALL_COUNT={5} MODE=\"replay --region={1} --invocation={2} {3} --wrapper={4}\" -B".format(cere_configure.cere_config["build_cmd"], args.region, args.invocation, instru_cmd, args.wrapper, args.invitro_callcount), stderr=subprocess.STDOUT, shell=True))
    except subprocess.CalledProcessError as err:
        logger.error(str(err))
        logger.error(err.output)
        logger.error("Compiling replay mode for region {0} invocation {1} Failed".format(args.region, args.invocation))
        utils.mark_invalid(args.region, "Replay failed")
        return False
    if not args.norun:
        logger.info("Replaying invocation {1} for region {0}".format(args.region, args.invocation))
        try:
            logger.debug(subprocess.check_output(cere_configure.cere_config["run_cmd"], stderr=subprocess.STDOUT, shell=True))
        except subprocess.CalledProcessError as err:
            logger.error(str(err))
            logger.error(err.output)
            logger.error("Replay failed for {0} invocation {1}".format(args.region, args.invocation))
            utils.mark_invalid(args.region, "Replay failed")
            return False
    return True
