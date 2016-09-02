#!/usr/bin/env perl

use v5.24;

use strict;
use warnings;
use autodie;

use DateTime;
use DateTime::Format::Strptime;
use Path::Tiny qw( path );
use Text::CSV_XS;

my @generosity_columns = qw(
    donation_amount
    email
    name
    anon
    donation_date
    donation_level
    shipping_name
    address1
    address2
    city
    state
    zip
    country
);

my @contributions_columns = (
    'Email Address',
    'Total Amount',
    'Net Amount',
    'Fee Amount',
    'Date Received',
    'Receipt Date',
    'Transaction ID',
    'Payment Method',
    'Contribution Source',
    'Financial Type',
    'Note',
);

my @individuals_columns = (
    'First Name',
    'Last Name',
    'Email Address',
    'Street Address',
    'Supplemental Address 1',
    'City',
    'State',
    'Postal Code',
    'Country',
    'Mobile Phone',
);

sub main {
    my $in_file = path(shift);

    my $in_fh = $in_file->openr;

    my $csv = Text::CSV_XS->new( { eol => "\n" } );
    <$in_fh>;

    my $contributions_file = $in_file->parent->child(
        $in_file->basename =~ s/(\..+)$/-contributions$1/r );
    my $contributions_fh = $contributions_file->openw;
    $csv->print( $contributions_fh, \@contributions_columns );

    my $individuals_file = $in_file->parent->child(
        $in_file->basename =~ s/(\..+)$/-individuals$1/r );
    my $individuals_fh = $individuals_file->openw;
    $csv->print( $individuals_fh, \@individuals_columns );

    $csv->column_names(@generosity_columns);

    my $dt_parser = DateTime::Format::Strptime->new(
        pattern  => '%Y-%m-%d %H:%M:%S %z',
        on_error => 'croak',
    );
    my $id_dedupe = '1';
    my %ids;
    while ( my $row = $csv->getline_hr($in_fh) ) {
        $row->{donation_amount} =~ s/\D+//g;
        $row->{net_amount} = $row->{donation_amount};
        $row->{our_fee}    = 0;

        my $date = $dt_parser->parse_datetime( $row->{donation_date} )
            ->set_time_zone('America/Chicago')->ymd;

        $csv->print(
            $contributions_fh,
            [
                @{$row}{
                    qw(
                        email
                        donation_amount
                        net_amount
                        our_fee
                        )
                },
                ($date) x 2,
                q{},
                $row->{payment_method},
                'Generosity',
                'Donation',
                q{},
            ],
        );

        $row->{zip} =~ s/[^0-9\-]+//g;
        my ( $first, $last ) = ( split / /, $row->{name} )[ 0, -1 ];
        $csv->print(
            $individuals_fh,
            [
                $first,
                $last,
                @{$row}{
                    qw(
                        email
                        address1
                        address2
                        city
                        state
                        zip
                        country
                        )
                },
                q{},
            ],
        );
    }
}

main(@ARGV);
