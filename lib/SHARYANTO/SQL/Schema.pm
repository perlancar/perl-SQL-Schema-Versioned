package SHARYANTO::SQL::Schema;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(create_or_update_db_schema);

our %SPEC;

$SPEC{create_or_update_db_schema} = {
    v => 1.1,
    summary => 'Routine and convention to create/update '.
        'your application\'s DB schema',
    description => <<'_',

With this routine (and some convention) you can easily create and update
database schema for your application in a simple (and boring a.k.a. using plain
SQL) way.

First you supply the SQL statements in `sqls` to create the database in the form
of array of arrays of statements. The first array element is a series of SQL
statements to create the tables/indexes (recommended to use CREATE TABLE IF NOT
EXISTS instead of CREATE TABLE). This is called version 1. Version will be
created in the special table called `meta` (in the row ('schema_version', 1).
The second array element is a series of SQL statements to update to version 2
(e.g. ALTER TABLE, and so on). The third element to update to version 3, and so
on.

So whenever you want to update your schema, you add a series of SQL statements
to the `sqls` array.

This routine will connect to database and check the current schema version. If
`meta` table does not exist yet, it will be created and the first series of SQL
statements will be executed. The final result is schema at version 1. If `meta`
table exists, schema version will be read from it and one or more series of SQL
statements will be executed to get the schema to the latest version.

Currently only tested on MySQL and SQLite.

_
    args => {
        sqls => {
            schema => ['array*', of => ['array*' => of => 'str*']],
            summary => 'SQL statements to create and update schema',
            req => 1,
        },
        dbh => {
            schema => ['obj*'],
            summary => 'DBI database handle',
            req => 1,
            description => <<'_',

Example:

    [
        [
            # for version 1
            'CREATE TABLE IF NOT EXISTS t1 (...)',
            'CREATE TABLE IF NOT EXISTS t2 (...)',
        ],
        [
            # for version 2
            'ALTER TABLE t1 ADD COLUMN c5 INT NOT NULL',
            'CREATE UNIQUE INDEX i1 ON t2(c1)',
        ],
        [
            # for version 3
            'ALTER TABLE t2 DROP COLUMN c2',
        ],
    ]

_
        },
    },
    "_perinci.sub.wrapper.validate_args" => 0,
};
sub create_or_update_db_schema {
    my %args = @_; # VALIDATE_ARGS

    my $sqls = $args{sqls};
    my $dbh  = $args{dbh};

    # first, check current schema version
    my $v;
    my @t = $dbh->tables("", undef, "meta");
    if (@t) {
        ($v) = $dbh->selectrow_array(
            "SELECT value FROM meta WHERE name='schema_version'");
    } else {
        $v = 0;
        $dbh->do("CREATE TABLE meta (name VARCHAR(64) NOT NULL PRIMARY KEY, value VARCHAR(255))");
        $dbh->do("INSERT INTO meta (name,value) VALUES ('schema_version',0)");
    }

    for my $i (($v+1) .. @$sqls) {
        $log->debug("Updating database schema to version $i ...");
        for my $sql (@{ $sqls->[$i-1] }) {
            $dbh->do($sql);
        }
        $dbh->do("UPDATE meta SET value=$i WHERE name='schema_version'");
    }

    [200];
}

1;
# ABSTRACT: Routine and convention to create/update your application's DB schema

=cut
