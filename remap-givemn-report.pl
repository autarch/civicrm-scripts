#!/usr/bin/env perl

use v5.24;

use strict;
use warnings;
use autodie;

use DateTime;
use Path::Tiny qw( path );
use Text::CSV_XS;

my @givemn_columns = qw(
    tracking_number
    type
    donation_date
    donation_time_eastern
    first_name
    last_name
    address
    city
    state
    zip
    country
    email
    designation
    dedication
    dedication_email
    source
    page_creator
    donation_site
    team_name
    giving_event_name
    repeats
    payment_method
    origin
    donation_amount
    platform_rate
    platform_cost
    credit_card_processing_rate
    credit_card_processing_cost
    campaign_rate
    campaign_cost
    covered_cost
    net_amount
    refund
    disbursement_date
    referral_code
    publicly_hidden
    company
    age
    gender
    phone_number
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
    # consume header row
    <$in_fh>;

    my $csv = Text::CSV_XS->new( { eol => "\n" } );

    my $contributions_file = $in_file->parent->child(
        $in_file->basename =~ s/(\..+)$/-contributions$1/r );
    my $contributions_fh = $contributions_file->openw;
    $csv->print( $contributions_fh, \@contributions_columns );

    my $individuals_file = $in_file->parent->child(
        $in_file->basename =~ s/(\..+)$/-individuals$1/r );
    my $individuals_fh = $individuals_file->openw;
    $csv->print( $individuals_fh, \@individuals_columns );

    $csv->column_names(@givemn_columns);

    while ( my $row = $csv->getline_hr($in_fh) ) {
        if ( $row->{dedication} ) {
            say "$row->{first_name} $row->{last_name} made a dedication";
            say "  - $row->{dedication}";
        }
        if ( $row->{email} eq 'anonymous' ) {
           $row->{email} = 'anonymous@gmail.com';
        }
        if ( $row->{country} eq 'USA' ) {
           $row->{country} = 'US';
        }

        s/^\D//
            for grep {defined}
            @{$row}{qw( donation_amount net_amount platform_cost )};

        my ( $month, $day, $year ) = split /\//, $row->{donation_date};
        my $date
            = DateTime->new( year => $year, month => $month, day => $day )
            ->ymd;

        $csv->print(
            $contributions_fh,
            [
                @{$row}{
                    qw(
                        email
                        )
                },
                abs($row->{donation_amount}),
                abs($row->{net_amount}),
                abs($row->{donation_amount}) - abs($row->{net_amount}),
                ($date) x 2,
                $row->{tracking_number},
                'Credit Card',
                'GiveMN',
                'Donation',
                q{},
            ],
        );

        $csv->print(
            $individuals_fh,
            [
                @{$row}{
                    qw(
                        first_name
                        last_name
                        email
                        address
                        )
                },
                q{},    # Supplement Address 1
                @{$row}{
                    qw(
                        city
                        state
                        zip
                        country
                        phone_number
                        )
                },
            ],
        );
    }
}

main(@ARGV);
