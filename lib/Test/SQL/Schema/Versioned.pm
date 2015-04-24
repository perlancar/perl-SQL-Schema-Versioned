package Test::SQL::Schema::Versioned;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
                    sql_schema_spec_ok
            );

use DBIx::Diff::Schema qw(diff_db_schema);
use SQL::Schema::Versioned qw(create_or_update_db_schema);
use Test::Exception;
use Test::More;

sub sql_schema_spec_ok {
    my ($spec, $twdb) = @_;

    subtest "sql schema spec test" => sub {
        # some sanity checks
        is(ref($spec), 'HASH', 'spec is a hash') or return;
        ok($spec->{latest_v} >= 1, 'latest_v >= 1') or return;
        ok($spec->{install}, 'has install') or return;
        if ($spec->{latest_v} > 1) {
            ok($spec->{install_v1}, 'has install_v1') or return;
        }

        my $dbh1;
        subtest "testing schema creation using install" => sub {
            $dbh1 = $twdb->create_db;
            lives_ok {
                my $res = create_or_update_db_schema(dbh=>$dbh1, spec=>$spec);
                is($res->[0], 200, 'create/update status') or diag explain $res;
            };
        };

        my $dbh2;
        subtest "testing schema upgrade from v1" => sub {
            $dbh2 = $twdb->create_db;
            lives_ok {
                local $spec->{install} = $spec->{install_v1};
                local $spec->{latest_v} = 1;
                my $res = create_or_update_db_schema(dbh=>$dbh2, spec=>$spec);
                is($res->[0], 200, 'create/update status') or diag explain $res;
            } "create with install_v1";

            lives_ok {
                my $res = create_or_update_db_schema(dbh=>$dbh2, spec=>$spec);
                is($res->[0], 200, 'create/update status') or diag explain $res;
            };
        } if $spec->{latest_v} > 1;

        my $diff = diff_db_schema($dbh1, $dbh2);
        is_deeply($diff, {}, 'create from scratch vs upgrade from v1 results in the same database schema')
            or diag explain $diff;
    };
}

1;
# ABSTRACT: Test SQL::Schema::Versioned spec

=head1 FUNCTIONS

=head2 sql_schema_spec_ok($spec, $twdb)

Test C<$spec>. C<$twdb> is an instance of L<Test::WithDB> (e.g. Test::WithDB
itself or L<Test::WithDB::SQLite>).
