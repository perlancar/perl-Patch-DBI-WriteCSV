package Patch::DBI::WriteCSV;

# DATE
# VERSION

use strict;
use warnings;

my @patchhandles;
my $has_written_csv_header;

sub import {
    my $class = shift;
    my %args = @_;

    my $csv;
    if ($args{csv}) {
        $csv = delete $args{csv};
    } else {
        require Text::CSV;
        $csv = Text::CSV->new;
    }
    my $filehandle;
    if ($args{handle}) {
        $filehandle = delete $args{handle};
    } elsif ($args{filename}) {
        open $filehandle, ">>", $args{filename}
            or die "Can't write to $args{filename}: $!";
        delete $args{filename};
    } else {
        $filehandle = \*STDOUT;
    }

    require Monkey::Patch::Action;
    @patchhandles = ();
    push @patchhandles, Monkey::Patch::Action::patch_package(
        "DBI::st", "fetchrow_array", "wrap",
        sub {
            my $ctx = shift;
            my $self = $_[0];

            $csv->say($filehandle, $self->{NAME})
                unless $has_written_csv_header++;
            my @row = $ctx->{orig}->(@_);
            $csv->say($filehandle, \@row) if @row;
            @row;
        },
    );
    push @patchhandles, Monkey::Patch::Action::patch_package(
        "DBI::st", "fetchrow_arrayref", "wrap",
        sub {
            my $ctx = shift;
            my $self = $_[0];

            $csv->say($filehandle, $self->{NAME})
                unless $has_written_csv_header++;
            my $row = $ctx->{orig}->(@_);
            $csv->say($filehandle, $row) if $row;
            $row;
        },
    );
    push @patchhandles, Monkey::Patch::Action::patch_package(
        "DBI::st", "fetchrow_hashref", "wrap",
        sub {
            my $ctx = shift;
            my $self = $_[0];

            $csv->say($filehandle, $self->{NAME})
                unless $has_written_csv_header++;
            my $row = $ctx->{orig}->(@_);
            $csv->say($filehandle, [map {$row->{$_}} @{ $self->{NAME} }]) if $row;
            $row;
        },
    );
    push @patchhandles, Monkey::Patch::Action::patch_package(
        "DBI::st", "fetchall_arrayref", "wrap",
        sub {
            my $ctx = shift;
            my $self = $_[0];

            $csv->say($filehandle, $self->{NAME})
                unless $has_written_csv_header++;
            my $rows = $ctx->{orig}->(@_);
            if ($rows) {
                for my $row (@$rows) { $csv->say($filehandle, $row) }
            }
            $rows;
        },
    );
    push @patchhandles, Monkey::Patch::Action::patch_package(
        "DBI::st", "fetchall_hashref", "wrap",
        sub {
            my $ctx = shift;
            my $self = $_[0];

            $csv->say($filehandle, $self->{NAME})
                unless $has_written_csv_header++;
            my $rows = $ctx->{orig}->(@_);
            if ($rows) {
                for my $id (sort keys %$rows) {
                    my $row = $rows->{$id};
                    $csv->say($filehandle, [map {$row->{$_}} @{ $self->{NAME} }]);
                }
            }
            $rows;
        },
    );
    $has_written_csv_header = 0;
}

sub unimport {
    @patchhandles = ();
}

1;
# ABSTRACT: Patch DBI to also write CSV while fetching rows

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

 use DBI;
 require Patch:DBI::WriteCSV;
 my $dbh = DBI->connect("dbi:mysql:database=mydb", "someuser", "somepass");

 {
     Patch::DBI::WriteCSV->import; # start writing CSV
     $dbh->selectrow_texttable("SELECT * FROM member");
     Patch::DBI::WriteCSV->unimport; # no longer write CSV
 }

The above code will print CSV to STDOUT, e.g.:

 Name,Rank,Serial
 alice,pvt,123456
 bob,cpl,98765321
 carol,"brig gen",8745


=head1 DESCRIPTION

This package patches the following L<DBI> methods:

 fetchrow_array
 fetchrow_arrayref
 fetchrow_hashref
 fetchall_arrayref
 fetchall_hashref

to also write CSV while fetching row(s). By default it writes to STDOUT but this
can be customized (see L</IMPORTS>).


=head1 IMPORTS

Usage:

 Patch::DBI::WriteCSV->import(%opts);

Known options:

=over

=item * csv

A L<Text::CSV> object to use. If not specified, will instantiate a new default
one:

 Text::CSV->new

=item * handle

File handle to write CSV to. Defaults to STDOUT if this as well as L</filename>
is not specified.

=item * filename

File name to open (in append-mode) to write CSV to.

=back


=head1 SEE ALSO

L<DBIx::CSV>

L<https://www.perlmonks.org/?node_id=1227520>
