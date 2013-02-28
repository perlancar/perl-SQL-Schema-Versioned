#!perl -T

use 5.010;
use strict;
use warnings;

use DBI;
use File::chdir;
use File::Temp qw(tempdir);
use SHARYANTO::SQL::Schema qw(create_or_update_db_schema);
use Test::More 0.98;

my $dir = tempdir(CLEANUP => 1);
$CWD = $dir;
my $dbh;

sub connect_db {
    $dbh = DBI->connect("dbi:SQLite:$dir/db.db", "", "");
}

my $full_sqls = [
    [
        "CREATE TABLE t1 (i INT)",
        "CREATE TABLE t2 (i INT)",
        "CREATE TABLE t3 (i INT)",
    ],
    [
        "CREATE TABLE t4 (i INT)",
        "DROP TABLE t3",
    ],
    [
        "DROP TABLE t2",
    ],
];
my $sqls;

sub _table_exists_or_not_exists_ok {
    my ($which, $t) = @_; # which=1 -> test exists, 2 -> test doesn't exist
    my @t = $dbh->tables("", undef, $t);
    if ($which == 1) {
        ok(~~@t, "table $t exists");
    } else {
        ok(!@t, "table $t doesn't exist");
    }
}

sub table_exists {
    for (@_) {
        _table_exists_or_not_exists_ok(1, $_);
    }
}

sub table_not_exists {
    for (@_) {
        _table_exists_or_not_exists_ok(2, $_);
    }
}

sub v_is {
    my ($supposed_v) = @_;
    my ($cur_v) = $dbh->selectrow_array(
        "SELECT value FROM meta WHERE name='schema_version'");
    is($cur_v, $supposed_v, "v");
}

connect_db();

subtest "create (v1)" => sub {
    $sqls = [ $full_sqls->[0] ];
    create_or_update_db_schema(dbh => $dbh, sqls => $sqls);
    table_exists(qw/t1 t2 t3/); table_not_exists(qw/t4/);
    v_is(1);
};

subtest "upgrade to v2" => sub {
    $sqls = [ $full_sqls->[0], $full_sqls->[1] ];
    create_or_update_db_schema(dbh => $dbh, sqls => $sqls);
    table_exists(qw/t1 t2 t4/); table_not_exists(qw/t3/);
    v_is(2);
};

subtest "upgrade to v3" => sub {
    $sqls = [ $full_sqls->[0], $full_sqls->[1], $full_sqls->[2] ];
    create_or_update_db_schema(dbh => $dbh, sqls => $sqls);
    table_exists(qw/t1 t4/); table_not_exists(qw/t2 t3/);
    v_is(3);
};

subtest "create (directly to v3)" => sub {
    undef $dbh;
    unlink "$dir/db.db";
    connect_db();
    $sqls = [ $full_sqls->[0], $full_sqls->[1], $full_sqls->[2] ];
    create_or_update_db_schema(dbh => $dbh, sqls => $sqls);
    table_exists(qw/t1 t4/); table_not_exists(qw/t2 t3/);
    v_is(3);
};

DONE_TESTING:
done_testing();
if (Test::More->builder->is_passing) {
    $CWD = "/";
} else {
    diag "Tests failing, not removing tmpdir $dir";
}
