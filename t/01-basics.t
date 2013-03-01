#!perl -T

use 5.010;
use strict;
use warnings;

use Data::Clone;
use DBI;
use File::chdir;
use File::Temp qw(tempdir);
use SHARYANTO::SQL::Schema qw(create_or_update_db_schema);
use Test::More 0.98;

my $dir = tempdir(CLEANUP => 1);
$CWD = $dir;
my $dbh;

sub connect_db {
    my ($ds, $user, $pass);
    if ($ds = $ENV{TEST_DBI_DS}) {
        $user = $ENV{TEST_DBI_USER};
        $pass = $ENV{TEST_DBI_PASS};
    } else {
        $ds = "dbi:SQLite:$dir/db.db";
        $user = "";
        $pass = "";
    }
    $dbh = DBI->connect($ds, $user, $pass, {RaiseError=>1});
}

sub reset_db {
    $dbh->begin_work;
    $dbh->do("DROP TABLE IF EXISTS $_") for qw(t1 t2 t3 t4 meta);
    $dbh->commit;
}

my $spec0 = {
    latest_v => 3,

    install => [
        "CREATE TABLE t1 (i INT)",
        "CREATE TABLE t4 (i INT)",
    ],

    upgrade_to_v1 => [
        "CREATE TABLE t1 (i INT)",
        "CREATE TABLE t2 (i INT)",
        "CREATE TABLE t3 (i INT)",
    ],
    upgrade_to_v2 => [
        "CREATE TABLE t4 (i INT)",
        "DROP TABLE t3",
    ],
    upgrade_to_v3 => [
        "DROP TABLE t2",
    ],
};
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
reset_db();

subtest "create (v1)" => sub {
    my $spec = clone($spec0);
    delete $spec->{install}; $spec->{latest_v} = 1;
    create_or_update_db_schema(dbh => $dbh, spec => $spec);
    table_exists(qw/t1 t2 t3/); table_not_exists(qw/t4/);
    v_is(1);
};

subtest "upgrade to v2" => sub {
    my $spec = clone($spec0);
    $spec->{latest_v} = 2;
    create_or_update_db_schema(dbh => $dbh, spec => $spec);
    table_exists(qw/t1 t2 t4/); table_not_exists(qw/t3/);
    v_is(2);
};

subtest "upgrade to v3" => sub {
    my $spec = clone($spec0);
    create_or_update_db_schema(dbh => $dbh, spec => $spec);
    table_exists(qw/t1 t4/); table_not_exists(qw/t2 t3/);
    v_is(3);
};

subtest "create (directly to v3, via install)" => sub {
    reset_db();
    my $spec = clone($spec0);
    create_or_update_db_schema(dbh => $dbh, spec => $spec);
    table_exists(qw/t1 t4/); table_not_exists(qw/t2 t3/);
    v_is(3);
};

# XXX should use postgres to test atomicity of upgrade
subtest "failed upgrade 1->2 due to error in SQL" => sub {
    reset_db();
    my $spec = clone($spec0);
    delete $spec->{install}; $spec->{upgrade_to_v2} = ['blah'];
    my $res = create_or_update_db_schema(dbh => $dbh, spec => $spec);
    diag explain $res;
    is($res->[0], 500, "res");
    table_exists(qw/t1 t2 t3/); table_not_exists(qw/t4/);
    v_is(1);
};
subtest "failed upgrade 2->3 due to error in SQL" => sub {
    reset_db();
    my $spec = clone($spec0);
    delete $spec->{install}; $spec->{upgrade_to_v3} = ['blah'];
    my $res = create_or_update_db_schema(dbh => $dbh, spec => $spec);
    diag explain $res;
    is($res->[0], 500, "res");
    table_exists(qw/t1 t2 t4/); table_not_exists(qw/t3/);
    v_is(2);
};

DONE_TESTING:
done_testing();
reset_db();
if (Test::More->builder->is_passing) {
    $CWD = "/";
} else {
    diag "Tests failing, not removing tmpdir $dir";
}
