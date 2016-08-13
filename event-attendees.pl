#!/usr/bin/env perl

use v5.24;

use strict;
use warnings;
use autodie;

use DBI;
use Path::Tiny qw( path );
use Text::CSV_XS;

my @in_columns = qw(
    first_name
    last_name
    phone
    email
    address
    city
    state
    postal_code
    event_name
);

my @attendees_columns = qw(
    contact_id
    event_name
    role
    status
);

sub main {
    my $in_file = path(shift);

    my $in_fh = $in_file->openr;
    <$in_fh>; # skip the headers

    my $csv = Text::CSV_XS->new( { eol => "\r\n" } );

    my $attendees_file = $in_file->parent->child(
        $in_file->basename =~ s/(\..+)$/-attendance$1/r );
    my $attendees_fh = $attendees_file->openw;
    $csv->print( $attendees_fh, \@attendees_columns );

    my $dbh = DBI->connect(
        'dbi:mysql:dbname=civicrm;port=3307;host=127.0.0.1', 'root', undef,
        { RaiseError => 1 },
    );
    my $email_sth = $dbh->prepare(<<'EOF');
SELECT contact_id
  FROM civicrm_email
 WHERE LOWER(email) = ?
EOF
    my $name_sth = $dbh->prepare(<<'EOF');
SELECT id
  FROM civicrm_contact
 WHERE ( LOWER(first_name) = ? OR LOWER(nick_name) = ? )
   AND LOWER(last_name)  = ?
EOF

    $csv->column_names(@in_columns);
    while ( my $row = $csv->getline_hr($in_fh) ) {
        $email_sth->execute( lc $row->{email} );
        my @ids = map { $_->[0] } @{ $email_sth->fetchall_arrayref( [0] ) // [] };
        $email_sth->finish;

        if ( @ids > 1 ) {
            warn "Found multiple ids for $row->{email}\n";
            next;
        }

        unless (@ids) {
            $name_sth->execute(
                map {lc} (
                    $row->{first_name},
                    $row->{first_name},
                    $row->{last_name},
                )
            );
            @ids = map { $_->[0] } @{ $name_sth->fetchall_arrayref( [0] ) // [] };
            $name_sth->finish;
        }

        if ( @ids > 1 ) {
            warn
                "Found multiple contacts named $row->{first_name} $row->{last_name}\n";
            next;
        }

        unless (@ids) {
            warn
                "Did not find a match for $row->{first_name} $row->{last_name} ($row->{email})\n";
            next;
        }

        $csv->print(
            $attendees_fh,
            [
                $ids[0],
                $row->{event_name},
                'Attendee',
                'Attended',
            ],
        );
    }
}

main(@ARGV);
