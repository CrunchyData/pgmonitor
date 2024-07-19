#!/usr/bin/env python

import argparse, os, os.path, psycopg2, shutil, subprocess, sys, time
from datetime import date, timedelta

parser = argparse.ArgumentParser(description="This script runs the pg_badger log analysis tool for all databases in a given database. Runs on yesterdays logs.")
parser.add_argument('-l', '--logdir', required=True, help="Full path to directory where postgresql log files are stored. Required.")
parser.add_argument('-c', '--connection', default="host=", help="""Connection string for psycopg. Defaults to "host=" (local socket).""")
parser.add_argument('-d', '--dbname', help="Only run for given database. Otherwise defaults to all databases in the cluster")
parser.add_argument('-o', '--output', default=os.getcwd(), help="Base directory to create folders for pgbadger output. Each database gets its own subfolder. Default is current location where script is run from.")
parser.add_argument('-e', '--exclude', action="append", help="Exclude a database. Set multiple times to exclude more than one. By default it already excludes postgres, template0 and template1")
parser.add_argument('-j', '--jobs', type=int, default=1, help="Use the -j option in pgbadger to set number of jobs to run on parallel on each log file.")
parser.add_argument('-J', '--Jobs', type=int, default=1, help="Use the -J option in pgbadger to set number of log file to parse in parallel.")
parser.add_argument('--pgbadger', default="pgbadger", help="Location of pgbadger script file. Otherwise assumed in PATH.")
parser.add_argument('--perl', default="perl", help="Path to desired perl binary location if not in PATH.")
parser.add_argument('--log_line_prefix', default="""%t [%r] [%p]: [%l-1] user=%u,db=%d,e=%e """, help="""Log line prefix used in log files. Defaults to: "%%t [%%r] [%%p]: [%%l-1] user=%%u,db=%%d,e=%%e ".""")
parser.add_argument('--exclude_query', help="""any query matching the given regex will be excluded from the report. For example: "^(VACUUM|COMMIT)".""")
parser.add_argument('-v', '--verbose', action="store_true", help="Give more verbose output")

parser.add_argument('-a', '--archive', action="store_true", help="""Flag to enable results file archiving. Stores them gzip'd in an folder in the given --output path. Use --archive_time to change default of 30 days and --archive_folder to change the name of the folder used.""")
parser.add_argument('--archive_time', type=int, default=30, help="Sets how old the results files that get archived must be. Default 30.")
parser.add_argument('--archive_folder', default="archive", help="""Folder name to put archived reports into. Make sure this name does not match any current database names. Defaults to "archive".""")
parser.add_argument('--date', help="Run for another day besides yesterday. Must be in format YYYY-MM-DD")

args = parser.parse_args()

if not os.path.exists(args.output):
    print "Path given by --output (-o) does not exist: " + str(args.output)
    sys.exit(2)

def get_databases():
    conn = psycopg2.connect(args.connection)
    cur = conn.cursor()
    sql = "SELECT datname FROM pg_catalog.pg_database WHERE datallowconn = true AND datname NOT IN ('postgres', 'template0', 'template1')"
    if args.dbname != None:
        sql += " AND datname = %s"
    sql += " ORDER BY datname"
    if args.dbname != None:
        cur.execute(sql, [args.dbname])
    else:
        cur.execute(sql)
    database_list = cur.fetchall()
    cur.close()
    conn.close()
    return database_list


def get_yesterday():
    yesterday = date.today() - timedelta(1)
    yesterday = yesterday.strftime("%Y-%m-%d")
    return yesterday

def check_date(date_string):
    try:
        valid_date = time.strptime(date_string, "%Y-%m-%d")
    except ValueError, e:
        print "Invalid date format given for --date option. Must be YYYY-MM-DD."

def check_exclude(datname):
    if args.exclude != None:
        for e in args.exclude:
            if e == datname:
                return True
            else:
                return False
    else:
        return False


def archive():
    max_diff = timedelta(days=args.archive_time)

    dbdir_list = os.listdir(args.output)
    for dbname in dbdir_list:
        if dbname == args.archive_folder:
            continue
        if not os.path.exists(os.path.join(args.output, args.archive_folder, dbname)):
            os.makedirs(os.path.join(args.output, args.archive_folder, dbname))
        file_list = os.listdir(os.path.join(args.output, dbname))
        if file_list != None:
            for f in file_list:
                f = os.path.join(args.output, dbname, f)
                mtime = os.stat(f).st_mtime
                time_diff = timedelta(seconds=(time.time() - mtime))
                if time_diff > max_diff:
                    year = time.strftime('%Y', time.localtime(mtime))
                    month = time.strftime('%m', time.localtime(mtime))
                    dest_dir = os.path.join(args.output, "archive", dbname, year, month)
                    if not os.path.exists(dest_dir):
                        os.makedirs(dest_dir)
                    if args.verbose:
                        print "Archiving " + f
                    shutil.move(f, dest_dir)
        else:
            # directory is empty so delete it
            # purposely used rmdir so it will throw error if it tries to delete a non-empty dir
            os.rmdir(os.path.join(args.output, dbname))


if __name__ == "__main__":
    database_list = get_databases()
    if args.date != None:
        check_date(args.date)
        report_date = args.date
    else:
        report_date = get_yesterday()
    if args.archive:
        for d in database_list:
            if d[0] == args.archive_folder:
                print("Target archive folder has the same name as a current database. Please use --archive_folder to give a different folder name.")
                sys.exit(2);
    for d in database_list:
        # check for databases to exclude
        if check_exclude(d[0]) == True:
            continue
        # check that folder for given database exists and if it doesn't create it
        if not os.path.exists(os.path.join(args.output, d[0])):
            os.makedirs(os.path.join(args.output, d[0]))
        call_pgbadger = args.perl + " " + args.pgbadger + " " + os.path.join(args.logdir, "postgresql-" + report_date + "*")
        if args.verbose != True:
            call_pgbadger += " -q"
        call_pgbadger += " -d " + d[0]
        call_pgbadger += " -o \"" + os.path.join(args.output, d[0], d[0] + "_log_report-" + report_date + ".html") + "\""
        call_pgbadger += " -j " + str(args.jobs)
        call_pgbadger += " -J " + str(args.Jobs)
        call_pgbadger += " -p \"" + args.log_line_prefix + "\""
        if args.exclude_query is not None:
            call_pgbadger += " --exclude-query=\"" + args.exclude_query + "\""
        if args.verbose == True:
            print call_pgbadger
        os.system(call_pgbadger)
    if args.archive:
       archive()


"""
LICENSE AND COPYRIGHT
---------------------

run_pgbadger.py is released under the PostgreSQL License, a liberal Open Source license, similar to the BSD or MIT licenses.

Copyright (c) 2015 Gilt Groupe, Inc.

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

IN NO EVENT SHALL THE AUTHOR BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE AUTHOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

THE AUTHOR SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE AUTHOR HAS NO OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
"""
