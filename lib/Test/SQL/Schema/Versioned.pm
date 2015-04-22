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

use SQL::Schema::Versioned qw(create_or_update_db_schema);
use Test::Exception;
use Test::More;

sub sql_schema_spec_ok {
    my ($spec, $twdb) = @_;

    subtest "sql schema spec test" => sub {
        is(ref($spec), 'HASH', 'spec is a hash') or return;
        ok($spec->{latest_v} >= 1, 'latest_v >= 1') or return;
        ok($spec->{install}, 'has install') or return;
        if ($spec->{latest_v} > 1) {
            ok($spec->{install_v1}, 'has install_v1') or return;
        }

        subtest "testing schema creation using install" => sub {
            my $dbh = $twdb->create_db;
            lives_ok { create_or_update_db_schema(dbh=>$dbh, spec=>$spec) };
        };

        subtest "testing schema upgrade from v1" => sub {
            my $dbh = $twdb->create_db;
            lives_ok {
                local $spec->{install} = $spec->{install_v1};
                local $spec->{latest_v} = 1;
                create_or_update_db_schema(dbh=>$dbh, spec=>$spec);
            } "create with install_v1";
            lives_ok { create_or_update_db_schema(dbh=>$dbh, spec=>$spec) };
        } if $spec->{latest_v} > 1;
    };
}

1;
# ABSTRACT: Test SQL::Schema::Versioned spec

=head1 FUNCTIONS

=head2 sql_schema_spec_ok($spec[ , $twdb ])

Test C<$spec>. C<$twdb> is an instance of L<Test::WithDB>.
